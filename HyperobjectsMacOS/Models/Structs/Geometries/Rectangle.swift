//
//  Rectangle.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 07/01/2026.
//

import simd

struct RectangleCustom {
    var position: SIMD3<Float>
    var size: SIMD2<Float>
    var orientation: SIMD3<Float>
    
    func toLines() -> [Line] {
        let halfWidth = size.x / 2
        let halfHeight = size.y / 2
        
        let localCorners = [
            SIMD3<Float>(-halfWidth, -halfHeight, 0),
            SIMD3<Float>( halfWidth, -halfHeight, 0),
            SIMD3<Float>( halfWidth,  halfHeight, 0),
            SIMD3<Float>(-halfWidth,  halfHeight, 0)
        ]
        
        let rotationMatrixX = matrix_rotation(angle: orientation.x, axis: SIMD3<Float>(1, 0, 0))
        let rotationMatrixY = matrix_rotation(angle: orientation.y, axis: SIMD3<Float>(0, 1, 0))
        let rotationMatrixZ = matrix_rotation(angle: orientation.z, axis: SIMD3<Float>(0, 0, 1))
        let rotationMatrix = rotationMatrixZ * rotationMatrixY * rotationMatrixX
        
        let worldCorners = localCorners.map { corner in
            let rotated = rotationMatrix * SIMD4<Float>(corner, 1)
            return SIMD3<Float>(rotated.x, rotated.y, rotated.z) + position
        }
        
        return [
            Line(startPoint: worldCorners[0], endPoint: worldCorners[1]),
            Line(startPoint: worldCorners[1], endPoint: worldCorners[2]),
            Line(startPoint: worldCorners[2], endPoint: worldCorners[3]),
            Line(startPoint: worldCorners[3], endPoint: worldCorners[0])
        ]
    }
}
