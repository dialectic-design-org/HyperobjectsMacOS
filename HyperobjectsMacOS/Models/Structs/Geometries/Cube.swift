//
//  Cube.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 04/01/2026.
//

import simd

struct Cube {
    var center: SIMD3<Float>
    var size: Float
    var orientation: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    var axisScale: SIMD3<Float> = SIMD3<Float>(1, 1, 1)
    
    func vertices() -> [SIMD3<Float>] {
        let halfSize = size / 2
        let localVertices = [
            SIMD3<Float>(-halfSize, -halfSize, -halfSize) * axisScale,
            SIMD3<Float>( halfSize, -halfSize, -halfSize) * axisScale,
            SIMD3<Float>( halfSize,  halfSize, -halfSize) * axisScale,
            SIMD3<Float>(-halfSize,  halfSize, -halfSize) * axisScale,
            SIMD3<Float>(-halfSize, -halfSize,  halfSize) * axisScale,
            SIMD3<Float>( halfSize, -halfSize,  halfSize) * axisScale,
            SIMD3<Float>( halfSize,  halfSize,  halfSize) * axisScale,
            SIMD3<Float>(-halfSize,  halfSize,  halfSize) * axisScale
        ]
        
        let rotationMatrixX = matrix_rotation(angle: orientation.x, axis: SIMD3<Float>(1, 0, 0))
        let rotationMatrixY = matrix_rotation(angle: orientation.y, axis: SIMD3<Float>(0, 1, 0))
        let rotationMatrixZ = matrix_rotation(angle: orientation.z, axis: SIMD3<Float>(0, 0, 1))
        let rotationMatrix = rotationMatrixZ * rotationMatrixY * rotationMatrixX
        
        return localVertices.map { vertex in
            let rotated = rotationMatrix * SIMD4<Float>(vertex, 1)
            return SIMD3<Float>(rotated.x, rotated.y, rotated.z) + center
        }
    }

    func volume() -> Float {
        return pow(size, 3) * axisScale.x * axisScale.y * axisScale.z
    }

    func surfaceArea() -> Float {
        let w = size * axisScale.x
        let h = size * axisScale.y
        let d = size * axisScale.z
        return 2 * (w * h + h * d + d * w)
    }

    func contains(point: SIMD3<Float>) -> Bool {
        let halfSize = size / 2
        
        let translatedPoint = point - center
        
        let rotationMatrixX = matrix_rotation(angle: orientation.x, axis: SIMD3<Float>(1, 0, 0))
        let rotationMatrixY = matrix_rotation(angle: orientation.y, axis: SIMD3<Float>(0, 1, 0))
        let rotationMatrixZ = matrix_rotation(angle: orientation.z, axis: SIMD3<Float>(0, 0, 1))
        let rotationMatrix = rotationMatrixZ * rotationMatrixY * rotationMatrixX
        
        let inverseRotation = rotationMatrix.inverse
        
        let localPoint4 = inverseRotation * SIMD4<Float>(translatedPoint, 1)
        let localPoint = SIMD3<Float>(localPoint4.x, localPoint4.y, localPoint4.z)
        
        return abs(localPoint.x) <= halfSize * axisScale.x &&
               abs(localPoint.y) <= halfSize * axisScale.y &&
               abs(localPoint.z) <= halfSize * axisScale.z
    }

    func wallOutlines() -> [Line] {
        let v = vertices()
        return [
            // Bottom face
            Line(startPoint: v[0], endPoint: v[1]),
            Line(startPoint: v[1], endPoint: v[2]),
            Line(startPoint: v[2], endPoint: v[3]),
            Line(startPoint: v[3], endPoint: v[0]),
            // Top face
            Line(startPoint: v[4], endPoint: v[5]),
            Line(startPoint: v[5], endPoint: v[6]),
            Line(startPoint: v[6], endPoint: v[7]),
            Line(startPoint: v[7], endPoint: v[4]),
            // Vertical edges
            Line(startPoint: v[0], endPoint: v[4]),
            Line(startPoint: v[1], endPoint: v[5]),
            Line(startPoint: v[2], endPoint: v[6]),
            Line(startPoint: v[3], endPoint: v[7])
        ]
    }
    
}
