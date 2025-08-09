//
//  Shaders.metal
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 02/01/2025.
//

#include <metal_stdlib>
#include "definitions.h"

using namespace metal;

struct VertexUniforms {
    float4x4 projectionMatrix;  // 64 bytes
    float4x4 viewMatrix;        // 64 bytes
    float rotationAngle;        // 4 bytes
    float3 _padding;            // 12 bytes to align to 16 bytes
};



struct VertexOut {
    float4 position [[ position ]];
    float2 uv;
    float pointsize [[point_size]];
};

#define BIN_POW 4
#define BIN_SIZE (1 << BIN_POW)
#define lineCount 10000





////////////////////////////////////////////////////////////////////////////
// Path evaluation helpers

inline float2 eval_point(Shader_PathSeg S, float t) {
    float u = 1.0 - t;
    if (S.degree == 1) {
        return mix(S.p_screen[0], S.p_screen[1], t);
    } else if (S.degree == 2) {
        return u*u*S.p_screen[0] + 2.0*u*t*S.p_screen[1] + t*t*S.p_screen[2];
    } else {
        float uu = u*u; float tt = t*t;
        return uu*u*S.p_screen[0] + 3.0*uu*t*S.p_screen[1] + 3.0*u*tt*S.p_screen[2] + tt*t*S.p_screen[3];
    }
}




