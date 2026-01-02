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
    outSegs[outIdx].halfWidthStartPx = rad; // NOTE: use S.halfWidthPx
    outSegs[outIdx].halfWidthEndPx = rad; // NOTE: use S.halfWidthPx
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

static inline bool rectIntersectsSegmentLB(
                                           float2 p0,
                                           float2 d,
                                           float inv_dx,
                                           float inv_dy,
                                           float x0,
                                           float y0,
                                           float x1,
                                           float y1
                                           ) {
    float t0 = 0.0f;
    float t1 = 1.0f;

    // Left:  x >= x0
    {
        const float p = d.x;
        const float q = x0 - p0.x;
        if (p == 0.0f) { if (p0.x < x0) return false; }
        else {
            const float t = q * inv_dx; // q/p
            if (p > 0.0f) { if (t > t1) return false; t0 = max(t0, t); }
            else          { if (t < t0) return false; t1 = min(t1, t); }
        }
    }
    // Right: x <= x1
    {
        const float p = d.x;
        const float q = x1 - p0.x;
        if (p == 0.0f) { if (p0.x > x1) return false; }
        else {
            const float t = q * inv_dx;
            if (p < 0.0f) { if (t > t1) return false; t0 = max(t0, t); }
            else          { if (t < t0) return false; t1 = min(t1, t); }
        }
    }
    // Bottom: y >= y0
    {
        const float p = d.y;
        const float q = y0 - p0.y;
        if (p == 0.0f) { if (p0.y < y0) return false; }
        else {
            const float t = q * inv_dy;
            if (p > 0.0f) { if (t > t1) return false; t0 = max(t0, t); }
            else          { if (t < t0) return false; t1 = min(t1, t); }
        }
    }
    // Top: y <= y1
    {
        const float p = d.y;
        const float q = y1 - p0.y;
        if (p == 0.0f) { if (p0.y > y1) return false; }
        else {
            const float t = q * inv_dy;
            if (p < 0.0f) { if (t > t1) return false; t0 = max(t0, t); }
            else          { if (t < t0) return false; t1 = min(t1, t); }
        }
    }
    return t0 <= t1;
}

static inline bool diskIntersectsAABB(float2 c, float r, float x0, float y0, float x1, float y1)
{
    // Closest point on AABB to center
    const float cx = clamp(c.x, x0, x1);
    const float cy = clamp(c.y, y0, y1);
    const float dx = c.x - cx;
    const float dy = c.y - cy;
    return (dx*dx + dy*dy) <= (r*r);
}

inline float bellRemapPower(float u, float k) {
    float s = smoothstep(0.0, 1.0, u);
    s = pow(s, k);
    return s * 2.0 - 1.0;
}

inline uint hashCombine(uint a, uint b) {
    a ^= b + 0x9e3779b9u + (a<<6) + (a>>b);
    return a;
}

inline uint hashStep(uint x) {
    x ^= x >> 17;
    x *= 0xed5ad4bbu;
    x ^= x >> 11;
    x *= 0xac4c1b51u;
    x ^= x >> 15;
    x *= 0x31848babu;
    x ^= x >> 14;
    return x;
}

inline float hash2D_uint(uint2 p, uint seed) {
    uint h = hashCombine(p.x * 0x85ebca6bu ^ p.y * 0xc2b2ae35u, seed);
    h = hashStep(h);
    return (float(h) / 4294967295.0f); // [0,1]
}
inline float2 rand2_uint(uint2 p, uint seed) {
    return float2(hash2D_uint(p, seed),
                  hash2D_uint(p ^ uint2(0x68e31d4u, 0x27d4eb2du), seed ^ 0x165667b1u));
}



