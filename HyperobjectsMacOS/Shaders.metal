//
//  Shaders.metal
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 02/01/2025.
//

#include <metal_stdlib>
#include "definitions.h"

using namespace metal;


constant uint SIMD_WIDTH = 32;
constant uint TG_ATOMICS_SIZE = 64; // Local bins for threadgroup accumulation



// Fast math helpers
[[clang::always_inline]]
inline float2 fastProjectToScreen(float4 clipPos, float2 viewSize) {
    float inv_w = fast::divide(1.0f, clipPos.w);
    float2 ndc = clamp(clipPos.xy * inv_w, -1.0f, 1.0f);
    return (ndc * 0.5f + 0.5f) * viewSize;
}

[[clang::always_inline]]
inline bool lineIntersectsBox(float2 p0, float2 p1, float2 boxMin, float2 boxMax, float radius) {
    float2 expandedMin = boxMin - radius;
    float2 expandedMax = boxMax + radius;
    
    float2 lineMin = min(p0, p1);
    float2 lineMax = max(p0, p1);
    
    bool2 noOverlap = (lineMax < expandedMin) | (lineMin > expandedMax);
    return !any(noOverlap);
}

[[clang::always_inline]]
inline void binRange(float2 mn, float2 mx, float2 viewPx,
                     thread uint& bx0, thread uint& by0,
                     thread uint& bx1, thread uint& by1) {
    // pixel inclusive rect
    int px0 = max(0, (int)floor(mn.x));
    int py0 = max(0, (int)floor(mn.y));
    int px1 = min((int)viewPx.x - 1, (int)ceil (mx.x) - 1);
    int py1 = min((int)viewPx.y - 1, (int)ceil (mx.y) - 1);
    
    if (px1 < px0 || py1 < py0) { bx0=1; bx1=0; by0=1; by1=0; return; } // empty
    
    bx0 = (uint)(px0) >> BIN_POW;
    by0 = (uint)(py0) >> BIN_POW;
    bx1 = (uint)(px1) >> BIN_POW;
    by1 = (uint)(py1) >> BIN_POW;
}