kernel void transformAndBin(
                            device Shader_PathSeg* lines [[buffer(0)]],
                            constant float4x4& MVP [[buffer(1)]],
                            constant TransformUniforms& U [[buffer(2)]],
                            device atomic_uint* binCounts [[buffer(3)]],
                            device uint* binOffsets [[buffer(4)]],
                            device uint* binList [[buffer(5)]],
                            uint gid [[thread_position_in_grid]]
                            ) {
    if (gid >= lineCount) return;
    Shader_PathSeg L = lines[gid];
    
    // Early culling: Skip degenerate lines where start and end are identical
    
    if (distance(L.p_world[0], L.p_world[1]) < 1e-8) {
        return; // Don't add to any bins
    }
    
    float2 viewSize = float2(U.viewWidth, U.viewHeight);
    
    float2 points[4];
    
    for (int i = 0; i <= L.degree; i++) {
        float4 p_clip = MVP * L.p_world[i];
        float2 p_screen = p_clip.xy / p_clip.w;
        p_screen = (p_screen * 0.5 + 0.5) * viewSize;
        lines[gid].p_screen[i] = p_screen;
        lines[gid].p_depth[i] = length(L.p_world[i].xyz - U.cameraPosition);
        lines[gid].p_inv_w[i] = 1.0 / p_clip.w;
        lines[gid].p_depth_over_w[i] = lines[gid].p_depth[i] / p_clip.w;
        points[i] = p_screen;
    }
    
    // build arc‑length LUT in screen space --------------------------------
    lines[gid].sLUT[0] = 0.0;
    float2 prev = eval_point(L, 0.0);
    float accum = 0.0;
    for(uint n=1; n<ARC_LUT_SAMPLES; ++n) {
        float t = float(n) / float(ARC_LUT_SAMPLES - 1);
        float2 pt = eval_point(lines[gid], t);
        accum += distance(pt, prev);
        lines[gid].sLUT[n] = accum;
        prev = pt;
    }
    lines[gid].segLengthPx = accum;
    
    uint BIN_COLS = (viewSize.x + BIN_SIZE - 1) / BIN_SIZE;
        
    float2 mn = floor(min(points[0], points[1]) - max(L.halfWidth0, L.halfWidth1) - L.antiAlias);
    float2 mx = ceil (max(points[0], points[1]) + max(L.halfWidth0, L.halfWidth1) + L.antiAlias);
    
    if (L.degree == 2) {
        mn = floor(min(mn, points[2]) - max(L.halfWidth0, L.halfWidth1) - L.antiAlias);
        mx = ceil (max(mx, points[2]) + max(L.halfWidth0, L.halfWidth1) + L.antiAlias);
    } else if (L.degree == 3) {
        mn = floor(min(mn, points[2]) - max(L.halfWidth0, L.halfWidth1) - L.antiAlias);
        mx = ceil (max(mx, points[2]) + max(L.halfWidth0, L.halfWidth1) + L.antiAlias);
        mn = floor(min(mn, points[3]) - max(L.halfWidth0, L.halfWidth1) - L.antiAlias);
        mx = ceil (max(mx, points[3]) + max(L.halfWidth0, L.halfWidth1) + L.antiAlias);
    }
    
    uint2 g0 = uint2(max(mn, 0.0));
    uint2 g1 = uint2(min(mx, viewSize - 1));

    for (uint y = g0.y >> BIN_POW; y <= g1.y >> BIN_POW; ++y)
    for (uint x = g0.x >> BIN_POW; x <= g1.x >> BIN_POW; ++x) {
        
        if(L.degree == 1) {
            // Calculate bin bounds (expand by line radius to account for thickness)
            float lineRadius = max(L.halfWidth0, L.halfWidth1) + L.antiAlias;
            float2 binMin = float2(x << BIN_POW, y << BIN_POW) - lineRadius;
            float2 binMax = binMin + BIN_SIZE + 2.0 * lineRadius;
            
            // Line-rectangle intersection test
            // Using parametric line equation: point = p0 + t * (p1 - p0)
            float2 lineDir = points[1] - points[0];
            float2 invDir = 1.0 / lineDir;
            
            // Calculate t values for intersection with bin edges
            float2 t1 = (binMin - points[0]) * invDir;
            float2 t2 = (binMax - points[0]) * invDir;
            
            // Handle division by zero (parallel lines)
            if (abs(lineDir.x) < 1e-6) {
                // Line is vertical - check if it's within bin's x range
                if (points[0].x >= binMin.x && points[0].x <= binMax.x) {
                    t1.x = -1000.0; // Allow intersection
                    t2.x = 1000.0;
                } else {
                    t1.x = 1000.0;  // No intersection
                    t2.x = -1000.0;
                }
            }
            if (abs(lineDir.y) < 1e-6) {
                // Line is horizontal - check if it's within bin's y range
                if (points[0].y >= binMin.y && points[0].y <= binMax.y) {
                    t1.y = -1000.0; // Allow intersection
                    t2.y = 1000.0;
                } else {
                    t1.y = 1000.0;  // No intersection
                    t2.y = -1000.0;
                }
            }
            
            // Ensure t1 <= t2
            float2 tMin = min(t1, t2);
            float2 tMax = max(t1, t2);
            
            // Find intersection interval
            float tEnter = max(tMin.x, tMin.y);
            float tExit = min(tMax.x, tMax.y);
            
            // Check if line segment intersects expanded bin
            bool intersects = (tEnter <= tExit) && (tExit >= 0.0) && (tEnter <= 1.0);
            
            if (intersects) {
                uint bin = y * BIN_COLS + x;
                uint pos = atomic_fetch_add_explicit(&binCounts[bin], 1u,
                                                    memory_order_relaxed);
                binList[binOffsets[bin] + pos] = gid;
            }
        } else {
            uint bin = y * BIN_COLS + x;
            uint pos = atomic_fetch_add_explicit(&binCounts[bin], 1u, memory_order_relaxed);
            binList[binOffsets[bin] + pos] = gid;
        }
    }
}




inline float2 eval_deriv(Shader_PathSeg S, float t) {
    if (S.degree == 1) {
        return S.p_screen[1] - S.p_screen[0];
    } else if (S.degree == 2) {
        return 2.0 * mix(S.p_screen[1] - S.p_screen[0], S.p_screen[2] - S.p_screen[1], t);
    } else {
        float u = 1.0 - t;
        return 3.0 * (u*u*(S.p_screen[1]-S.p_screen[0]) + 2.0*u*t*(S.p_screen[2]-S.p_screen[1]) + t*t*(S.p_screen[3]-S.p_screen[2]));
    }
}