uint hash3(uint x, uint y, uint p) {
    uint h = x * 73856093u ^ y * 19349663u ^ p * 83492791u;
    // Optional avalanching
    h ^= h >> 13;
    h *= 0x5bd1e995u;
    h ^= h >> 15;
    return h;
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
    device float4*                          randomValues    [[buffer(9)]],
    uint                                    gid             [[thread_position_in_grid]]
) {
    if (gid >= segCount) return;
    
    const LinearSeg3D S = inSegs[gid];
    
    if (length((S.p1_world - S.p0_world).xyz) < 1e-12f) return;
    
    // Project endpoints into clip space
    float4 p0c = MVP * S.p0_world;
    float4 p1c = MVP * S.p1_world;
    
    // [... existing clipping logic unchanged ...]
    if (p0c.w < W_NEAR_CLIP && p1c.w < W_NEAR_CLIP) return;
    
    float4 original_p0c = p0c;
    float4 original_p1c = p1c;
    
    if (original_p0c.w < W_NEAR_CLIP) {
        float t = (W_NEAR_CLIP - original_p0c.w) / (original_p1c.w - original_p0c.w);
        p0c = mix(original_p0c, original_p1c, t);
    }
    if (original_p1c.w < W_NEAR_CLIP) {
        float t = (W_NEAR_CLIP - original_p1c.w) / (original_p0c.w - original_p1c.w);
        p1c = mix(original_p1c, original_p0c, t);
    }

    float radMax = max(S.halfWidthStartPx, S.halfWidthEndPx) + U.antiAliasPx;
    float2 view = float2(U.viewWidth, U.viewHeight);
    float2 rad_ndc = radMax * 2.0 / view;
    
    if (!liangBarskyClip(p0c, p1c, rad_ndc)) {
        return;
    }
    
    const float4 randomVec = randomValues[gid % 1000];
    
    // TODO: SAVING THIS FOR LATER FUN!
//    float2 p0ss = clipToScreen(p0c + randomVec * 0.1, view);
//    float2 p1ss = clipToScreen(p1c + randomVec * 0.1, view);
    float2 p0ss = clipToScreen(p0c, view);
    float2 p1ss = clipToScreen(p1c, view);
    
    // Expanded bbox
    float2 mn = floor(min(p0ss, p1ss) - radMax);
    float2 mx = ceil (max(p0ss, p1ss) + radMax);

    
    bool2 outside_min = mx < 0.0f;
    bool2 outside_max = mn >= view;
    if(any(outside_min) || any(outside_max)) return;
    
    const float2 d = p1ss - p0ss;
    const float line_len_sq = dot(d, d);
    
    // Bin grid
    const uint BIN_COLS = (uint)((view.x + BIN_SIZE - 1) / BIN_SIZE);
    const uint BIN_ROWS = (uint)((view.y + BIN_SIZE - 1) / BIN_SIZE);
    
    // --- Single-emit state ---
    bool emitted = false;
    uint outIdx = 0;
    
    

    auto emitOnce = [&](){
        if (emitted) return;
        const uint idx = atomic_fetch_add_explicit(&alloc->next, 1u, memory_order_relaxed);
        if (idx >= alloc->capacity) return;
        outIdx = idx;

        outSegs[idx].p0_ss = p0ss;
        outSegs[idx].p1_ss = p1ss;
        outSegs[idx].halfWidthStartPx = S.halfWidthStartPx;
        outSegs[idx].halfWidthEndPx = S.halfWidthEndPx;
        outSegs[idx].aaPx = U.antiAliasPx;
        outSegs[outIdx].noiseFloor = S.noiseFloor;
        outSegs[idx].bboxMinSS = mn;
        outSegs[idx].bboxMaxSS = mx;
        outSegs[idx].colorStartCenter = S.colorStartCenter;
        outSegs[idx].colorEndCenter   = S.colorEndCenter;
        outSegs[idx].z0_clip = p0c.z; outSegs[idx].w0_clip = p0c.w;
        outSegs[idx].z1_clip = p1c.z; outSegs[idx].w1_clip = p1c.w;
        outSegs[idx].pathID  = S.pathID;
        outSegs[idx].segIndex = 0;
        outSegs[idx].totalSegs = 1;

        emitted = true;
    };

    auto pushToBin = [&](uint bx, uint by){
        const uint bin = by * BIN_COLS + bx;
        const uint pos = atomic_fetch_add_explicit(&binCounts[bin], 1u, memory_order_relaxed);
        binList[binOffsets[bin] + pos] = outIdx;
    };

    // -------------------------------
    // SIMPLE GRID SCAN APPROACH
    // -------------------------------
    
    // Calculate bin bounds from the expanded bbox
    uint bx0, by0, bx1, by1;
    binRange(mn, mx, view, bx0, by0, bx1, by1);
    
    // Handle degenerate case (point/disk)
    if (line_len_sq <= 1e-9f) {
        for (uint by = by0; by <= by1; ++by)
        for (uint bx = bx0; bx <= bx1; ++bx) {
            // Test if bin intersects with disk at p0ss
            const float x0 = float(bx * BIN_SIZE);
            const float y0 = float(by * BIN_SIZE);
            const float x1 = x0 + BIN_SIZE;
            const float y1 = y0 + BIN_SIZE;
            
            if (diskIntersectsAABB(p0ss, radMax, x0, y0, x1, y1)) {
                emitOnce();
                if (!emitted) return;
                pushToBin(bx, by);
            }
        }
        return;
    }
    
    for (uint by = by0; by <= by1; ++by)
    for (uint bx = bx0; bx <= bx1; ++bx) {
        // Bin AABB
        const float x0 = float(bx * BIN_SIZE);
        const float y0 = float(by * BIN_SIZE);
        const float x1 = x0 + BIN_SIZE;
        const float y1 = y0 + BIN_SIZE;
        
        // Test if this bin intersects with the rounded line (body + caps)
        bool intersects = false;
        
        // 1. Check body intersection (segment vs expanded AABB)
        const float eps = 1e-12f;
        const float inv_dx = (fabs(d.x) > eps) ? fast::divide(1.0f, d.x) : (d.x >= 0.0f ? INFINITY : -INFINITY);
        const float inv_dy = (fabs(d.y) > eps) ? fast::divide(1.0f, d.y) : (d.y >= 0.0f ? INFINITY : -INFINITY);
        
        if (rectIntersectsSegmentLB(p0ss, d, inv_dx, inv_dy, x0 - radMax, y0 - radMax, x1 + radMax, y1 + radMax)) {
            intersects = true;
        }
        
        // 2. If body doesn't intersect, check cap intersections
        if (!intersects) {
            // Start cap
            if (diskIntersectsAABB(p0ss, radMax, x0, y0, x1, y1)) {
                intersects = true;
            }
            // End cap
            else if (diskIntersectsAABB(p1ss, radMax, x0, y0, x1, y1)) {
                intersects = true;
            }
        }
        
        if (intersects) {
            emitOnce();
            if (!emitted) return;
            pushToBin(bx, by);
        }
    }
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
    float rad = max(S.halfWidthStartPx, S.halfWidthEndPx) + U.antiAliasPx;
    
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
                    // TODO: INTERPOLATE
                    outSegs[outIdx].halfWidthStartPx = mix(S.halfWidthStartPx, S.halfWidthEndPx, t);
                    outSegs[outIdx].halfWidthEndPx = mix(S.halfWidthStartPx, S.halfWidthEndPx, tn);
                    outSegs[outIdx].aaPx = U.antiAliasPx;
                    outSegs[outIdx].noiseFloor = S.noiseFloor;
                    outSegs[outIdx].bboxMinSS = mn;
                    outSegs[outIdx].bboxMaxSS = mx;
                    outSegs[outIdx].colorStartCenter = mix(S.colorStartCenter, S.colorEndCenter, t);
                    outSegs[outIdx].colorEndCenter = mix(S.colorStartCenter, S.colorEndCenter, tn);
                    
                    outSegs[outIdx].z0_clip = c0.z;
                    outSegs[outIdx].w0_clip = c0.w;
                    outSegs[outIdx].z1_clip = c1.z;
                    outSegs[outIdx].w1_clip = c1.w;
                    
                    outSegs[outIdx].pathID = S.pathID;
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
                    emitJoinDisk(jointSS, S.halfWidthEndPx, view, outSegs, alloc, binCounts, binOffsets, binList);
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
    const float rad = max(S.halfWidthStartPx, S.halfWidthEndPx) + U.antiAliasPx;
    
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
                    // TODO: INTERPOLATE
                    outSegs[outIdx].halfWidthStartPx = mix(S.halfWidthStartPx, S.halfWidthEndPx, t);
                    outSegs[outIdx].halfWidthEndPx = mix(S.halfWidthStartPx, S.halfWidthEndPx, tn);
                    outSegs[outIdx].aaPx        = U.antiAliasPx;
                    outSegs[outIdx].noiseFloor = S.noiseFloor;
                    outSegs[outIdx].bboxMinSS   = mn;
                    outSegs[outIdx].bboxMaxSS   = mx;
                    outSegs[outIdx].colorStartCenter = mix(S.colorStartCenter, S.colorEndCenter, t);
                    outSegs[outIdx].colorEndCenter  = mix(S.colorStartCenter, S.colorEndCenter, tn);

                    outSegs[outIdx].z0_clip = c0.z;
                    outSegs[outIdx].w0_clip = c0.w;
                    outSegs[outIdx].z1_clip = c1.z;
                    outSegs[outIdx].w1_clip = c1.w;
                    
                    outSegs[outIdx].pathID = S.pathID;
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
                        emitJoinDisk(jointSS, S.halfWidthEndPx, view, outSegs, alloc, binCounts, binOffsets, binList);
                    }
                }
            }
        }
        prevC = currC;
        t = tn;
    }
}


















