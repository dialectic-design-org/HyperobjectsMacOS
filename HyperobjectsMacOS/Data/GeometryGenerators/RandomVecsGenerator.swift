//
//  RandomVecsGenerator.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 08/10/2025.
//

import Foundation
import simd

class RandomVecsGenerator: CachedGeometryGenerator {
    init() {
        super.init(
            name: "Random Vecs Generator",
            inputDependencies: [
                "Radius",
            ]
        )
    }
    
    override func generateGeometriesFromInputs(inputs: [String : Any], withScene: GeometriesSceneBase) -> [any Geometry] {
        var lines: [Line] = []
        
        lines.append(
            Line(
                startPoint: SIMD3<Float>(0.0, -1.0, 0.0),
                endPoint: SIMD3<Float>(0.0, 1.0, 0.0)
            )
        )
        
        
        return lines
    }
}