inline float closestT(Shader_PathSeg S, float2 p) {
    float bestT = 0.0;
    float bestD = 1e9;
    const uint N = 16u;
    for (uint i = 0; i < N; i ++) {
        float t = float(i) / float(N);
        float d = distance(eval_point(S, t), p);
        if (d < bestD) {
            bestD = d;
            bestT = t;
        }
    }
    
    for (uint k=0; k < 3; k++) {
        float2 pt = eval_point(S, bestT);
        float2 dpt = eval_deriv(S, bestT);
        float2 r = pt - p;
        float f = dot(r, dpt);
        float g = dot(dpt, dpt) + dot(r, eval_deriv(S, bestT + 1e-3) - dpt) / 1e-3;
        float dt = (g == 0.0) ? 0.0 : f / g;
        bestT = clamp(bestT - dt, 0.0, 1.0);
    }
    return bestT;
}

inline float arcLenAtT(Shader_PathSeg S, float t) {
    float u = clamp(t, 0.0, 1.0) * float(ARC_LUT_SAMPLES - 1);
    uint  i = (uint)floor(u);
    float f = u - float(i);
    uint  j = min(i + 1u, (uint)ARC_LUT_SAMPLES - 1u);
    return mix(S.sLUT[i], S.sLUT[j], f);
}


inline float dashMaskPx(Shader_PathSeg S, float t) {
    if (S.dashCount == 0 || S.dashTotalPx <= 0.0) return 1.0; // solid
    float s = arcLenAtT(S, t) + S.dashPhasePx; // pixels from path origin
    float m = fmod(max(s, 0.0), S.dashTotalPx);
    float accum = 0.0;
    for (int i=0; i<S.dashCount; ++i) {
        float seg = S.dashPatternPx[i];
        if (m < accum + seg) {
            return (i & 1u) ? 0.0 : 1.0; // even=draw, odd=gap
        }
        accum += seg;
    }
    return 1.0;
}



////////////////////////////////////////////////////////////////////////////
// Path shader


