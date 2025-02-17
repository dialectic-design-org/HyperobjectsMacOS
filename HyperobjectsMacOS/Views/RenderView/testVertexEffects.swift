//
//  testVertexEffects.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 05/02/2025.
//


func translateWaveEffect(vec: SIMD3<Float>, index: Int, drawCounter: Int) -> SIMD3<Float> {
    var newVec = vec
    let phase = Float(index) * 0.1
    let time = Float(drawCounter) * 0.01
    let height = sin(phase + time)
    newVec.y += height
    newVec.z += height
    return newVec
}

func rotationEffect(vec: SIMD3<Float>, drawCounter: Int, rotationSpeed: Float, axis: Int) -> SIMD3<Float> {
    // Create rotation matrix based on drawCounter
    let angle = Float(drawCounter) * 0.01 * rotationSpeed
    // Create rotation matrix based on axis from scratch
    let rotationMatrix: matrix_float4x4
    switch axis {
    case 0:
        rotationMatrix = matrix_float4x4(columns: (
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, cos(angle), sin(angle), 0),
            SIMD4<Float>(0, -sin(angle), cos(angle), 0),
            SIMD4<Float>(0, 0, 0, 1)
        ))
    case 1:
        rotationMatrix = matrix_float4x4(columns: (
            SIMD4<Float>(cos(angle), 0, -sin(angle), 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(sin(angle), 0, cos(angle), 0),
            SIMD4<Float>(0, 0, 0, 1)
        ))
    case 2:
        rotationMatrix = matrix_float4x4(columns: (
            SIMD4<Float>(cos(angle), sin(angle), 0, 0),
            SIMD4<Float>(-sin(angle), cos(angle), 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(0, 0, 0, 1)
        ))
    default:
        rotationMatrix = matrix_float4x4(columns: (
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(0, 0, 0, 1)
        ))
    }
    var newVec = rotationMatrix * SIMD4<Float>(vec.x, vec.y, vec.z, 1)

    // Return SIMD3<Float> from SIMD4<Float>
    return SIMD3<Float>(newVec.x, newVec.y, newVec.z)
}
