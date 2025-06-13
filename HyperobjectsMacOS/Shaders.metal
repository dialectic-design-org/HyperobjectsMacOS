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
    out.position = float4(vertices[vertexID] * 0.1, 1.0);
    float4 in = out.position;
    float cosAngle = cos(uniforms.rotationAngle);
    float sinAngle = sin(uniforms.rotationAngle);
    float3 rotatedPosition = float3(
        in.x * cosAngle - in.y * sinAngle,
        in.x * sinAngle + in.y * cosAngle,
        in.z
                                    );
    out.position = float4(rotatedPosition, 1.0);
    
    out.pointsize = 10.0;
    
    return out;
}

// Fragment shader
fragment float4 fragment_main(const device float4* color [[ buffer(0) ]]) {
    
    Shader_Triangle test;
    return float4(0, 1, 1, 1);
    return *color;
}
