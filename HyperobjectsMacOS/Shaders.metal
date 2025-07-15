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
#define lineCount 1000

kernel void transformAndBin(
                            device Shader_Line* lines [[buffer(0)]],
                            constant float4x4& MVP [[buffer(1)]],
                            constant TransformUniforms& U [[buffer(2)]],
                            device atomic_uint* binCounts [[buffer(3)]],
                            device uint* binOffsets [[buffer(4)]],
                            device uint* binList [[buffer(5)]],
                            uint gid [[thread_position_in_grid]]
                            ) {
    if (gid >= lineCount) return;
    Shader_Line L = lines[gid];
    float4 p0_clip = MVP * float4(L.p0_world, 1);
    float4 p1_clip = MVP * float4(L.p1_world, 1);
    
    // L.p0_depth = p0_clip.z / max(p0_clip.w, 1e-6);
    // L.p1_depth = p1_clip.z / max(p1_clip.w, 1e-6);
    
    L.p0_depth = length(L.p0_world - U.cameraPosition);
    L.p1_depth = length(L.p1_world - U.cameraPosition);
    
    // 2. Perform the perspective divide to get NDC
    float2 p0 = p0_clip.xy / p0_clip.w;
    float2 p1 = p1_clip.xy / p1_clip.w;
    
    float2 viewSize = float2(U.viewWidth, U.viewHeight);
    
    p0 = (p0 * 0.5 + 0.5) * viewSize;
    p1 = (p1 * 0.5 + 0.5) * viewSize;
    
    lines[gid].p0_screen = p0;
    lines[gid].p1_screen = p1;
    lines[gid].p0_depth = L.p0_depth;
    lines[gid].p1_depth = L.p1_depth;
    
    uint BIN_COLS = (viewSize.x + BIN_SIZE - 1) / BIN_SIZE;
    
    float2 mn = floor(min(p0, p1) - max(L.halfWidth0, L.halfWidth1) - L.antiAlias);
    float2 mx = ceil (max(p0, p1) + max(L.halfWidth0, L.halfWidth1) + L.antiAlias);
    
    uint2 g0 = uint2(max(mn, 0.0));
    uint2 g1 = uint2(min(mx, viewSize - 1));
    for (uint y = g0.y >> BIN_POW; y <= g1.y >> BIN_POW; ++y)
    for (uint x = g0.x >> BIN_POW; x <= g1.x >> BIN_POW; ++x) {
        uint bin = y * BIN_COLS + x;
        uint  pos = atomic_fetch_add_explicit(&binCounts[bin], 1u,
                                              memory_order_relaxed);
        binList[binOffsets[bin] + pos] = gid;    }
}


kernel void drawLines(
                      texture2d<float, access::write> outTex [[texture(0)]],
                      device const Shader_Line* lines [[buffer(0)]],
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
    
    
    const uint MAX_LINES_PER_BIN = min(count, 32u);
    // const uint MAX_LINES_PER_BIN = count;
    
    constexpr uint MAX_PER_BIN = 32u;
    
    uint localIdx [MAX_PER_BIN];
    float localZ [MAX_PER_BIN];
    
    for (uint i = 0; i < MAX_PER_BIN; ++i) {
        localZ[i] = 1.0e9f;
        localIdx[i] = 0;
    }
    
    for (uint i = 0; i < count; ++i) {
        const uint line_idx = binList[base + i];
        const Shader_Line L = lines[line_idx];
        
        // Calculate interpolated depth for the current pixel
        float2 pa = p - L.p0_screen;
        float2 ba = L.p1_screen - L.p0_screen;
        float ba_len2 = dot(ba, ba);
        float t = 0.0;
        if (ba_len2 > 1e-8) {
            t = clamp(dot(pa, ba) / ba_len2, 0.0, 1.0);
        }
        float depth = mix(L.p0_depth, L.p1_depth, t);
        
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
    
    float3 rgb = 0.0;
    float  a   = 0.0;
    float prevDepth = 1000000.0;
    
    for (uint i = 0; i < localCnt && a < 0.99; ++i) {
        const Shader_Line L = lines[localIdx[i]];
        
        float2 pa = p - L.p0_screen;
        float2 ba = L.p1_screen - L.p0_screen;
        float ba_len2 = dot(ba, ba);
        float t, d;
        
        if (ba_len2 < 1e-8) {
            d = length(pa);
            t = 0;
        } else {
            t = clamp(dot(pa, ba) / ba_len2, 0.0, 1.0);
            float2 closest = L.p0_screen + ba * t;
            d = length(p - closest);
        }
        
        float depth = mix(L.p0_depth, L.p1_depth, t);
        
        
        float halfWidth = mix(L.halfWidth0, L.halfWidth1, t);
        float aa = max(L.antiAlias, 0.0);
        float alphaEdge = smoothstep(halfWidth + aa, halfWidth - aa, d);
        float4 color = mix(L.colorPremul0, L.colorPremul1, t);
        
        // The alpha of the current line fragment considering its geometry
        float src_alpha = alphaEdge * color.w;
        
        // The accumulated alpha of everything drawn so far
        float occlusion = 1.0 - a;
        
        if (alphaEdge > 0.001) {
            if(depth < prevDepth) {
                // rgb = float3(L.p0_depth, 0.1, 0.1);
                rgb = color.xyz;
                a = 1.0;
                prevDepth = depth;
            }
        }
        
        
        // Blend the new line on top
//        rgb += color.xyz * alphaEdge * occlusion; // Correct: Apply only geometric alpha
//        a   += src_alpha * occlusion;
    }
    a = clamp(a, 0.0, 1.0);
    
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
