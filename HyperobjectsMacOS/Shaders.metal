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
constant float W_NEAR_CLIP = 1e-5f;

constant bool EMIT_JOIN_DISK = false;
constant uint MAX_TESSELLATION_STEPS = 256u;

struct SegAlloc {
    atomic_uint next;
    uint capacity;
};


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
    const float eps = 1e-4f;
    
    // pixel inclusive rect
    int px0 = max(0, (int)floor(mn.x));
    int py0 = max(0, (int)floor(mn.y));
    int px1 = min((int)viewPx.x - 1, (int)floor(mx.x - eps));
    int py1 = min((int)viewPx.y - 1, (int)floor(mx.y - eps));
    
    if (px1 < px0 || py1 < py0) { bx0=1; bx1=0; by0=1; by1=0; return; } // empty
    
    bx0 = (uint)(px0) >> BIN_POW;
    by0 = (uint)(py0) >> BIN_POW;
    bx1 = (uint)(px1) >> BIN_POW;
    by1 = (uint)(py1) >> BIN_POW;
}

// ---------------------------------------------------------------------------------
// Liang-Barsky helper function for clipping one boundary (e.g., x > -w)
// This is a core component of the line clipping algorithm.
// ---------------------------------------------------------------------------------
[[clang::always_inline]]
inline bool clipLine1D(float p, float q, thread float& t_min, thread float& t_max) {
    // p: numerator, q: denominator for the parametric intersection t = p/q
    if (fabs(p) < 1e-12f) { // Line is parallel to the boundary
        // If it's outside, the whole line is outside, so we reject it.
        if (q < 0.0f) return false;
    } else {
        float t = q / p;
        if (p < 0.0f) { // Line enters the clip region
            if (t > t_max) return false; // Enters after it has already left
            t_min = max(t_min, t);
        } else { // Line leaves the clip region
            if (t < t_min) return false; // Leaves before it has entered
            t_max = min(t_max, t);
        }
    }
    return (t_min <= t_max + 1e-9f); // If t_min >= t_max, the line is fully clipped
}


// ---------------------------------------------------------------------------------
// Full Liang-Barsky clipping in 4D homogeneous coordinates
// Rejects lines fully outside the view frustum and clips lines that are partially inside.
// ---------------------------------------------------------------------------------
[[clang::always_inline]]
bool liangBarskyClip(thread float4& p0c, thread float4& p1c, float2 rad_ndc) {
    float t_min = 0.0f;
    float t_max = 1.0f;
    float4 dp = p1c - p0c;

    // Expand boundaries to account for line width
    float2 expand = 1.0f + rad_ndc;

    // Right plane: x <= w * expand.x
    if (!clipLine1D(dp.x - dp.w * expand.x, p0c.w * expand.x - p0c.x, t_min, t_max)) return false;
    
    // Left plane: x >= -w * expand.x
    if (!clipLine1D(-dp.x - dp.w * expand.x, p0c.w * expand.x + p0c.x, t_min, t_max)) return false; // CORRECTED

    // Top plane: y <= w * expand.y
    if (!clipLine1D(dp.y - dp.w * expand.y, p0c.w * expand.y - p0c.y, t_min, t_max)) return false;

    // Bottom plane: y >= -w * expand.y
    if (!clipLine1D(-dp.y - dp.w * expand.y, p0c.w * expand.y + p0c.y, t_min, t_max)) return false; // CORRECTED

    // If clipping occurred, update the endpoints
    if (t_max < 1.0f) {
        p1c = p0c + dp * t_max;
    }
    if (t_min > 0.0f) {
        p0c = p0c + dp * t_min;
    }

    return true; // Line is visible
}


[[clang::always_inline]]
inline float4 evalBezierH(float4 p0, float4 p1, float4 p2, float t) {
    float4 a = mix(p0, p1, t);
    float4 b = mix(p1, p2, t);
    return mix(a, b, t);
}

[[clang::always_inline]]
inline float4 evalBezierH(float4 p0, float4 p1, float4 p2, float4 p3, float t) {
    float4 a = mix(p0, p1, t);
    float4 b = mix(p1, p2, t);
    float4 c = mix(p2, p3, t);
    float4 d = mix(a, b, t);
    float4 e = mix(b, c, t);
    return mix(d, e, t);
}

