# Scene-Controlled Render Configuration Overrides

This document explains how scenes can programmatically override render configuration values (chromatic aberration, background color, blend settings) without modifying the UI controls.

## Overview

The override system provides two hooks for scenes to control render parameters:

1. **Geometry-time overrides**: Called once when geometries are regenerated (e.g., when audio input changes). Values persist until the next geometry generation.

2. **Render-time overrides**: Called every frame during rendering. Use this for smooth per-frame animations.

Both hooks receive context about the current state (frame count, audio levels, input values) and return optional overrides. When a property is `nil`, the UI value is used. When non-nil, the override takes precedence.

## Quick Start

```swift
let scene = GeometriesSceneBase(
    name: "My Scene",
    inputs: [
        SceneInput(name: "Intensity", type: .float, value: 0.5, range: 0...1)
    ],
    geometryGenerators: [myGenerator]
)

// Override chromatic aberration based on input value
scene.geometryTimeOverride = { context in
    let intensity = context.inputs["Intensity"] as? Float ?? 0.5
    return RenderConfigurationOverrides(
        chromaticAberrationEnabled: true,
        chromaticAberrationIntensity: intensity * 2.0
    )
}

// Animate the aberration angle every frame
scene.renderTimeOverride = { context in
    let angle = Float(context.frameStamp) * 0.01
    return RenderConfigurationOverrides(
        chromaticAberrationAngle: angle
    )
}
```

## API Reference

### RenderOverrideContext

Context passed to both override closures:

```swift
struct RenderOverrideContext {
    let frameStamp: Int              // Frame counter, increments each audio tick
    let audioSignal: Float           // Current smoothed audio level (0-1)
    let audioSignalProcessed: Double // Processed audio signal (envelope-shaped)
    let inputs: [String: Any]        // Dictionary of scene input values by name
}
```

### RenderConfigurationOverrides

Struct containing optional override values. All properties default to `nil` (use UI value).

```swift
struct RenderConfigurationOverrides {
    // Chromatic Aberration
    var chromaticAberrationEnabled: Bool?
    var chromaticAberrationIntensity: Float?
    var chromaticAberrationRedOffset: Float?
    var chromaticAberrationGreenOffset: Float?
    var chromaticAberrationBlueOffset: Float?
    var chromaticAberrationRadialPower: Float?
    var chromaticAberrationUseRadialMode: Bool?
    var chromaticAberrationAngle: Float?
    var chromaticAberrationUseSpectralMode: Bool?
    var chromaticAberrationDispersionStrength: Float?
    var chromaticAberrationReferenceWavelength: Float?

    // Background & Blending
    var backgroundColor: SIMD3<Float>?
    var blendRadius: Float?
    var blendIntensity: Float?
    var previousColorVisibility: Float?
    var lineColorStrength: Float?

    static let none = RenderConfigurationOverrides()

    func merged(with other: RenderConfigurationOverrides) -> RenderConfigurationOverrides
}
```

### GeometriesSceneBase Properties

```swift
// Called during setWrappedGeometries() - values cached until next generation
var geometryTimeOverride: ((RenderOverrideContext) -> RenderConfigurationOverrides)?

// Called every frame in render() - for per-frame animation
var renderTimeOverride: ((RenderOverrideContext) -> RenderConfigurationOverrides)?
```

## Override Precedence

When both geometry-time and render-time overrides are set, they are merged with render-time taking precedence:

```
Final Value = render-time override ?? geometry-time override ?? UI value
```

This allows geometry-time to set baseline values that render-time can selectively animate.

## Usage Patterns

### Pattern 1: Audio-Reactive Chromatic Aberration

```swift
scene.geometryTimeOverride = { context in
    // Scale intensity with audio
    let intensity = Float(context.audioSignalProcessed) * 3.0
    return RenderConfigurationOverrides(
        chromaticAberrationEnabled: intensity > 0.1,
        chromaticAberrationIntensity: intensity
    )
}
```

### Pattern 2: Input-Controlled Background

```swift
scene.geometryTimeOverride = { context in
    let r = context.inputs["Red"] as? Float ?? 0.0
    let g = context.inputs["Green"] as? Float ?? 0.0
    let b = context.inputs["Blue"] as? Float ?? 0.0
    return RenderConfigurationOverrides(
        backgroundColor: SIMD3<Float>(r, g, b)
    )
}
```

### Pattern 3: Animated Effect with Static Base

