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
        
        return lines
    }
}
