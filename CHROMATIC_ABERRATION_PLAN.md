# Chromatic Aberration Implementation Plan

## Executive Summary

This document provides a comprehensive analysis of the HyperobjectsMacOS rendering pipeline and a detailed plan for implementing chromatic aberration (CA). The recommended approach is a **post-process CA effect** in the `compute_fragment` shader, with an optional advanced **per-channel SDF distance offset** for more physically accurate results.

---

## Part 1: Pipeline Architecture Analysis

### Overview

The rendering pipeline is a non-standard, compute-based system that renders lines and curves using signed distance field (SDF) techniques with spatial binning for performance.

### Three-Stage Pipeline

```
Stage 1: Transform & Bin (Compute)
├── transformAndBinLinear    (degree 1 - straight lines)
├── transformAndBinQuadratic (degree 2 - quadratic Bezier)
└── transformAndBinCubic     (degree 3 - cubic Bezier)
    → Projects 3D curves to screen space
    → Bins segments into 128x128 pixel spatial grid
    → Output: linearLinesScreenSpaceBuffer

Stage 2: Rasterization (Compute)
└── drawLines kernel
    → Per-pixel SDF distance calculation
    → K-buffer fragment collection (4 fragments)
    → Path-aware alpha compositing
    → Output: writeTexture (double-buffered A/B)

Stage 3: Final Composition (Render)
├── compute_vertex   → Full-screen quad
└── compute_fragment → Samples readTexture to drawable
    ★ THIS IS WHERE CHROMATIC ABERRATION WILL BE ADDED
```

### Key Files

| File | Purpose |
|------|---------|
| `HyperobjectsMacOS/Shaders.metal` | All compute and render shaders (1293 lines) |
| `HyperobjectsMacOS/definitions.h` | Shared C/Metal structs (Uniforms, segments) |
| `HyperobjectsMacOS/Views/RenderView/MetalRenderer.swift` | Pipeline orchestration, buffer management |
| `HyperobjectsMacOS/Models/Classes/RenderConfigurations.swift` | UI-bound parameters |

### Current `compute_fragment` Implementation (Shaders.metal:1265-1268)

```metal
fragment float4 compute_fragment(float4 fragCoord [[position]],
                                 texture2d<float> lineTexture [[texture(0)]]) {
    constexpr sampler s(coord::pixel);
    return lineTexture.sample(s, fragCoord.xy);
}
```

This minimal shader simply copies the compute output to the screen - perfect for adding post-processing.

### Existing Infrastructure to Leverage

1. **Double-buffered textures**: `lineRenderTextureA`/`lineRenderTextureB` - can read/write independently
2. **Unused uniforms**: `blendRadius` and `blendIntensity` declared in `definitions.h` (lines 46-47) but not implemented
3. **UV coordinates**: `VertexOut` struct has `float2 uv` field (line 1233) already computed in vertex shader
4. **Pattern for params**: `setFragmentTexture` called at line 735 - same pattern for binding uniform buffer

---

## Part 2: Chromatic Aberration Approaches

### Approach A: Post-Process (RECOMMENDED)

Sample R, G, B channels at offset UV coordinates in `compute_fragment`.

**Pros:**
- Simple implementation (modify one function)
- Zero impact on SDF rendering performance
- Easy artistic control
- Works with all existing content

