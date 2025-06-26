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
        
        
        // Initial conditions
        var x: Float = 1.0
        var y: Float = 1.0
        var z: Float = 1.0
        
        // Generate points and connect with lines
        for i in 0..<steps {
            let currentPoint = SIMD3<Float>(x: x * scale, y: y * scale, z: z * scale)
            
            let dx = sigma * (y - x)
            let dy = x * (rho - z) - y
            let dz = x * y - beta * z
            
            x += dx * dt
            y += dy * dt
            z += dz * dt
            
            let nextPoint = SIMD3<Float>(x: x * scale, y: y * scale, z: z * scale)
            
            lines.append(Line(
                startPoint: currentPoint,
                endPoint: nextPoint
            ))
        }
        
        if rotationX != 0 {
            let rotationMatrix = matrix_rotation(angle: rotationX, axis: SIMD3<Float>(x: 1, y: 0, z: 0))
            for i in 0..<lines.count {
                lines[i] = lines[i].applyMatrix(rotationMatrix)
            }
        }

        if rotationY != 0 {
            let rotationMatrix = matrix_rotation(angle: rotationY, axis: SIMD3<Float>(x: 0, y: 1, z: 0))
            for i in 0..<lines.count {
                lines[i] = lines[i].applyMatrix(rotationMatrix)
            }
        }

        if rotationZ != 0 {
            let rotationMatrix = matrix_rotation(angle: rotationZ, axis: SIMD3<Float>(x: 0, y: 0, z: 1))
            for i in 0..<lines.count {
                lines[i] = lines[i].applyMatrix(rotationMatrix)
            }
        }
        
        return lines
    }
}
