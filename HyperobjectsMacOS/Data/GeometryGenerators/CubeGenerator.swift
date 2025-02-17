//
//  CubeGenerator.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 06/11/2024.
//

import Foundation
import simd

class CubeGenerator: CachedGeometryGenerator {
    init() {
        super.init(name: "Cube Generator", inputDependencies: ["Size", "Rotation"])
    }
    
    override func generateGeometriesFromInputs(inputs: [String : Any]) -> [any Geometry] {
        var lines: [Line] = []
        
        // Front
        lines.append(
            Line(
                startPoint: SIMD3<Float>(x: -25.0, y: -25.0, z: -25.0),
                endPoint: SIMD3<Float>(x: 25.0, y: -25.0, z: -25.0)
            )
        )
        lines.append(
            Line(
                startPoint: SIMD3<Float>(x: 25.0, y: -25.0, z: -25.0),
                endPoint: SIMD3<Float>(x: 25.0, y: 25.0, z: -25.0)
            )
        )
        lines.append(
            Line(
                startPoint: SIMD3<Float>(x: 25.0, y: 25.0, z: -25.0),
                endPoint: SIMD3<Float>(x: -25.0, y: 25.0, z: -25.0)
            )
        )
        lines.append(
            Line(
                startPoint: SIMD3<Float>(x: -25.0, y: 25.0, z: -25.0),
                endPoint: SIMD3<Float>(x: -25.0, y: -25.0, z: -25.0)
            )
        )
        
        
        // Back
        lines.append(
            Line(
                startPoint: SIMD3<Float>(x: -25.0, y: -25.0, z: 25.0),
                endPoint: SIMD3<Float>(x: 25.0, y: -25.0, z: 25.0)
            )
        )
        lines.append(
            Line(
                startPoint: SIMD3<Float>(x: 25.0, y: -25.0, z: 25.0),
                endPoint: SIMD3<Float>(x: 25.0, y: 25.0, z: 25.0)
            )
        )
        lines.append(
            Line(
                startPoint: SIMD3<Float>(x: 25.0, y: 25.0, z: 25.0),
                endPoint: SIMD3<Float>(x: -25.0, y: 25.0, z: 25.0)
            )
        )
        lines.append(
            Line(
                startPoint: SIMD3<Float>(x: -25.0, y: 25.0, z: 25.0),
                endPoint: SIMD3<Float>(x: -25.0, y: -25.0, z: 25.0)
            )
        )
        
        
        // Connecting Lines
        lines.append(
            Line(
                startPoint: SIMD3<Float>(x: -25.0, y: -25.0, z: -25.0),
                endPoint: SIMD3<Float>(x: -25.0, y: -25.0, z: 25.0)
            )
        )
        lines.append(
            Line(
                startPoint: SIMD3<Float>(x: 25.0, y: -25.0, z: -25.0),
                endPoint: SIMD3<Float>(x: 25.0, y: -25.0, z: 25.0)
            )
        )
        lines.append(
            Line(
                startPoint: SIMD3<Float>(x: 25.0, y: 25.0, z: -25.0),
                endPoint: SIMD3<Float>(x: 25.0, y: 25.0, z: 25.0)
            )
        )
        lines.append(
            Line(
                startPoint: SIMD3<Float>(x: -25.0, y: 25.0, z: -25.0),
                endPoint: SIMD3<Float>(x: -25.0, y: 25.0, z: 25.0)
            )
        )
        
        return lines
    }
}