**Cons:**
- Uniform effect across image (doesn't interact with line depth)

### Approach B: Per-Channel SDF Distance Offset (ADVANCED)

Modify `drawLines` kernel to compute distances with per-channel spatial offsets.

**Pros:**
- True per-line chromatic aberration
- Interacts with line depth and overlap

**Cons:**
- 3x distance calculations per fragment
- Requires PathFragment struct modification
- More complex to tune

### Approach C: Geometric Offset (NOT RECOMMENDED)

Render lines 3x with different positions per channel.

**Cons:**
- 3x memory and compute cost
- Complex to implement and control

---

## Part 3: Implementation Plan (Approach A - Post-Process)

### Step 1: Add ChromaticAberration Struct to `definitions.h`

**Location:** After line 49 (after Uniforms struct)

```c
struct ChromaticAberrationParams {
    float intensity;          // 0.0-1.0, blend with original
    float redOffset;          // Pixels, typically negative (-3.0)
    float greenOffset;        // Pixels, typically 0.0
    float blueOffset;         // Pixels, typically positive (3.0)
    float radialPower;        // Falloff exponent (1.0=linear, 2.0=quadratic)
    int useRadialMode;        // 1=radial from center, 0=uniform direction
    vector_float2 direction;  // Direction for uniform mode (normalized)
};
```

### Step 2: Add Parameters to `RenderConfigurations.swift`

**Location:** After line 48 (near `blendIntensity`)

```swift
// Chromatic Aberration
@Published var chromaticAberrationEnabled: Bool = false
@Published var chromaticAberrationIntensity: Float = 0.5
@Published var chromaticAberrationRedOffset: Float = -2.0
@Published var chromaticAberrationGreenOffset: Float = 0.0
@Published var chromaticAberrationBlueOffset: Float = 2.0
@Published var chromaticAberrationRadialPower: Float = 2.0
@Published var chromaticAberrationUseRadialMode: Bool = true
@Published var chromaticAberrationAngle: Float = 0.0  // Radians, for uniform mode
```

### Step 3: Modify `compute_fragment` in `Shaders.metal`

**Location:** Replace lines 1265-1268

```metal
fragment float4 compute_fragment(
    VertexOut in [[stage_in]],
    texture2d<float> lineTexture [[texture(0)]],
    constant ChromaticAberrationParams& ca [[buffer(0)]]
) {
    float2 texSize = float2(lineTexture.get_width(), lineTexture.get_height());
    float2 uv = in.position.xy / texSize;

    // Early exit if CA disabled
    if (ca.intensity < 0.001) {
        constexpr sampler s(coord::pixel);
        return lineTexture.sample(s, in.position.xy);
    }

    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);

    float2 offsetR, offsetG, offsetB;

    if (ca.useRadialMode) {
        // Radial mode: offset from screen center
        float2 center = float2(0.5, 0.5);
        float2 fromCenter = uv - center;
        float dist = length(fromCenter);
        float2 dir = normalize(fromCenter + 1e-6);
        float falloff = pow(dist * 2.0, ca.radialPower);

        offsetR = dir * ca.redOffset * falloff / texSize;
        offsetG = dir * ca.greenOffset * falloff / texSize;
        offsetB = dir * ca.blueOffset * falloff / texSize;
    } else {
        // Uniform mode: fixed direction
        offsetR = ca.direction * ca.redOffset / texSize;
        offsetG = ca.direction * ca.greenOffset / texSize;
        offsetB = ca.direction * ca.blueOffset / texSize;
    }

    // Sample each channel at offset position
    float r = lineTexture.sample(s, uv + offsetR).r;
    float g = lineTexture.sample(s, uv + offsetG).g;
    float b = lineTexture.sample(s, uv + offsetB).b;
    float a = lineTexture.sample(s, uv).a;

    float4 aberrated = float4(r, g, b, a);
    float4 original = lineTexture.sample(s, uv);

    return mix(original, aberrated, ca.intensity);
}
```

### Step 4: Bind CA Buffer in `MetalRenderer.swift`

**Location:** Around line 735, after `setFragmentTexture`

First, add the Swift struct (in MetalRenderer or a shared file):

```swift
struct ChromaticAberrationParams {
    var intensity: Float
    var redOffset: Float
    var greenOffset: Float
    var blueOffset: Float
    var radialPower: Float
    var useRadialMode: Int32
    var direction: SIMD2<Float>
}
```

Then in the render function, before the `drawPrimitives` call:

```swift
// Create CA params from RenderConfigurations
var caParams = ChromaticAberrationParams(
    intensity: (renderConfigs?.chromaticAberrationEnabled ?? false)
        ? (renderConfigs?.chromaticAberrationIntensity ?? 0.0)
        : 0.0,
    redOffset: renderConfigs?.chromaticAberrationRedOffset ?? -2.0,
    greenOffset: renderConfigs?.chromaticAberrationGreenOffset ?? 0.0,
    blueOffset: renderConfigs?.chromaticAberrationBlueOffset ?? 2.0,
    radialPower: renderConfigs?.chromaticAberrationRadialPower ?? 2.0,
    useRadialMode: (renderConfigs?.chromaticAberrationUseRadialMode ?? true) ? 1 : 0,
    direction: SIMD2<Float>(
        cos(renderConfigs?.chromaticAberrationAngle ?? 0.0),
        sin(renderConfigs?.chromaticAberrationAngle ?? 0.0)
    )
)

computeToRenderRenderEncoder.setFragmentBytes(
    &caParams,
    length: MemoryLayout<ChromaticAberrationParams>.stride,
    index: 0
)
```

---

## Part 4: Advanced Approach - Per-Channel SDF Distance Offset

For those seeking more physically accurate chromatic aberration that interacts with the line rendering itself, here's how to modify the `drawLines` kernel:

### Concept

Instead of offsetting the final image, offset the pixel position when calculating distance to each line segment, separately for each color channel.

### Implementation Sketch

In `drawLines` kernel (around line 1028-1038), after calculating the base pixel position:

```metal
// Base pixel position
float2 p = float2(gid) + 0.5f;

// Per-channel offsets (from uniforms)
float2 caOffset = float2(U.caOffsetX, U.caOffsetY);
float caStrength = U.caStrength;

// Offset positions for R and B channels (G stays centered)
float2 p_r = p + caOffset * caStrength;
float2 p_b = p - caOffset * caStrength;
```

Then for each segment, calculate THREE distances:

```metal
// Distance for green channel (original)
float tLine = clamp((dot(p, b) - tgP0dotB[i]) * invL2, 0.0f, 1.0f);
float2 p_closest = tgP0[i] + tLine * b;
float d2_g = dot(p - p_closest, p - p_closest);

// Distance for red channel
float tLine_r = clamp((dot(p_r, b) - tgP0dotB[i]) * invL2, 0.0f, 1.0f);
float2 p_closest_r = tgP0[i] + tLine_r * b;
float d2_r = dot(p_r - p_closest_r, p_r - p_closest_r);

// Distance for blue channel
float tLine_b = clamp((dot(p_b, b) - tgP0dotB[i]) * invL2, 0.0f, 1.0f);
float2 p_closest_b = tgP0[i] + tLine_b * b;
float d2_b = dot(p_b - p_closest_b, p_b - p_closest_b);
```

This requires modifying the `PathFragment` struct and compositing logic to handle per-channel alpha values.

**Estimated additional complexity:** 4-6 hours of development, debugging, and tuning.

---

## Part 5: Artistic Presets

| Preset | Red | Green | Blue | Power | Mode | Effect |
|--------|-----|-------|------|-------|------|--------|
| Subtle | -1.0 | 0.0 | 1.0 | 2.0 | Radial | Barely visible fringing |
| Classic Lens | -3.0 | 0.0 | 3.0 | 1.5 | Radial | Film camera aesthetic |
| VHS Glitch | -8.0 | 2.0 | 8.0 | 0.5 | Radial | Heavy RGB split |
| Analog Drift | -4.0 | 0.0 | 4.0 | 1.0 | Uniform | Horizontal color shift |
| Prism | -5.0 | 0.0 | 5.0 | 1.0 | Radial | Rainbow edge effect |

---

## Part 6: Verification Plan

### Build Verification
1. Build project in Xcode - ensure no compilation errors
2. Check Metal shader compilation logs for warnings

### Visual Testing
1. Run with a high-contrast scene (white lines on black)
2. Set `chromaticAberrationIntensity` to 1.0 and offsets to extreme values (10px)
3. Verify RGB separation is visible at screen edges (radial mode)
4. Test uniform mode with different angles
5. Verify intensity=0 produces identical output to original

### Edge Cases
- Test at different resolutions (1080p, 4K, Retina)
- Verify no artifacts at screen edges (clamping works)
- Test with animated content (no temporal artifacts)

### Performance
- Profile with Instruments.app Metal System Trace
- Expected overhead: <0.1ms (3 texture samples vs 1)

---

## Part 7: Files to Modify Summary

| File | Changes |
|------|---------|
| `definitions.h` | Add `ChromaticAberrationParams` struct (~10 lines) |
| `RenderConfigurations.swift` | Add 8 `@Published` CA properties (~10 lines) |
| `Shaders.metal` | Replace `compute_fragment` (~40 lines) |
| `MetalRenderer.swift` | Add Swift struct + bind buffer (~25 lines) |

**Total:** ~85 lines of code across 4 files

---

## Part 8: Optional UI Controls

If you want UI sliders for the CA parameters, add to your settings view:

```swift
// In a SwiftUI settings view
Section("Chromatic Aberration") {
    Toggle("Enable", isOn: $renderConfigs.chromaticAberrationEnabled)

    if renderConfigs.chromaticAberrationEnabled {
        Slider(value: $renderConfigs.chromaticAberrationIntensity, in: 0...1) {
            Text("Intensity")
        }
        Slider(value: $renderConfigs.chromaticAberrationRedOffset, in: -20...0) {
            Text("Red Offset")
        }
        Slider(value: $renderConfigs.chromaticAberrationBlueOffset, in: 0...20) {
            Text("Blue Offset")
        }
        Slider(value: $renderConfigs.chromaticAberrationRadialPower, in: 0.5...3.0) {
            Text("Radial Power")
        }
        Toggle("Radial Mode", isOn: $renderConfigs.chromaticAberrationUseRadialMode)
    }
}
```

---

## Conclusion

The chromatic aberration effect can be cleanly added as a post-process step in `compute_fragment` with minimal code changes. The effect leverages the existing double-buffered texture system and follows the established pattern for shader parameters.

The recommended approach (post-process) provides:
- Immediate visual results
- Full artistic control via parameters
- Near-zero performance impact
- Clean separation from the core SDF rendering logic

For more advanced use cases, the per-channel SDF approach offers physically accurate aberration that interacts with line depth and overlap, at the cost of additional complexity and slightly higher GPU load.
