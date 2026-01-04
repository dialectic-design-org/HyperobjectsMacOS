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
    
    func vertices() -> [SIMD3<Float>] {
        let halfSize = size / 2
        return [
            center + SIMD3<Float>(-halfSize, -halfSize, -halfSize),
            center + SIMD3<Float>( halfSize, -halfSize, -halfSize),
            center + SIMD3<Float>( halfSize,  halfSize, -halfSize),
            center + SIMD3<Float>(-halfSize,  halfSize, -halfSize),
            center + SIMD3<Float>(-halfSize, -halfSize,  halfSize),
            center + SIMD3<Float>( halfSize, -halfSize,  halfSize),
            center + SIMD3<Float>( halfSize,  halfSize,  halfSize),
            center + SIMD3<Float>(-halfSize,  halfSize,  halfSize)
        ]
    }

    func volume() -> Float {
        return pow(size, 3)
    }

    func surfaceArea() -> Float {
        return 6 * pow(size, 2)
    }

    func contains(point: SIMD3<Float>) -> Bool {
        let halfSize = size / 2
        return abs(point.x - center.x) <= halfSize &&
               abs(point.y - center.y) <= halfSize &&
               abs(point.z - center.z) <= halfSize
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