struct FD3 {
    float4 P;
    float4 d1;
    float4 d2;
    float4 d3;
};

[[clang::always_inline]]
inline void cubicPolyFromCtrl(
                              float4 p0,
                              float4 p1,
                              float4 p2,
                              float4 p3,
                              thread float4 &A,
                              thread float4 &B,
                              thread float4 &C,
                              thread float4 &D
                              ) {
    A = -p0 * 3.0f * p1 - 3.0f * p2 + p3;
    B = 3.0f * p0 - 6.0f * p1 + 3.0f * p2;
    C = -3.0f * p0 + 3.0f * p1;
    D = p0;
}

[[clang::always_inline]]
inline FD3 cubicFDInit(float4 p0,
                       float4 p1,
                       float4 p2,
                       float4 p3,
                       float dt) {
    float4 A,B,C,D;
    cubicPolyFromCtrl(p0, p1, p2, p3, A, B, C, D);
    float dt2 = dt * dt;
    float dt3 = dt2 * dt;
    FD3 fd;
    fd.P = D;
    fd.d1 = C * dt + B * dt2 + A * dt3;
    fd.d2 = 2.0f * B * dt2 + 6.0f * A * dt3;
    fd.d3 = 6.0f * A * dt3;
    return fd;
}

[[clang::always_inline]]
inline void cubicFDStep(thread FD3 & fd) {
    fd.P += fd.d1;
    fd.d1 += fd.d2;
    fd.d2 += fd.d3;
}

[[clang::always_inline]]
inline float2 clipToScreen(float4 Pc, float2 view) {
    float inv_w = fast::divide(1.0f, Pc.w);
    float2 ndc = clamp(Pc.xy * inv_w, -1.0f, 1.0f);
    return (ndc * 0.5f + 0.5f) * view;
}

[[clang::always_inline]]
inline uint estimateN_quadratic(float4 p0c, float4 p1c, float4 p2c, float2 view, float tolPx) {
    float2 s0 = clipToScreen(p0c, view);
    float2 s1 = clipToScreen(evalBezierH(p0c, p1c, p2c, 0.5f), view);
    float2 s2 = clipToScreen(p2c, view);
    float2 mid = 0.5f * (s0 + s2);
    float dev = length(s1 - mid);
    uint N = (uint)ceil(sqrt(max(dev, 0.0f) / max(tolPx, 1e-6f)));
    return clamp(N, 4u, 128u);
}

[[clang::always_inline]]
inline uint estimateN_cubic(float4 p0c, float4 p1c, float4 p2c, float4 p3c, float2 view, float tolPx) {
    float2 s0 = clipToScreen(p0c, view);
    float2 s33 = clipToScreen(evalBezierH(p0c, p1c, p2c, p3c, 1.0f / 3.0f), view);
    float2 s66 = clipToScreen(evalBezierH(p0c, p1c, p2c, p3c, 2.0f / 3.0f), view);
    float2 s1 = clipToScreen(p3c, view);
    float dev1 = length(s33 - (2.0f * s0 + s1) / 3.0f);
    float dev2 = length(s66 - (s0 + 2.0f * s1) / 3.0f);
    float dev = max(dev1, dev2);
    uint N = (uint)ceil(sqrt(max(dev, 0.0f) / max(tolPx, 1e-6f)));
    return clamp(N, 4u, 128u);
}

[[clang::always_inline]]
static inline bool isInsideClipNoExpand(float4 pc) {
    if (pc.w <= W_NEAR_CLIP) return false;
    return (-pc.w <= pc.x && pc.x <= pc.w) &&
           (-pc.w <= pc.y && pc.y <= pc.w);
}


