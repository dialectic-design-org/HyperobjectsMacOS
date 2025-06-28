//
//  LorenzGenerator.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 21/06/2025.
//

import Foundation
import simd

class LorenzGenerator: CachedGeometryGenerator {
    init() {
        super.init(name: "Lorenz Generator", inputDependencies: [
            "Sigma",
            "Rho",
            "Beta",
            "Steps",
            "DT",
            "Scale"
        ])
    }
    
    
    
    override func generateGeometriesFromInputs(inputs: [String : Any]) -> [any Geometry] {
        var lines: [Line] = []
        
        // Extract parameters with defaults
        let sigma = floatFromInputs(inputs, name: "Sigma")
        let rho = floatFromInputs(inputs, name: "Rho")
        let beta = floatFromInputs(inputs, name: "Beta")
        let steps = intFromInputs(inputs, name: "Steps")
        let dt = floatFromInputs(inputs, name: "DT")
        let scale = floatFromInputs(inputs, name: "Scale")
        
        let rotationX = floatFromInputs(inputs, name: "Rotation X")
        let rotationY = floatFromInputs(inputs, name: "Rotation Y")
        let rotationZ = floatFromInputs(inputs, name: "Rotation Z")
        
        let translationX = floatFromInputs(inputs, name: "Translation X")
        let translationY = floatFromInputs(inputs, name: "Translation Y")
        let translationZ = floatFromInputs(inputs, name: "Translation Z")
        
        let statefulRotationX = floatFromInputs(inputs, name: "Stateful Rotation X")
        let statefulRotationY = floatFromInputs(inputs, name: "Stateful Rotation Y")
        let statefulRotationZ = floatFromInputs(inputs, name: "Stateful Rotation Z")
        
        
        // Initial conditions
        var x: Float = 1.0
        var y: Float = 1.0
        var z: Float = 1.0
        
        // Generate points and connect with lines
        for i in 0..<steps {
            let currentPoint = SIMD3<Float>(x: x, y: y, z: z)
            
            let dx = sigma * (y - x)
            let dy = x * (rho - z) - y
            let dz = x * y - beta * z
            
            x += dx * dt
            y += dy * dt
            z += dz * dt
            
            let nextPoint = SIMD3<Float>(x: x, y: y, z: z)
            
            lines.append(Line(
                startPoint: currentPoint,
                endPoint: nextPoint
            ))
        }
        let translationMatrixBefore = matrix_translation(translation: SIMD3<Float>(x: translationX, y: translationY, z: translationZ))
        for i in 0..<lines.count {
            lines[i] = lines[i].applyMatrix(translationMatrixBefore)
        }
        
        let rotationMatrixX = matrix_rotation(angle: rotationX + statefulRotationX, axis: SIMD3<Float>(x: 1, y: 0, z: 0))
        for i in 0..<lines.count {
            lines[i] = lines[i].applyMatrix(rotationMatrixX)
        }

        let rotationMatrixY = matrix_rotation(angle: rotationY + statefulRotationY, axis: SIMD3<Float>(x: 0, y: 1, z: 0))
        for i in 0..<lines.count {
            lines[i] = lines[i].applyMatrix(rotationMatrixY)
        }

        let rotationMatrixZ = matrix_rotation(angle: rotationZ + statefulRotationZ, axis: SIMD3<Float>(x: 0, y: 0, z: 1))
        for i in 0..<lines.count {
            lines[i] = lines[i].applyMatrix(rotationMatrixZ)
        }
        
        let translationMatrixAfter = matrix_translation(translation: SIMD3<Float>(x: -translationX, y: -translationY, z: -translationZ))
        for i in 0..<lines.count {
            lines[i] = lines[i].applyMatrix(translationMatrixAfter)
        }
        
        let scaleMatrix = matrix_float4x4(
            SIMD4<Float>(scale, 0, 0, 0),
            SIMD4<Float>(0, scale, 0, 0),
            SIMD4<Float>(0, 0, scale, 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
        for i in 0..<lines.count {
            lines[i] = lines[i].applyMatrix(scaleMatrix)
        }
        
        return lines
    }
}
