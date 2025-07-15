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

struct Shader_Line {
    vector_float3 p0_world;
    vector_float3 p1_world;
    vector_float2 p0_screen;
    vector_float2 p1_screen;
    
    float halfWidth0;
    float halfWidth1;
    
    float antiAlias;
    float depth;
    
    float _pad0;
    vector_float4 colorPremul0;
    vector_float4 colorPremul1;
};


struct TransformUniforms {
    int viewWidth;
    int viewHeight;
};

#endif /* definitions_h */