inline void emitJoinDisk(float2 centerSS, float rad, float2 view,
                         device LinearSegScreenSpace* outSegs,
                         device SegAlloc* alloc,
                         device atomic_uint* binCounts,
                         device uint* binOffsets,
                         device uint* binList) {
    const uint BIN_COLS = (uint)((view.x + BIN_SIZE - 1) / BIN_SIZE);
    const float2 binSizeVec = float2(BIN_SIZE);
    
    uint outIdx = atomic_fetch_add_explicit(&alloc->next, 1u, memory_order_relaxed);
    if (outIdx >= alloc->capacity) return;

    float2 mn = floor(centerSS - rad);
    float2 mx = ceil (centerSS + rad);

    outSegs[outIdx].p0_ss = centerSS; // degenerate: disk
    outSegs[outIdx].p1_ss = centerSS; // degenerate: disk
    outSegs[outIdx].halfWidthPx = rad; // NOTE: use S.halfWidthPx
    outSegs[outIdx].aaPx = 0.0f; // NOTE: AA handled by the main shader band
    outSegs[outIdx].bboxMinSS = mn;
    outSegs[outIdx].bboxMaxSS = mx;

    uint bx0,by0,bx1,by1; binRange(mn, mx, view, bx0,by0,bx1,by1);
    for (uint by = by0; by <= by1; ++by)
    for (uint bx = bx0; bx <= bx1; ++bx) {
        float2 binMin = float2(bx, by) * binSizeVec;
        float2 binMax = binMin + binSizeVec;
        if (!lineIntersectsBox(centerSS, centerSS, binMin, binMax, rad)) continue;
        uint bin = by * BIN_COLS + bx;
        uint pos = atomic_fetch_add_explicit(&binCounts[bin], 1u, memory_order_relaxed);
        binList[binOffsets[bin] + pos] = outIdx;
    }
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
    device SegAlloc*                        alloc           [[buffer(8)]],
    uint                                    gid             [[thread_position_in_grid]]
) {
    if (gid >= segCount) return;
    
    const LinearSeg3D S = inSegs[gid];
    
    if (length((S.p1_world - S.p0_world).xyz) < 1e-12f) return;
    
    // Project endpoints into clip space
    float4 p0c = MVP * S.p0_world;
    float4 p1c = MVP * S.p1_world;
    
    // ---------------------------------------------------------------------------------
    // Culling and Clipping Pipeline
    // ---------------------------------------------------------------------------------

    // 1. Trivial reject if both points are behind the near plane (Requirement 1)
    if (p0c.w < W_NEAR_CLIP && p1c.w < W_NEAR_CLIP) return;

    
    float4 original_p0c = p0c;
    float4 original_p1c = p1c;
    
    // 2. Clip segment to the near plane (w > W_NEAR_CLIP)
    if (original_p0c.w < W_NEAR_CLIP) {
        float t = (W_NEAR_CLIP - original_p0c.w) / (original_p1c.w - original_p0c.w);
        p0c = mix(original_p0c, original_p1c, t);
    }
    if (original_p1c.w < W_NEAR_CLIP) {
        float t = (W_NEAR_CLIP - original_p1c.w) / (original_p0c.w - original_p1c.w);
        p1c = mix(original_p1c, original_p0c, t);
    }

    // 3. Clip against view frustum sides (Requirements 2 & 3)
    float rad = S.halfWidthPx + U.antiAliasPx;
    float2 view = float2(U.viewWidth, U.viewHeight);
    
    // Convert screen-space radius to NDC-space radius for boundary expansion
    float2 rad_ndc = rad * 2.0 / view;
    
    if (!liangBarskyClip(p0c, p1c, rad_ndc)) {
        return; // Line is fully outside the view
    }

    // ---------------------------------------------------------------------------------
    // Continue with processing for the now-clipped line
    // ---------------------------------------------------------------------------------
    
    float2 p0ss = clipToScreen(p0c, view);
    float2 p1ss = clipToScreen(p1c, view);
    
    // Expanded bbox (width + aa)
    float2 mn = floor(min(p0ss, p1ss) - rad);
    float2 mx = ceil (max(p0ss, p1ss) + rad);
    
    // Screen reject vectorized
    bool2 outside_min = mx < 0.0f;
    bool2 outside_max = mn >= view;
    if(any(outside_min) || any(outside_max)) return;
    
    
    uint outIdx = atomic_fetch_add_explicit(&alloc->next, 1u, memory_order_relaxed);
    if (outIdx >= alloc->capacity) return;
    
    
    outSegs[outIdx].p0_ss = p0ss;
    outSegs[outIdx].p1_ss = p1ss;
    outSegs[outIdx].halfWidthPx = S.halfWidthPx;
    outSegs[outIdx].aaPx = U.antiAliasPx;
    outSegs[outIdx].bboxMinSS = mn;
    outSegs[outIdx].bboxMaxSS = mx;
    outSegs[outIdx].colorStartCenter  = S.colorStartCenter;
    outSegs[outIdx].colorEndCenter  = S.colorEndCenter;
    
    outSegs[outIdx].z0_clip = p0c.z;
    outSegs[outIdx].w0_clip = p0c.w;
    outSegs[outIdx].z1_clip = p1c.z;
    outSegs[outIdx].w1_clip = p1c.w;
    
    outSegs[outIdx].pathID = gid;
    outSegs[outIdx].segIndex = 0;
    outSegs[outIdx].totalSegs = 1;
 

    // Bin by bbox only (simple & over-inclusive)
    uint BIN_COLS = (uint)((view.x + BIN_SIZE - 1) / BIN_SIZE);
        
    uint bx0,by0,bx1,by1;
    binRange(mn, mx, view, bx0,by0,bx1,by1);
    
    for (uint by = by0; by <= by1; ++by)
    for (uint bx = bx0; bx <= bx1; ++bx) {
        uint bin  = by * BIN_COLS + bx;
        uint pos  = atomic_fetch_add_explicit(&binCounts[bin], 1u, memory_order_relaxed);
        binList[binOffsets[bin] + pos] = outIdx; // store index of outSegs
    }
    
    // Flush threadgroup atomics to device memory
    threadgroup_barrier(mem_flags::mem_threadgroup);
};