kernel void drawLines(
                      texture2d<float, access::write> outTex [[texture(0)]],
                      device const Shader_PathSeg* lines [[buffer(0)]],
                      device const atomic_uint* binCounts [[buffer(1)]],
                      device const uint* binOffsets [[buffer(2)]],
                      device const uint* binList [[buffer(3)]],
                      constant TransformUniforms& U [[buffer(4)]],
                      ushort2 tid [[thread_position_in_threadgroup]],
                      uint2 gid [[thread_position_in_grid]]
                      ) {
    const uint2 pix = gid;
    const float2 p  = float2(pix) + 0.5;
    
    const float2 viewSize = float2(U.viewWidth, U.viewHeight);
    
    uint BIN_COLS = (viewSize.x + BIN_SIZE - 1) / BIN_SIZE;
    const uint  bin = (pix.y >> BIN_POW) * BIN_COLS + (pix.x >> BIN_POW);
    const uint  count = atomic_load_explicit(&binCounts[bin], memory_order_relaxed);
    const uint  base  = binOffsets[bin];
    
    
    constexpr uint MAX_PER_BIN = 32u;
    
    uint localIdx [MAX_PER_BIN];
    float localZ [MAX_PER_BIN];
    
    for (uint i = 0; i < MAX_PER_BIN; ++i) {
        localZ[i] = 1.0e9f;
        localIdx[i] = 0;
    }
    
    for (uint i = 0; i < count; ++i) {
        const uint line_idx = binList[base + i];
        const Shader_PathSeg L = lines[line_idx];
        
        // Calculate interpolated depth for the current pixel
        float2 pa = p - L.p_screen[0];
        float2 ba = L.p_screen[1] - L.p_screen[0];
        float ba_len2 = dot(ba, ba);
        float t = 0.0;
        if (ba_len2 > 1e-8) {
            t = clamp(dot(pa, ba) / ba_len2, 0.0, 1.0);
        }
        // float depth = mix(L.p0_depth, L.p1_depth, t);
        float inv_w = mix(L.p_inv_w[0], L.p_inv_w[1], t);
        float depth_over_w = mix(L.p_depth_over_w[0], L.p_depth_over_w[1], t);
        float depth = depth_over_w / inv_w;
        if (L.degree == 2) {
            float u = 1.0 - t;
            depth = u*u*L.p_depth[0] + 2.0*u*t*L.p_depth[1] + t*t*L.p_depth[2];
        } else if (L.degree == 3) {
            float u = 1.0 - t;
            float uu = u*u;
            float tt = t*t;
            depth = uu*u*L.p_depth[0] + 3.0*uu*t*L.p_depth[1] +
                    3.0*u*tt*L.p_depth[2] + tt*t*L.p_depth[3];
        }
        
        // 3. If this line is closer than the farthest one in our list, insert it
        if (depth < localZ[MAX_PER_BIN - 1]) {
            uint j = MAX_PER_BIN - 1;
            while (j > 0 && depth < localZ[j - 1]) {
                localZ[j] = localZ[j-1];
                localIdx[j] = localIdx[j-1];
                --j;
            }
            localZ[j] = depth;
            localIdx[j] = line_idx;
        }
    }
    
    // reverse localIdx

    uint localCnt = 0;
    while(localCnt < MAX_PER_BIN && localZ[localCnt] < 1.0e9f) {
        localCnt++;
    }
    
    float3 rgb = U.backgroundColor;
    float  a   = 0.0;
    float prevDepth = 1000000.0;
    
    // Intermediary bin size debug step. TODO: Add as render configuration to show localCnt
//    float debugIntensity = float(localCnt) / 32.0 * 2.0;
//    rgb += float3(debugIntensity, debugIntensity, debugIntensity);
//    a += debugIntensity;
//    
    for (uint i = 0; i < localCnt && a < 0.99; ++i) {
        const Shader_PathSeg L = lines[localIdx[i]];
        
        float2 pa = p - L.p_screen[0];
        float2 ba = L.p_screen[1] - L.p_screen[0];
        float ba_len2 = dot(ba, ba);
        float t, d, signedDistance;
        
        if (ba_len2 < 1e-8) {
            d = length(pa);
            t = 0;
        } else {
            // Time on path
            t = clamp(dot(pa, ba) / ba_len2, 0.0, 1.0);
            t = closestT(L, p);
            
            // Point on line
            float2 closest = L.p_screen[0] + ba * t;
            closest = eval_point(L, t);
            
            // Distance to pixel 2d vector
            // float2 toPixel = p - closest;
            
            // Distance to pixel float
            d = length(p - closest);
            float2 dpt = eval_deriv(L, t);
            float sign = (dot(p - closest, float2(-dpt.y, dpt.x)) > 0) ? 1.0 : -1.0;
            
            // 'Signed' distance to extended line
            // float2 lineDirection = normalize(ba);
            // float2 perpendicular = float2(-lineDirection.y, lineDirection.x); // 90° rotation
            signedDistance = d * sign;
        }
        
        float depth = mix(L.p_depth[0], L.p_depth[1], t);
        
        
        float halfWidth = mix(L.halfWidth0, L.halfWidth1, t);
        float aa = max(L.antiAlias, 0.0);
        float alphaEdge = smoothstep(halfWidth + aa, halfWidth - aa, d);
        
        alphaEdge *= dashMaskPx(L, t);
        if(alphaEdge <1e-3) continue;
        
        float4 innerColor = mix(L.colorPremul0, L.colorPremul1, t);
        
        float4 outerColorLeft = mix(L.colorPremul0OuterLeft, L.colorPremul1OuterLeft, t);
        float4 outerColorRight = mix(L.colorPremul0OuterRight, L.colorPremul1OuterRight, t);
        
        float sigmoidSteepness = mix(L.sigmoidSteepness0, L.sigmoidSteepness1, t);
        float sigmoidMidpoint = mix(L.sigmoidMidpoint0, L.sigmoidMidpoint1, t);
        
        float normalizedDistance = d / halfWidth;
        
        float finalSignedDistance = (ba_len2 < 1e-8) ? d : signedDistance;
        
        float2 perpendicular = normalize(float2(-ba.y, ba.x));
        
        float signedNormalizedDistance = signedDistance / halfWidth;
        
        float absDistance = abs(signedNormalizedDistance);
        float sigmoidInput = sigmoidSteepness * (absDistance - sigmoidMidpoint);
        float sigmoidValue = 1.0 / (1.0 + exp(-sigmoidInput));
        
        float4 outerColor = (signedNormalizedDistance >= 0.0) ? outerColorLeft : outerColorRight;
        
        // float4 color = mix(L.colorPremul0, L.colorPremul1, t);
        float4 color = mix(innerColor, outerColor, sigmoidValue);
        // float4 color = float4(absDistance, 1.0 - absDistance, 0.0, 1.0);
        // float4 color = outerColorLeft;
        // float4 color = outerColorRight;
        // float4 color = float4(sigmoidMidpoint, 1.0 - sigmoidMidpoint, 0.0, 1.0);
        // float4 color = float4(sigmoidSteepness, 1.0 - sigmoidSteepness, 0.0, 1.0);
        // color = float4(finalSignedDistance, 0.0, 0.0, 1.0);
        // color = float4(arcLenAtT(L, t) / 1.0, 1.0, 0.0, 1.0);
        // color = float4(L.sLUT[16], 1.0, 0.0, 1.0);
        
        // The alpha of the current line fragment considering its geometry
        float src_alpha = alphaEdge * color.w;
        
        // The accumulated alpha of everything drawn so far
        float occlusion = 1.0 - a;
        
        if (alphaEdge > 0.001) {
            if(depth < prevDepth) {
                rgb += color.xyz * alphaEdge * color.w * occlusion;
                a   += alphaEdge * color.w * occlusion;
            }
        }
    }
    a = clamp(a, 0.0, 1.0);
    
//    const float3 debugColor = float3((bin % 3 == 0), (bin % 3 == 1), (bin % 3 == 2));
//    outTex.write(float4(debugColor, 1.0), pix);
    
    if (false) {
        if (pix.x == U.viewWidth/2 && pix.y == U.viewHeight/2) {
            // Center pixel - visualize bin data
            outTex.write(float4(float(count) / 32.0, 0, 0, 1.0), pix);
            return;
        }
    }

//    if (pix.x == U.viewWidth/2 && pix.y == U.viewHeight/2) {
//        // Center pixel - visualize bin data
//        outTex.write(float4(float(count) / 32.0, 0, 0, 1.0), pix);
//        return;
//    }
    
    if (false) {
        // Or color-code bins by their content count
        float debugIntensity = float(count) / 32.0;
        outTex.write(float4(debugIntensity, debugIntensity, debugIntensity, 1.0), pix);
        return;
    }
    
     outTex.write(float4(rgb, a), pix);
}


