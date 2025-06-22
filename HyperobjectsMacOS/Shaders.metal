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
    float pointsize [[point_size]];
};

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