constant float TOLERANCE_MIN = 0.1f;


kernel void transformAndBinQuadratic(
    device const QuadraticSeg3D*            curves          [[buffer(0)]],
    constant float4x4&                      MVP             [[buffer(1)]],
    constant Uniforms&                      U               [[buffer(2)]],
    device LinearSegScreenSpace*            outSegs         [[buffer(3)]],
    device atomic_uint*                     binCounts       [[buffer(4)]],
    device uint*                            binOffsets      [[buffer(5)]],
    device uint*                            binList         [[buffer(6)]],
    constant uint&                          curveCount      [[buffer(7)]],
    device SegAlloc*                        alloc           [[buffer(8)]],
    uint                                    gid             [[thread_position_in_grid]]
                                     ) {
    if (gid >= curveCount) return;
    const QuadraticSeg3D S = curves[gid];
    
    float2 view = float2(U.viewWidth, U.viewHeight);
    float rad = S.halfWidthPx + U.antiAliasPx;
    
    // Control points to clips space
    float4 p0c = MVP * S.p0_world;
    float4 p1c = MVP * S.p1_world;
    float4 p2c = MVP * S.p2_world;
    
    if (p0c.w < W_NEAR_CLIP &&
        p1c.w < W_NEAR_CLIP &&
        p2c.w < W_NEAR_CLIP) return;
    
    const float tolPx = min(TOLERANCE_MIN, U.antiAliasPx * 0.75f);
    uint N = estimateN_quadratic(p0c, p1c, p2c, view, tolPx);
    
    
    float dt = 1.0f / float(N);
    
    float4 prevC = p0c;
    
    uint BIN_COLS = (uint)((view.x + BIN_SIZE - 1) / BIN_SIZE);
    float2 binSizeVec = float2(BIN_SIZE);
    
    const float2 rad_ndc = float2( (2.0f * rad) / max(view.x, 1.0f),
                                  (2.0f * rad) / max(view.y, 1.0f) );
    
    float t = 0.0f;
    
    for (uint i = 0; i < N; i++) {
        float tn = min(1.0f, t + dt);
        float4 currC = evalBezierH(p0c, p1c, p2c, tn);
        
        float4 c0 = prevC;
        float4 c1 = currC;
        
        float4 original_c0 = c0;
        float4 original_c1 = c1;
        
        // Stabilize before Liang-Barsky
        if (original_c0.w < W_NEAR_CLIP && original_c1.w < W_NEAR_CLIP) { /* drop */ }
        if (original_c0.w < W_NEAR_CLIP) {
            float tW = (W_NEAR_CLIP - original_c0.w) / (original_c1.w - original_c0.w + 1e-20f);
            c0 = mix(original_c0, original_c1, tW);
        }
        if (original_c1.w < W_NEAR_CLIP) {
            float tW = (W_NEAR_CLIP - original_c1.w) / (original_c0.w - original_c1.w + 1e-20f);
            c1 = mix(original_c1, original_c0, tW);
        }
        
        bool visible = liangBarskyClip(c0, c1, rad_ndc);
        
        if (visible) {
            
            bool inside0 = isInsideClipNoExpand(c0);
            bool inside1 = isInsideClipNoExpand(c1);
            if(!inside0 && inside1) {
                float4 tmp = c0;
                c0 = c1;
                c1 = tmp;
            }
            
            float2 s0 = clipToScreen(c0, view);
            float2 s1 = clipToScreen(c1, view);
            
            float2 mn = floor(min(s0, s1) - rad);
            float2 mx = ceil (max(s0, s1) + rad);
            
            bool2 outside_min = mx < 0.0f;
            bool2 outside_max = mn >= view;
            
            if(!(any(outside_min) || any(outside_max))) {
                uint outIdx = atomic_fetch_add_explicit(&alloc->next, 1u, memory_order_relaxed);
                if (outIdx < alloc->capacity) {
                    outSegs[outIdx].p0_ss = s0;
                    outSegs[outIdx].p1_ss = s1;
                    outSegs[outIdx].halfWidthPx = S.halfWidthPx;
                    outSegs[outIdx].aaPx = U.antiAliasPx;
                    outSegs[outIdx].bboxMinSS = mn;
                    outSegs[outIdx].bboxMaxSS = mx;
                    outSegs[outIdx].colorStartCenter = float4(1.0, 1.0, 1.0, 1.0);
                    outSegs[outIdx].colorEndCenter = float4(1.0, 1.0, 1.0, 1.0);
                    
                    outSegs[outIdx].z0_clip = c0.z;
                    outSegs[outIdx].w0_clip = c0.w;
                    outSegs[outIdx].z1_clip = c1.z;
                    outSegs[outIdx].w1_clip = c1.w;
                    
                    outSegs[outIdx].pathID = gid;
                    outSegs[outIdx].segIndex = i;
                    outSegs[outIdx].totalSegs = N;
                    
                    uint bx0, by0, bx1, by1;
                    binRange(mn, mx, view, bx0, by0, bx1, by1);
                    
                    for (uint by = by0; by <= by1; ++by)
                    for (uint bx = bx0; bx <= bx1; ++bx) {
                        uint bin = by * BIN_COLS + bx;
                        uint pos = atomic_fetch_add_explicit(&binCounts[bin], 1u, memory_order_relaxed);
                        binList[binOffsets[bin] + pos] = outIdx;
                    }
                }
                
                if ((i > 0 && i < N) && EMIT_JOIN_DISK) { // FIX: one micro‑disk per interior joint
                    float2 jointSS = s0; // the shared endpoint of this and previous segment after clipping
                    emitJoinDisk(jointSS, S.halfWidthPx, view, outSegs, alloc, binCounts, binOffsets, binList);
                }
            }
        }
        prevC = currC;
        t = tn;
    }
}