// Backdrop shader is used to make visual the output of the compute shader part of the pipeline
// Backdrop vertex shader
vertex VertexOut compute_vertex(uint vertexID [[vertex_id]]) {
    VertexOut out;

    // Define vertices of a full-screen quad in NDC
    float2 vertices[4] = {
        float2(-1.0, -1.0),
        float2( 1.0, -1.0),
        float2(-1.0,  1.0),
        float2( 1.0,  1.0)
    };
    float2 uvs[4] = {
        float2(0.0, 0.0),
        float2(1.0, 0.0),
        float2(0.0, 1.0),
        float2(1.0, 1.0)
    };

    out.position = float4(vertices[vertexID], 0.0, 1.0);
    out.uv = uvs[vertexID];
    // UV coordinates corresponding to vertex positions
    // out.uv = vertices[vertexID] * 0.5 + 0.5;

    return out;
}

// Backdrop fragment shader
fragment float4 compute_fragment(float4 fragCoord [[position]], texture2d<float> lineTexture [[texture(0)]]) {
    constexpr sampler s(coord::pixel);
    return lineTexture.sample(s, fragCoord.xy);
}

// Vertex shader
vertex VertexOut vertex_main(const device float3* vertices [[ buffer(0) ]],
                          constant VertexUniforms& uniforms [[ buffer(1) ]],
                          uint vertexID [[ vertex_id ]]) {
    VertexOut out;
    // Mapping to clip space
    out.position = float4(
                          vertices[vertexID].x * 1.0,
                          vertices[vertexID].y * 1.0,
                          vertices[vertexID].z * 0.01 + 0.5,
                          1.0);
    out.pointsize = 5.0;
    
    return out;
}

// Fragment shader
fragment float4 fragment_main(const device float4* color [[ buffer(0) ]]) {
    
    Shader_Triangle test;
    return float4(1, 1, 1, 0.8);
    return *color;
}
