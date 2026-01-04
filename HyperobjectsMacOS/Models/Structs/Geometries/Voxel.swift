//
//  Voxel.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 04/01/2026.
//

import simd

struct Voxel {
    let center: SIMD3<Float>
    let size: Float

    func corners() -> [SIMD3<Float>] {
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

    func toCube() -> Cube {
        return Cube(center: center, size: size)
    }
}
