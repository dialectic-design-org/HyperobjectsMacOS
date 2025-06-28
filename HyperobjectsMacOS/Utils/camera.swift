//
//  camera.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 02/01/2025.
//

import simd


func matrix_rotation(angle: Float, axis: SIMD3<Float>) -> matrix_float4x4 {
    let s = sin(angle)
    let c = cos(angle)
    let t = 1.0 - c
    let x = axis.x
    let y = axis.y
    let z = axis.z

    return matrix_float4x4(
        SIMD4<Float>(t*x*x + c,     t*x*y - s*z,   t*x*z + s*y,   0),
        SIMD4<Float>(t*x*y + s*z,   t*y*y + c,     t*y*z - s*x,   0),
        SIMD4<Float>(t*x*z - s*y,   t*y*z + s*x,   t*z*z + c,     0),
        SIMD4<Float>(0,             0,             0,             1)
    )
}

func matrix_translation(translation: SIMD3<Float>) -> matrix_float4x4 {
    return matrix_float4x4(
        SIMD4<Float>(1, 0, 0, 0),
        SIMD4<Float>(0, 1, 0, 0),
        SIMD4<Float>(0, 0, 1, 0),
        SIMD4<Float>(translation.x, translation.y, translation.z, 1)
    )
}


func matrix_lookAt(eye: SIMD3<Float>, target: SIMD3<Float>, up: SIMD3<Float>) -> matrix_float4x4 {
    let zAxis = normalize(target - eye)
    let xAxis = normalize(cross(up, zAxis))
    let yAxis = cross(zAxis, xAxis)
    
    let translation = SIMD4<Float>(-dot(xAxis, eye), -dot(yAxis, eye), -dot(zAxis, eye), 1.0)
    return matrix_float4x4(
        SIMD4<Float>(xAxis, 0),
        SIMD4<Float>(yAxis, 0),
        SIMD4<Float>(zAxis, 0),
        translation
    )
}

func matrix_perspective(fovY: Float, aspect: Float, nearZ: Float, farZ: Float) -> matrix_float4x4 {
    let yScale = 1.0 / tan(fovY * 0.5)
    let xScale = yScale / aspect
    let zRange = farZ - nearZ
    let zScale = -(farZ + nearZ) / zRange
    let wzScale = -2.0 * farZ * nearZ / zRange

    return matrix_float4x4(
        SIMD4<Float>(xScale, 0, 0, 0),
        SIMD4<Float>(0, yScale, 0, 0),
        SIMD4<Float>(0, 0, zScale, -1),
        SIMD4<Float>(0, 0, wzScale, 0)
    )
}
