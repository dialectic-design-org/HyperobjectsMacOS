//
//  definitions.h
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 05/02/2025.
//

#ifndef definitions_h
#define definitions_h

#include <simd/simd.h>

#define MAX_DASH_SEGMENTS 8
#define ARC_LUT_SAMPLES   32
#define DOT_PX2 36.0f


#define BIN_POW 7
#define BIN_SIZE (1 << BIN_POW)
#define lineCount 10000

#define KMAX_PER_BIN 16u  // clamp for safety

struct Shader_Triangle {
    vector_float3 normals[3];
    vector_float3 colors[3];
};


struct Uniforms {
    int viewWidth;
    int viewHeight;
    vector_float3 backgroundColor;
    float antiAliasPx;
    
    float debugBins;
    float binVisibility;
    float boundingBoxVisibility;
};


struct LinearSeg3D {
    vector_float4 p0_world;
    vector_float4 p1_world;
    float halfWidthPx;
    float aaPx;
};

struct QuadraticSeg3D {
    vector_float4 p0_world;
    vector_float4 p1_world;
    vector_float4 p2_world;
    float halfWidthPx;
    float aaPx;
};

struct CubicSeg3D {
    vector_float4 p0_world;
    vector_float4 p1_world;
    vector_float4 p2_world;
    vector_float4 p3_world;
    float halfWidthPx;
    float aaPx;
};

struct LinearSegScreenSpace {
    vector_float2 p0_ss;
    vector_float2 p1_ss;
    float halfWidthPx;
    float aaPx;
    
    vector_float2 bboxMinSS;
    vector_float2 bboxMaxSS;
    
    vector_float4 colorStart;
    vector_float4 colorEnd;
};


#endif /* definitions_h */
