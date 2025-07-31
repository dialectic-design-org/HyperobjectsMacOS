//
//  BezierPathsSphereGenerator.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 30/07/2025.
//


import Foundation
import simd

class BezierPathsSphereGenerator: CachedGeometryGenerator {
    init() {
        super.init(
            name: "Bezier Paths Sphere Generator",
            inputDependencies: [
                "Segments",
                "Circles"
            ]
        )
    }
    
    override func generateGeometriesFromInputs(inputs: [String : Any]) -> [any Geometry] {
        var lines: [Line] = []
        
        
        for i in 0...9 {
            var circle = generateCircleSegments(nSegments: 16)
            let rotationMatrixA = matrix_rotation(angle: Float(i) / 4.0, axis: SIMD3<Float>(0.0, 0.0, 1.0))
            let rotationMatrixB = matrix_rotation(angle: Float(i) / 8.0, axis: SIMD3<Float>(0.0, 1.0, 0.0))
            let rotationMatrixFull = rotationMatrixA * rotationMatrixB
            for j in 0..<circle.count {
                circle[j] = circle[j].applyMatrix(rotationMatrixFull)
            }
            lines += circle
        }
                
        let scalingFactor: Float = 2.0
        let matrixScale = matrix_scale(scale: SIMD3<Float>(repeating: scalingFactor))
        for i in 0..<lines.count {
            lines[i] = lines[i].applyMatrix(matrixScale)
        }
        
        return lines
    }
}