kernel void transformAndBinCubic(
    device const CubicSeg3D*                curves          [[buffer(0)]],
    constant float4x4&                      MVP             [[buffer(1)]],
    constant Uniforms&                      U               [[buffer(2)]],
    device LinearSegScreenSpace*            outSegs         [[buffer(3)]],
    device atomic_uint*                     binCounts       [[buffer(4)]],
    device uint*                            binOffsets      [[buffer(5)]],
    device uint*                            binList         [[buffer(6)]],
    constant uint&                          curveCount      [[buffer(7)]],
    device SegAlloc*                        alloc           [[buffer(8)]],
    uint                                    gid             [[thread_position_in_grid]]
                                 ) {
    if (gid >= curveCount) return;
    
    const CubicSeg3D S = curves[gid];
    
    const float2 view = float2(U.viewWidth, U.viewHeight);
    const float rad = S.halfWidthPx + U.antiAliasPx;
    
    float4 p0c = MVP * S.p0_world;
    float4 p1c = MVP * S.p1_world;
    float4 p2c = MVP * S.p2_world;
    float4 p3c = MVP * S.p3_world;

    // Early reject: all behind near plane
    if (p0c.w < W_NEAR_CLIP &&
        p1c.w < W_NEAR_CLIP &&
        p2c.w < W_NEAR_CLIP &&
        p3c.w < W_NEAR_CLIP) return;
    
    // Segment count estimation (pixel tolerance)
    const float tolPx = min(TOLERANCE_MIN, U.antiAliasPx * 0.75f);
    const uint  N     = max(1u, estimateN_cubic(p0c, p1c, p2c, p3c, view, tolPx));
    const float dt    = 1.0f / float(N);

    // Stroke radius in NDC used by your clipper’s plane expansion
    const float2 rad_ndc = float2( (2.0f * rad) / max(view.x, 1.0f),
                                   (2.0f * rad) / max(view.y, 1.0f) );

    // Bin grid invariants
    const uint   BIN_COLS   = (uint)((view.x + BIN_SIZE - 1) / BIN_SIZE);
    const float2 binSizeVec = float2(BIN_SIZE);

    // March in clip space; clip each linear step with Liang–Barsky (expanded)
    float t  = 0.0f;
    float4 prevC = p0c;
    
    for (uint i = 0; i < N; i++) {
        const float tn = min(1.0f, t + dt);
        const float4 currC = evalBezierH(p0c, p1c, p2c, p3c, tn);

        // Clip the clip-space segment against expanded clip box
        float4 c0 = prevC;
        float4 c1 = currC;
        
        float4 original_c0 = c0;
        float4 original_c1 = c1;
        
        
        // Stabilize before Liang-Barsky
        if (original_c0.w < W_NEAR_CLIP && original_c1.w < W_NEAR_CLIP) { /* drop */ }
        if (original_c0.w < W_NEAR_CLIP) {
            float tW = (W_NEAR_CLIP - original_c0.w) / (original_c1.w - original_c0.w + 1e-20f);
            c0 = mix(original_c0, original_c1, tW);
        }
        if (original_c1.w < W_NEAR_CLIP) {
            float tW = (W_NEAR_CLIP - original_c1.w) / (original_c0.w - original_c1.w + 1e-20f);
            c1 = mix(original_c1, original_c0, tW);
        }
        
        
        if (liangBarskyClip(c0, c1, rad_ndc)) {
            // Direction rule: if exactly one endpoint is truly inside (no expansion), start from the inside
             const bool in0 = isInsideClipNoExpand(c0);
             const bool in1 = isInsideClipNoExpand(c1);
             if (!in0 && in1) { float4 tmp = c0; c0 = c1; c1 = tmp; }

            // Project clipped endpoints to screen space
            const float2 s0 = clipToScreen(c0, view);
            const float2 s1 = clipToScreen(c1, view);

            // Conservative bbox of the *clipped* segment
            float2 mn = floor(min(s0, s1) - rad);
            float2 mx = ceil (max(s0, s1) + rad);

            // Quick reject vs screen rect
            const bool2 outside_min = mx < 0.0f;
            const bool2 outside_max = mn >= view;
            
            if (!(any(outside_min) || any(outside_max))) {
                const uint outIdx = atomic_fetch_add_explicit(&alloc->next, 1u, memory_order_relaxed);
                if (outIdx < alloc->capacity) {
                    // Emit the *clipped* linear piece in screen space
                    outSegs[outIdx].p0_ss       = s0;
                    outSegs[outIdx].p1_ss       = s1;
                    outSegs[outIdx].halfWidthPx = S.halfWidthPx;
                    outSegs[outIdx].aaPx        = U.antiAliasPx;
                    outSegs[outIdx].bboxMinSS   = mn;
                    outSegs[outIdx].bboxMaxSS   = mx;
                    outSegs[outIdx].colorStartCenter = mix(S.colorStartCenter, S.colorEndCenter, t);
                    outSegs[outIdx].colorEndCenter  = mix(S.colorStartCenter, S.colorEndCenter, tn);

                    outSegs[outIdx].z0_clip = c0.z;
                    outSegs[outIdx].w0_clip = c0.w;
                    outSegs[outIdx].z1_clip = c1.z;
                    outSegs[outIdx].w1_clip = c1.w;
                    
                    outSegs[outIdx].pathID = gid;
                    outSegs[outIdx].segIndex = i;
                    outSegs[outIdx].totalSegs = N;
                    
                    
                    uint bx0, by0, bx1, by1;
                    binRange(mn, mx, view, bx0, by0, bx1, by1);

                    for (uint by = by0; by <= by1; ++by)
                    for (uint bx = bx0; bx <= bx1; ++bx) {
                        // const float2 binMin = float2(bx, by) * binSizeVec;
                        // const float2 binMax = binMin + binSizeVec;
                        // if (!lineIntersectsBox(s0, s1, binMin, binMax, rad)) continue;

                        const uint bin = by * BIN_COLS + bx;
                        const uint pos = atomic_fetch_add_explicit(&binCounts[bin], 1u, memory_order_relaxed);
                        binList[binOffsets[bin] + pos] = outIdx;
                    }
                    
                    if ((i > 0 && i < N) && EMIT_JOIN_DISK) { // FIX: one micro‑disk per interior joint
                        float2 jointSS = s0; // the shared endpoint of this and previous segment after clipping
                        emitJoinDisk(jointSS, S.halfWidthPx, view, outSegs, alloc, binCounts, binOffsets, binList);
                    }
                }
            }
        }
        prevC = currC;
        t = tn;
    }
}






















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
    threadgroup float4 tgColorStartCenter[KMAX_PER_BIN];
    threadgroup float4 tgColorEndCenter[KMAX_PER_BIN];
    
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
            tgColorStartCenter[i] = S->colorStartCenter;
            tgColorEndCenter[i] = S->colorEndCenter;
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);

        // Process cached batch
        const uint C = batch;
        for (uint i = 0; i < C; ++i) {
            // Optimized bbox rejection using vector operations
            bool2 outside_min = p < tgMN[i];
            bool2 outside_max = p > tgMX[i];
            if (any(outside_min) || any(outside_max)) continue;

            // Bounding box debug
            rgb += float3(0.0, 0.4, 1.0) * U.boundingBoxVisibility;
            
            float2 pa = p - tgP0[i];

            // Parallel & perpendicular components w.r.t. segment
            float s = dot(pa, tgDir[i]);        // signed distance along the segment
            float dp = dot(pa, tgPerp[i]);      // signed distance to the infinite line
            

            // Clamp to the finite segment
            float overlap = tgHW[i] + tgAA[i]; // Allow capsules to overlap at joints
            float sClamped = clamp(s, -overlap, tgLen[i] + overlap);

            // Closest point q = p0 + dir * sClamped
            float2 dq = pa - tgDir[i] * sClamped;

            // Squared distance from pixel to segment
            float d2 = dot(dq, dq);

            // Alpha via squared smoothstep: smoothstep(r1^2, r0^2, d^2)
            float r0_2 = tgR0_2[i];
            float r1_2 = tgR1_2[i];
            
            // Edge band: r0^2 .. r1^2
            float denom = max(r1_2 - r0_2, 1e-12f);
            float t = clamp((d2 - r0_2) / denom, 0.0f, 1.0f);
            
            
            float2 ba = tgP1[i] - tgP0[i];
            float ba_len2 = dot(ba, ba);
            float tLine = clamp(dot(pa, ba) / ba_len2, 0.0, 1.0);
            float2 pClosest = mix(tgP0[i], tgP1[i], tLine);
            
            float d = length(p - pClosest);
            
            float finalSignedDistance = (ba_len2 < 1e-8) ? d : sClamped;
            
            
            float4 color = mix(
                               tgColorStartCenter[i],
                               tgColorEndCenter[i],
                               tLine) * U.lineColorStrength
            + mix(float4(U.lineDebugGradientStartColor, 1.0),
                  float4(U.lineDebugGradientEndColor, 1.0),
                  tLine) * U.lineDebugGradientStrength;
            
            if(d > tgHW[i]) continue;
            
            float alpha = smoothstep(tgHW[i] + tgAA[i], tgHW[i] - tgAA[i], d);

            // Add this line's color, weighted by its alpha
            rgb += float3(color.xyz) * alpha;
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
