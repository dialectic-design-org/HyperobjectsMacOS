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

struct ChromaticAberrationParams {
    float intensity;          // 0.0-1.0, blend with original
    float redOffset;          // Pixels, typically negative (-3.0) [RGB mode only]
    float greenOffset;        // Pixels, typically 0.0 [RGB mode only]
    float blueOffset;         // Pixels, typically positive (3.0) [RGB mode only]
    float radialPower;        // Falloff exponent (1.0=linear, 2.0=quadratic)
    int useRadialMode;        // 1=radial from center, 0=uniform direction
    vector_float2 direction;  // Direction for uniform mode (normalized)
    int useSpectralMode;      // 1=physically-based spectral, 0=RGB split
    float dispersionStrength; // Pixels at 400nm wavelength [spectral mode]
    float referenceWavelength;// Reference wavelength (no shift), typically 550nm
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
