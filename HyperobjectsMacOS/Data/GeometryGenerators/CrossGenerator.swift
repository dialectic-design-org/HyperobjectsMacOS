//
//  CrossGenerator.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 28/10/2024.
//

import Foundation
import simd

class CrossGenerator: CachedGeometryGenerator {
    init() {
        super.init(name: "Cross Generator", inputDependencies: ["Size", "Rotation"])
    }
    
    override func generateGeometriesFromInputs(inputs: [String : Any]) -> [any Geometry] {
        var lines: [Line] = []
        
        lines.append(
            Line(
                startPoint: SIMD3<Float>(x: -20.0, y: -20.0, z: 0.0),
                endPoint: SIMD3<Float>(x: 20.0, y: 20.0, z: 0.0)
            )
        )
        
        lines.append(
            Line(
                startPoint: SIMD3<Float>(x: -20.0, y: 20.0, z: 0.0),
                endPoint: SIMD3<Float>(x: 20.0, y: -20.0, z: 0.0)
            )
        )
        
        return lines
    }
}
