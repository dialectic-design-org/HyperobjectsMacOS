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


struct Shader_Triangle {
    vector_float3 normals[3];
    vector_float3 colors[3];
};

struct Shader_Sphere {
    
};

struct Shader_PathSeg {
    vector_float4 p_world[4];
    
    vector_float2 p_screen[4];
    short degree;
    
    float halfWidth0;
    float halfWidth1;
    
    float antiAlias;
    
    float _pad0;
    vector_float4 colorPremul0;
    vector_float4 colorPremul0OuterLeft;
    vector_float4 colorPremul0OuterRight;
    
    vector_float4 colorPremul1;
    vector_float4 colorPremul1OuterLeft;
    vector_float4 colorPremul1OuterRight;
    
    float sigmoidSteepness0;
    float sigmoidMidpoint0;
    
    float sigmoidSteepness1;
    float sigmoidMidpoint1;
    
    // Dash detail
    float dashPatternPx[MAX_DASH_SEGMENTS];
    int dashCount;
    float dashTotalPx;
    float dashPhasePx;
    int _padDash;
    
    // Derived screen-space (set by transform and bin kernel)
    float p_depth[4];
    float p_inv_w[4];
    float p_depth_over_w[4];
    
    float  sLUT[ARC_LUT_SAMPLES]; // cumulative length; sLUT[0]=0, sLUT[N-1]=segLengthPx
    float  segLengthPx;           // convenience alias of sLUT[N-1]
    
    vector_float2 posLUT[ARC_LUT_SAMPLES];
    vector_float2 tanLUT[ARC_LUT_SAMPLES];
    
    short lutCount;
    
    vector_float2 bboxMinSS;
    vector_float2 bboxMaxSS;
};


struct TransformUniforms {
    int viewWidth;
    int viewHeight;
    vector_float3 cameraPosition;
    vector_float3 backgroundColor;
    
    float binVisibility;
    float binGridVisibility;
    int binDepth;
};

#endif /* definitions_h */
