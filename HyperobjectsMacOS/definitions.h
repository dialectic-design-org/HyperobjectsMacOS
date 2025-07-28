//
//  definitions.h
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 05/02/2025.
//

#ifndef definitions_h
#define definitions_h

#include <simd/simd.h>

struct Shader_Triangle {
    vector_float3 normals[3];
    vector_float3 colors[3];
};

struct Shader_Sphere {
    
};

struct Shader_PathSeg {
    vector_float3 p0_world;
    vector_float3 p1_world;
    vector_float4 p_world[4];
    
    vector_float2 p_screen[4];
    int degree;
    
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
    
    float p_depth[4];
    float p_inv_w[4];
    float p_depth_over_w[4];
};


struct TransformUniforms {
    int viewWidth;
    int viewHeight;
    vector_float3 cameraPosition;
    vector_float3 backgroundColor;
};

#endif /* definitions_h */