struct PathFragment {
    float depth;
    uint pathID;
    float min_dist_sq;
    float t_param;
    
    float4 colorStart;
    float4 colorEnd;
    float2 p0;
    float2 p1;
    float hwStart;
    float hwEnd;
    float aa;
    float noiseFloor;
};


kernel void drawLines(
    texture2d<half, access::read_write>     outTex          [[texture(0)]],
    device const LinearSegScreenSpace*      segs            [[buffer(0)]],
    device const atomic_uint*               binCounts       [[buffer(1)]],
    device const uint*                      binOffsets      [[buffer(2)]],
    device const uint*                      binList         [[buffer(3)]],
    constant Uniforms&                      U               [[buffer(4)]],
    device float4*                          randomValues    [[buffer(5)]],
    ushort2                                 tid             [[thread_position_in_threadgroup]],
    uint2                                   gid             [[thread_position_in_grid]]
) {
    const uint K_BUFFER_SIZE = 4;
    constexpr float Z_FIGHTING_EPSILON = 1e-5f;
    
    const int pxIndex = int(gid.x) + int(gid.y);
    float4 randomVec = randomValues[pxIndex % 1000];
    
    float2 randomVecXY = randomVec.xy;
    float2 randomVecXYMapped = float2(
                                      bellRemapPower(randomVecXY.x, 1),
                                      bellRemapPower(randomVecXY.y, 1)
                                      );
    
    float2 p = float2(gid) + 0.5f;
    
//    p -= randomVecXYMapped * 25.0;
//    p.x = clamp(p.x, 0.0, float(gid.x) + 0.5f);
//    p.y = clamp(p.y, 0.0, float(gid.y) + 0.5f);
    
    const float2 view = float2(U.viewWidth, U.viewHeight);
    
    // Bin lookup
    uint BIN_COLS = (uint)((view.x + BIN_SIZE - 1) / BIN_SIZE);
    uint bin = (gid.y >> BIN_POW) * BIN_COLS + (gid.x >> BIN_POW);
    
    // Single load of bin count (optimization: removed duplicate load)
    const uint total = atomic_load_explicit(&binCounts[bin], memory_order_relaxed);
    uint base = binOffsets[bin];
    
    // Threadgroup staging buffers - keeping separate arrays for better access patterns
    threadgroup uint tgPathID[KMAX_PER_BIN];
    threadgroup float2 tgP0[KMAX_PER_BIN];
    threadgroup float2 tgP1[KMAX_PER_BIN];
    threadgroup float tgInvW0[KMAX_PER_BIN];
    threadgroup float tgInvW1[KMAX_PER_BIN];
    threadgroup float tgZ_over_W0[KMAX_PER_BIN];
    threadgroup float tgZ_over_W1[KMAX_PER_BIN];
    threadgroup float tgHWStart[KMAX_PER_BIN];
    threadgroup float tgHWEnd[KMAX_PER_BIN];
    threadgroup float tgAA[KMAX_PER_BIN];
    threadgroup float2 tgMN[KMAX_PER_BIN];
    threadgroup float2 tgMX[KMAX_PER_BIN];
    threadgroup float2 tgB[KMAX_PER_BIN];
    threadgroup float tgInvL2[KMAX_PER_BIN];
    threadgroup float tgP0dotB[KMAX_PER_BIN];
    threadgroup float tgR2[KMAX_PER_BIN];
    threadgroup float4 tgColorStartCenter[KMAX_PER_BIN];
    threadgroup float4 tgColorEndCenter[KMAX_PER_BIN];
    
    threadgroup float tgNoiseFloor[KMAX_PER_BIN];
    
    PathFragment pathFragments[K_BUFFER_SIZE];
    for (uint i = 0; i < K_BUFFER_SIZE; ++i) {
        pathFragments[i].depth = FLT_MAX;
    }
    
    half4 prev = outTex.read(gid);
    float3 final_rgb = U.backgroundColor;
    final_rgb = final_rgb + float3(prev.rgb) * U.previousColorVisibility;
    
    
    // Path aware fragment collection
    uint processed = 0;
    while (processed < total) {
        const uint batch = min(KMAX_PER_BIN, total - processed);
        const uint start = base + processed;
        
        // Cooperative loading with SIMD optimization
        const uint lanes = BIN_SIZE * BIN_SIZE;
        const uint lane = tid.y * BIN_SIZE + tid.x;
        for (uint i = lane; i < batch; i += lanes) {
            const uint idx = binList[start + i];
            device const LinearSegScreenSpace* S = segs + idx;

            float inv_w0 = 1.0f / S->w0_clip;
            float inv_w1 = 1.0f / S->w1_clip;
            
            float hwStart = S->halfWidthStartPx;
            float hwEnd = S->halfWidthEndPx;
            float hwMax = max(hwStart,hwEnd);
            float aa = S->aaPx;
            
            float pad = hwMax + aa;
            float2 mn = S->bboxMinSS;
            float2 mx = S->bboxMaxSS;
            mn -= float2(pad, pad);
            mx += float2(pad, pad);
            
            float2 b = S->p1_ss - S-> p0_ss;
            float l2 = max(dot(b, b), 1e-9f);

            tgPathID[i] = S->pathID;
            tgP0[i] = S->p0_ss;
            tgP1[i] = S->p1_ss;
            tgMN[i] = mn;
            tgMX[i] = mx;
            tgInvW0[i] = inv_w0;
            tgInvW1[i] = inv_w1;
            tgZ_over_W0[i] = S->z0_clip * inv_w0;
            tgZ_over_W1[i] = S->z1_clip * inv_w1;
            tgHWStart[i] = hwStart;
            tgHWEnd[i] = hwEnd;
            tgAA[i] = aa;
            tgB[i] = b;
            tgInvL2[i] = 1.0f / l2;
            tgP0dotB[i] = dot(S->p0_ss, b);
            tgR2[i] = (hwMax + S->aaPx) * (hwMax + S->aaPx);
            tgColorStartCenter[i] = S->colorStartCenter;
            tgColorEndCenter[i] = S->colorEndCenter;
            tgNoiseFloor[i] = S->noiseFloor;
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
        
        
        
        
        // Extract into pathFragments
        
        for (uint i = 0; i < batch; ++i) {
            // Discard if point is out of bounds
            if (any (p < tgMN[i]) || any(p > tgMX[i])) continue;
            
            // Bounding box debug
            final_rgb += float3(0.0, 0.4, 1.0) * U.boundingBoxVisibility;
            
            
            float2 b = tgB[i];
            float invL2 = tgInvL2[i];
            
            
            float tLine = clamp((dot(p, b) - tgP0dotB[i]) * invL2, 0.0f, 1.0f);
            // float tLine = clamp((dot(p_sample, b) - tgP0dotB[i]) * invL2, 0.0f, 1.0f);

        
            float2 p_closest = tgP0[i] + tLine * b;
            
            float2 dvec = p - p_closest;

            
            float d2 = dot(dvec, dvec);
            if(d2 > tgR2[i]) continue;
            
            float inv_w = mix(tgInvW0[i], tgInvW1[i], tLine);
            float z_over_w = mix(tgZ_over_W0[i], tgZ_over_W1[i], tLine);
            
            float current_depth = z_over_w / inv_w;
            uint current_pathID = tgPathID[i];
            
            bool joined = false;
            for (uint j = 0; j < K_BUFFER_SIZE; ++j) {
                if(pathFragments[j].pathID == current_pathID
                   && abs(pathFragments[j].depth - current_depth) < Z_FIGHTING_EPSILON) {
                    pathFragments[j].min_dist_sq = min(pathFragments[j].min_dist_sq, d2);
                    joined = true;
                    break;
                }
            }
            
            if(!joined) {
                if (current_depth < pathFragments[K_BUFFER_SIZE - 1].depth) {
                    bool inserted = false;
                    // Shift fragments to make space
                    for (uint j = K_BUFFER_SIZE - 1; j > 0; --j) {
                        if (current_depth < pathFragments[j - 1].depth) {
                            pathFragments[j] = pathFragments[j - 1];
                        } else {
                            pathFragments[j] = {
                                current_depth,
                                current_pathID,
                                d2,
                                tLine,
                                tgColorStartCenter[i],
                                tgColorEndCenter[i],
                                tgP0[i],
                                tgP1[i],
                                tgHWStart[i],
                                tgHWEnd[i],
                                tgAA[i],
                                tgNoiseFloor[i]
                            };
                            inserted = true;
                            break;
                        }
                    }
                    if (!inserted) {
                        pathFragments[0] = {
                            current_depth,
                            current_pathID,
                            d2,
                            tLine,
                            tgColorStartCenter[i],
                            tgColorEndCenter[i],
                            tgP0[i],
                            tgP1[i],
                            tgHWStart[i],
                            tgHWEnd[i],
                            tgAA[i],
                            tgNoiseFloor[i]
                        };
                    }
                }
            }
        }
        
        threadgroup_barrier(mem_flags::mem_threadgroup);
        processed += batch;
    }
    
    // TODO: KEEP GLITCH ART FUNCTIONALITIES BY RANDOMLY CONFIGURING COLOR FROM E.G. FIRST SEGMENT IN THE THREAD GROUP

    
    
    if (((bin & 1u) == 0u)) final_rgb += U.debugBins * float3(0.1);
    final_rgb += float3(float(total) / 10.0) * U.binVisibility;

    // PASS 2A: Group fragments by pathID and blend within each path
    float4 pathColors[K_BUFFER_SIZE];
    uint uniquePathCount = 0;
    uint processedPaths[K_BUFFER_SIZE];

    // Initialize path tracking
    for (uint i = 0; i < K_BUFFER_SIZE; ++i) {
        pathColors[i] = float4(0.0, 0.0, 0.0, 0.0);
        processedPaths[i] = UINT_MAX;
    }

    // Process each fragment and group by pathID
    for (int i = K_BUFFER_SIZE - 1; i >= 0; --i) {
        if (pathFragments[i].depth >= FLT_MAX) continue;
        
        PathFragment pf = pathFragments[i];
        
        // Calculate this fragment's color and alpha
        float tLine = pf.t_param;
        float4 fragmentColor = mix(pf.colorStart, pf.colorEnd, tLine);
        
        float dist = sqrt(pf.min_dist_sq);
        
        float hwAtT = mix(pf.hwStart, pf.hwEnd, tLine);
        
        float r = dist / (hwAtT + pf.aa + 1e-6f);
        r = clamp(r, 0.0, 1.0);
        
        // float alpha = smoothstep(pf.hw + pf.aa, pf.hw - pf.aa, dist);
        float alpha = smoothstep(hwAtT + pf.aa, hwAtT - pf.aa, dist);
        fragmentColor.a *= alpha;
        
        // Apply debug gradient if enabled
        float4 debug_gradient = mix(float4(U.lineDebugGradientStartColor, 1.0),
                                   float4(U.lineDebugGradientEndColor, 1.0),
                                   tLine) * U.lineDebugGradientStrength;
        fragmentColor.rgb = fragmentColor.rgb * U.lineColorStrength + debug_gradient.rgb;
        
        // Find or create path entry
        int pathIndex = -1;
        for (uint j = 0; j < uniquePathCount; ++j) {
            if (processedPaths[j] == pf.pathID) {
                pathIndex = int(j);
                break;
            }
        }
        
        if (pathIndex == -1 && uniquePathCount < K_BUFFER_SIZE) {
            pathIndex = int(uniquePathCount);
            processedPaths[uniquePathCount] = pf.pathID;
            uniquePathCount++;
        }
        
        if (pathIndex >= 0) {
            // Blend this fragment with existing path color using "over" blending
//            float4 existing = pathColors[pathIndex];
//            pathColors[pathIndex] = float4(
//                mix(existing.rgb, fragmentColor.rgb, fragmentColor.a),
//                existing.a + fragmentColor.a * (1.0 - existing.a)
//            );
            // FIX: switch to premultiplied-alpha compositing within a path
            float4 existing = pathColors[pathIndex];

            // Convert fragment to premultiplied RGB
            uint hashedIndex = hash3(gid.x, gid.y, pxIndex);
            uint moduloHashedIndex = hashedIndex % 1000u;
            float randomBoolValue = clamp(round(pf.noiseFloor + randomValues[moduloHashedIndex % 1000].x
                                          * (0.5 +
                                             (1.0 - pow(smoothstep(0.0, 1.0, r), 1.0))
                                             * 0.5)), 0.0, 1.0);

            float  a_frag   = fragmentColor.a * randomBoolValue;
            float3 rgb_prem = fragmentColor.rgb * a_frag;

            // Premultiplied "over":
            // C = Cs + Cd*(1 - As)
            // A = As + Ad*(1 - As)
            float3 out_rgb = existing.rgb + rgb_prem * (1.0 - existing.a);
            float  out_a   = existing.a   + a_frag   * (1.0 - existing.a);

            pathColors[pathIndex] = float4(out_rgb, out_a);
            // END FIX
        }
    }

    // PASS 2B: Additively blend the path colors
    for (uint i = 0; i < uniquePathCount; ++i) {
        float4 pathColor = pathColors[i];
        if (pathColor.a > 0.0) {
            // Additive blending between paths
            // final_rgb = min(final_rgb + pathColor.rgb * pathColor.a, float3(1.0));
            // final_rgb = mix(final_rgb, pathColor.rgb, pathColor.a);
            
            // FIX: paths are stored premultiplied; unpremultiply before straight-alpha mix
            float3 src_straight = (pathColor.a > 1e-6f) ? (pathColor.rgb / pathColor.a) : pathColor.rgb;
            final_rgb = mix(final_rgb, src_straight, pathColor.a);
            // END FIX

        }
    }
    
    // Use half precision for output (optimization)
    outTex.write(half4(half3(final_rgb), 1.0h), gid);
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