kernel void transformAndBinLinear(
    device const LinearSeg3D*               inSegs          [[buffer(0)]],
    constant float4x4&                      MVP             [[buffer(1)]],
    constant Uniforms&                      U               [[buffer(2)]],
    device LinearSegScreenSpace*            outSegs         [[buffer(3)]],
    device atomic_uint*                     binCounts       [[buffer(4)]],
    device uint*                            binOffsets      [[buffer(5)]],
    device uint*                            binList         [[buffer(6)]],
    constant uint&                          segCount        [[buffer(7)]],
    uint                                    gid             [[thread_position_in_grid]],
    uint                                    tid             [[thread_index_in_quadgroup]],
    uint                                    tg_size         [[threads_per_threadgroup]]
) {
    if (gid >= segCount) return;
    
    const LinearSeg3D S = inSegs[gid];
    
    if (length((S.p1_world - S.p0_world).xyz) < 1e-12f) return;
    
    // Project endpoints into clip space
    float4 p0c = MVP * S.p0_world;
    float4 p1c = MVP * S.p1_world;
    
    if (fabs(p0c.w) < 1e-8f || fabs(p1c.w) < 1e-8f) return;

    float2 view = float2(U.viewWidth, U.viewHeight);
    
    
    float inv_p0w = fast::divide(1.0f, p0c.w);
    float inv_p1w = fast::divide(1.0f, p1c.w);
    
    
    float2 p0ndc = clamp(p0c.xy * inv_p0w, -1.0f, 1.0f);
    float2 p1ndc = clamp(p1c.xy * inv_p1w, -1.0f, 1.0f);
    
    float2 p0ss = (p0ndc * 0.5f + 0.5f) * view;
    float2 p1ss = (p1ndc * 0.5f + 0.5f) * view;
    
    outSegs[gid].p0_ss = p0ss;
    outSegs[gid].p1_ss = p1ss;
    outSegs[gid].halfWidthPx = S.halfWidthPx;
    outSegs[gid].aaPx = U.antiAliasPx;
    
    // Expanded bbox (width + aa)
    float rad = S.halfWidthPx + U.antiAliasPx;
    float2 mn = floor(min(p0ss, p1ss) - rad);
    float2 mx = ceil (max(p0ss, p1ss) + rad);
    
    outSegs[gid].bboxMinSS = mn;
    outSegs[gid].bboxMaxSS = mx;
    
    // Screen reject vectorized
    bool2 outside_min = mx < 0.0f;
    bool2 outside_max = mn >= view;
    if(any(outside_min) || any(outside_max)) return;

    // Bin by bbox only (simple & over-inclusive)
    uint BIN_COLS = (uint)((view.x + BIN_SIZE - 1) / BIN_SIZE);
    float2 binSizeVec = float2(BIN_SIZE);
    
    // Threadgroup local atomic accumulation
    threadgroup atomic_uint tg_localCounts[TG_ATOMICS_SIZE];
    
    // Initialize once per threadgroup
    if (tid < TG_ATOMICS_SIZE) {
        atomic_store_explicit(&tg_localCounts[tid], 0u, memory_order_relaxed);
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    uint bx0,by0,bx1,by1;
    binRange(mn, mx, view, bx0,by0,bx1,by1);
    
    for (uint by = by0; by <= by1; ++by)
    for (uint bx = bx0; bx <= bx1; ++bx) {
        float2 binMin = float2(bx, by) * binSizeVec;
        float2 binMax = binMin + binSizeVec;
        
        
        if(!lineIntersectsBox(p0ss, p1ss, binMin, binMax, rad)) {
            continue;
        }
        
        uint bin  = by * BIN_COLS + bx;
        
        if (bin < TG_ATOMICS_SIZE) {
            atomic_fetch_add_explicit(&tg_localCounts[bin], 1u, memory_order_relaxed);
        } else {
            uint pos  = atomic_fetch_add_explicit(&binCounts[bin], 1u, memory_order_relaxed);
            binList[binOffsets[bin] + pos] = gid; // store index of outSegs
        }
    }
    
    // Flush threadgroup atomics to device memory
    threadgroup_barrier(mem_flags::mem_threadgroup);
    if (tid < TG_ATOMICS_SIZE) {
        uint local_count = atomic_load_explicit(&tg_localCounts[tid], memory_order_relaxed);
        if (local_count > 0) {
            uint pos = atomic_fetch_add_explicit(&binCounts[tid], local_count, memory_order_relaxed);
            // Note: This simplified version assumes single segment per thread
            // Full implementation would need a separate pass or different strategy
            // binList[binOffsets[tid] + pos] = gid;
        }
    }
};


kernel void drawLines(
    texture2d<half, access::write>      outTex      [[texture(0)]],
                      
    device const LinearSegScreenSpace*  segs        [[buffer(0)]],
    device const atomic_uint*           binCounts   [[buffer(1)]],
    device const uint*                  binOffsets  [[buffer(2)]],
    device const uint*                  binList     [[buffer(3)]],
    constant Uniforms&                  U           [[buffer(4)]],
                      
    ushort2                             tid         [[thread_position_in_threadgroup]],
    uint2                               gid         [[thread_position_in_grid]],
    uint                                simd_lane   [[thread_index_in_simdgroup]],
    uint                                simd_size   [[threads_per_simdgroup]]
) {
    const float2 p = float2(gid) + 0.5f;
    const float2 view = float2(U.viewWidth, U.viewHeight);
    
    // Bin lookup
    uint BIN_COLS = (uint)((view.x + BIN_SIZE - 1) / BIN_SIZE);
    uint bin = (gid.y >> BIN_POW) * BIN_COLS + (gid.x >> BIN_POW);
    
    // Single load of bin count (optimization: removed duplicate load)
    const uint total = atomic_load_explicit(&binCounts[bin], memory_order_relaxed);
    uint base = binOffsets[bin];
    
    // Threadgroup staging buffers - keeping separate arrays for better access patterns
    threadgroup float2 tgP0[KMAX_PER_BIN];
    threadgroup float2 tgP1[KMAX_PER_BIN];
    threadgroup float2 tgDir[KMAX_PER_BIN];
    threadgroup float2 tgPerp[KMAX_PER_BIN];
    threadgroup float tgLen[KMAX_PER_BIN];
    threadgroup float tgInvLen[KMAX_PER_BIN];
    threadgroup float tgHW[KMAX_PER_BIN];
    threadgroup float tgAA[KMAX_PER_BIN];
    threadgroup float2 tgMN[KMAX_PER_BIN];
    threadgroup float2 tgMX[KMAX_PER_BIN];
    threadgroup float tgR0_2[KMAX_PER_BIN];
    threadgroup float tgR1_2[KMAX_PER_BIN];
    
    float3 rgb = U.backgroundColor;
    float a = 0.0f;
    
     if (((bin & 1u) == 0u)) rgb += U.debugBins * float3(0.1);

     rgb += float3(float(total) / 10.0) * U.binVisibility;
    
    
    // Process batches
    uint processed = 0;
    while (processed < total && a < 0.99f) {
        const uint batch = min(KMAX_PER_BIN, total - processed);
        const uint start = base + processed;
        
        // Cooperative loading with SIMD optimization
        const uint lanes = BIN_SIZE * BIN_SIZE;
        const uint lane = tid.y * BIN_SIZE + tid.x;
        for (uint i = lane; i < batch; i += lanes) {
            const uint idx = binList[start + i];
            device const LinearSegScreenSpace* S = segs + idx;

            float2 p0 = S->p0_ss;
            float2 p1 = S->p1_ss;
            float2 ba = p1 - p0;
            float l2 = max(dot(ba, ba), 1e-12f);
            float invLen = fast::rsqrt(l2);  // Optimization: use fast rsqrt
            float len = l2 * invLen;      // Optimization: use fast sqrt instead of 1/invLen
            float2 dir = ba * invLen;
            float2 perp = float2(-dir.y, dir.x);

            float hw = S->halfWidthPx;
            float aa = S->aaPx;
            float r0 = max(hw - aa, 0.0f);
            float r1 = hw + aa;

            tgP0[i] = p0;
            tgP1[i] = p1;
            tgDir[i] = dir;
            tgPerp[i] = perp;
            tgLen[i] = len;
            tgInvLen[i] = invLen;
            tgMN[i] = S->bboxMinSS;
            tgMX[i] = S->bboxMaxSS;
            tgHW[i] = hw;
            tgAA[i] = aa;
            tgR0_2[i] = r0 * r0;
            tgR1_2[i] = r1 * r1;
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);

        // Process cached batch
        const uint C = batch;
        for (uint i = 0; i < C && a < 0.99f; ++i) {
            // Optimized bbox rejection using vector operations
            bool2 outside_min = p < tgMN[i];
            bool2 outside_max = p > tgMX[i];
            if (any(outside_min) || any(outside_max)) continue;

            float2 pa = p - tgP0[i];

            // Parallel & perpendicular components w.r.t. segment
            float s = dot(pa, tgDir[i]);        // signed distance along the segment
            float dp = dot(pa, tgPerp[i]);      // signed distance to the infinite line

            // Clamp to the finite segment
            float sClamped = clamp(s, 0.0f, tgLen[i]);

            // Closest point q = p0 + dir * sClamped
            float2 dq = pa - tgDir[i] * sClamped;

            // Squared distance from pixel to segment
            float d2 = dot(dq, dq);

            // Alpha via squared smoothstep: smoothstep(r1^2, r0^2, d^2)
            float r0_2 = tgR0_2[i];
            float r1_2 = tgR1_2[i];

            // If fully inside: early O(1) fill
            if (d2 <= r0_2) {
                float contrib = (1.0f - a);
                rgb += float3(1.0f) * contrib;
                a += contrib;
                continue;
            }
            
            // If fully outside: skip
            if (d2 > r1_2) {
                continue;
            }

            // Edge band: r0^2 .. r1^2
            float denom = max(r1_2 - r0_2, 1e-12f);
            float t = clamp((d2 - r0_2) / denom, 0.0f, 1.0f);
            float smooth = t * t * (3.0f - 2.0f * t);
            float alpha = 1.0f - smooth;

            float contrib = alpha * (1.0f - a);
            rgb += float3(1.0f) * contrib;
            a += contrib;
        }

        threadgroup_barrier(mem_flags::mem_threadgroup);
        processed += C;

        // Group-wide early exit if everyone is opaque
        if (simd_all(a >= 0.99f)) break;
    }
    
    // Use half precision for output (optimization)
    outTex.write(half4(half3(rgb), half(saturate(a))), gid);
};







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
