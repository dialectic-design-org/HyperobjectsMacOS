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
    
    float lineColorStrength;
    float lineDebugGradientStrength;
    
    vector_float3 lineDebugGradientStartColor;
    vector_float3 lineDebugGradientEndColor;
    
    float blendRadius;
    float blendIntensity;
    float previousColorVisibility;
};


struct LinearSeg3D {
    int pathID;
    vector_float4 p0_world;
    vector_float4 p1_world;
    float halfWidthStartPx;
    float halfWidthEndPx;
    float aaPx;
    float noiseFloor;
    
    vector_float4 colorStartLeft;
    vector_float4 colorStartCenter;
    vector_float4 colorStartRight;
    
    vector_float2 transStartLeft;
    vector_float2 transStartRight;
    
    
    vector_float4 colorEndLeft;
    vector_float4 colorEndCenter;
    vector_float4 colorEndRight;
    
    vector_float2 transEndLeft;
    vector_float2 transEndRight;
    
};

struct QuadraticSeg3D {
    int pathID;
    vector_float4 p0_world;
    vector_float4 p1_world;
    vector_float4 p2_world;
    float halfWidthStartPx;
    float halfWidthEndPx;
    float aaPx;
    float noiseFloor;
    
    vector_float4 colorStartCenter;
    vector_float4 colorEndCenter;
};

struct CubicSeg3D {
    int pathID;
    vector_float4 p0_world;
    vector_float4 p1_world;
    vector_float4 p2_world;
    vector_float4 p3_world;
    float halfWidthStartPx;
    float halfWidthEndPx;
    float aaPx;
    float noiseFloor;
    
    vector_float4 colorStartCenter;
    vector_float4 colorEndCenter;
};

struct LinearSegScreenSpace {
    vector_float2 p0_ss;
    vector_float2 p1_ss;
    float halfWidthStartPx;
    float halfWidthEndPx;
    float aaPx;
    float noiseFloor;
    
    vector_float2 bboxMinSS;
    vector_float2 bboxMaxSS;
    
    vector_float4 colorStartCenter;
    vector_float4 colorEndCenter;
    
    float z0_clip;
    float w0_clip;
    float z1_clip;
    float w1_clip;
    
    int pathID;
    short segIndex;
    short totalSegs;
};


#endif /* definitions_h */
