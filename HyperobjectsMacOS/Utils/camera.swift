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

func matrix_scale(scale: SIMD3<Float>) -> matrix_float4x4 {
    return matrix_float4x4(
        SIMD4<Float>(scale.x, 0, 0, 0),
        SIMD4<Float>(0, scale.y, 0, 0),
        SIMD4<Float>(0, 0, scale.z, 0),
        SIMD4<Float>(0, 0, 0, 1)
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

// MARK: - Matrix helpers (Metal / RH / z in [0,1])
func matrix_perspective_metal_rh(fovY: Float, aspect: Float, nearZ: Float, farZ: Float) -> simd_float4x4 {
    let f = 1 / tanf(fovY * 0.5)
    let nf = 1 / (nearZ - farZ) // note: RH, Metal/D3D z
    return simd_float4x4(
        SIMD4<Float>( f/aspect, 0,  0,                          0),
        SIMD4<Float>( 0,        f,  0,                          0),
        SIMD4<Float>( 0,        0,  farZ*nf,                   -1),
        SIMD4<Float>( 0,        0,  (nearZ*farZ)*nf,            0)
    )
}

func matrix_lookAt_rh(eye: SIMD3<Float>, target: SIMD3<Float>, up: SIMD3<Float>) -> simd_float4x4 {
    let f = simd_normalize(target - eye)              // forward (to -Z if looking down -Z)
    let s = simd_normalize(simd_cross(f, up))
    let u = simd_cross(s, f)
    let m = simd_float4x4(
        SIMD4<Float>( s.x,  u.x, -f.x, 0),
        SIMD4<Float>( s.y,  u.y, -f.y, 0),
        SIMD4<Float>( s.z,  u.z, -f.z, 0),
        SIMD4<Float>(-simd_dot(s, eye),
                     -simd_dot(u, eye),
                      simd_dot(f, eye), 1)
    )
    return m
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

func matrix_orthographic(left: Float, right: Float, bottom: Float, top: Float, nearZ: Float, farZ: Float) -> simd_float4x4 {
    let sx = 2.0 / (right - left)
    let sy = 2.0 / (top - bottom)
    let sz = -2.0 / (farZ - nearZ)
    
    let tx = -(right + left) / (right - left)
    let ty = -(top + bottom) / (top - bottom)
    let tz = -(farZ + nearZ) / (farZ - nearZ)
    
    return simd_float4x4(
        columns: (
            simd_float4(sx, 0, 0, 0),
            simd_float4(0, sy, 0, 0),
            simd_float4(0, 0, sz, 0),
            simd_float4(tx, ty, tz, 1)
        )
    )
}