```swift
// Set base configuration at geometry-time
scene.geometryTimeOverride = { context in
    return RenderConfigurationOverrides(
        chromaticAberrationEnabled: true,
        chromaticAberrationIntensity: 1.0,
        chromaticAberrationUseRadialMode: false
    )
}

// Animate angle at render-time
scene.renderTimeOverride = { context in
    let t = Float(context.frameStamp) * 0.02
    return RenderConfigurationOverrides(
        chromaticAberrationAngle: sin(t) * .pi
    )
}
```

### Pattern 4: Conditional Overrides

```swift
scene.geometryTimeOverride = { context in
    let mode = context.inputs["Effect Mode"] as? Int ?? 0

    switch mode {
    case 0: // No effect
        return .none
    case 1: // Subtle
        return RenderConfigurationOverrides(
            chromaticAberrationEnabled: true,
            chromaticAberrationIntensity: 0.3
        )
    case 2: // Intense
        return RenderConfigurationOverrides(
            chromaticAberrationEnabled: true,
            chromaticAberrationIntensity: 2.0,
            blendIntensity: 0.5
        )
    default:
        return .none
    }
}
```

## Architecture

### Data Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                        GeometriesSceneBase                          │
│                                                                     │
│  ┌─────────────────────┐    ┌─────────────────────────────────┐    │
│  │ geometryTimeOverride │    │ cachedRenderOverrides (Atomic)  │    │
│  │      (closure)       │───▶│   Persists between frames       │    │
│  └─────────────────────┘    └─────────────────────────────────┘    │
│                                           │                         │
│  ┌─────────────────────┐                  │                         │
│  │ renderTimeOverride  │                  │                         │
│  │     (closure)       │──────────────────┼─────────┐               │
│  └─────────────────────┘                  │         │               │
└───────────────────────────────────────────┼─────────┼───────────────┘
                                            │         │
                                            ▼         ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          MetalRenderer                              │
│                                                                     │
│  render() {                                                         │
│      overrides = getEffectiveOverrides()                            │
│      // Merges cached + render-time                                 │
│                                                                     │
│      // Apply to uniforms and CA params:                            │
│      lineColorStrength: resolve(overrides.lineColorStrength, ui)    │
│      caIntensity: resolve(overrides.chromaticAberrationIntensity,ui)│
│      ...                                                            │
│  }                                                                  │
└─────────────────────────────────────────────────────────────────────┘
```

### File Locations

| File | Purpose |
|------|---------|
| `Models/Classes/RenderConfigurations.swift` | Defines `RenderOverrideContext` and `RenderConfigurationOverrides` structs |
| `Models/Classes/GeometriesSceneBase.swift` | Holds override closures and cached overrides |
| `Views/RenderView/MetalRenderer.swift` | Applies overrides during rendering |

### Thread Safety

- `cachedRenderOverrides` uses the `Atomic<T>` wrapper for thread-safe access
- Geometry-time overrides run on the main thread during `setWrappedGeometries()`
- Render-time overrides run on the render thread in `render()`
- The `RenderConfigurationOverrides` struct uses value types (`Float`, `Bool`, `SIMD3<Float>`) for safe cross-thread passing

### Key Methods

**GeometriesSceneBase:**
- `makeOverrideContext()` - Builds context struct from current scene state
- `setWrappedGeometries()` - Generates geometries and computes geometry-time overrides

**MetalRenderer:**
- `getEffectiveOverrides()` - Merges geometry-time and render-time overrides
- `resolve(_:_:)` - Returns override value if non-nil, otherwise UI value

## Extending the System

To add a new overridable property:

1. Add the property to `RenderConfigurationOverrides` in `RenderConfigurations.swift`:
   ```swift
   var myNewProperty: Float?
   ```

2. Add merge logic in `merged(with:)`:
   ```swift
   result.myNewProperty = other.myNewProperty ?? self.myNewProperty
   ```

3. Apply the override in `MetalRenderer.render()`:
   ```swift
   let value = resolve(overrides.myNewProperty, renderConfigs?.myNewProperty ?? defaultValue)
   ```

## Troubleshooting

**Override not applying:**
- Verify the closure is assigned before `setWrappedGeometries()` is called
- Check that you're returning a non-nil value for the property
- For render-time overrides, ensure `renderTimeOverride` is set (not just `geometryTimeOverride`)

**Performance concerns:**
- Geometry-time closures run once per geometry generation, so complex logic is acceptable
- Render-time closures run every frame - keep them lightweight
- Avoid allocations in render-time closures; use simple arithmetic

**Thread issues:**
- Don't capture mutable state in render-time closures
- Use the provided `context` parameter instead of accessing scene properties directly
