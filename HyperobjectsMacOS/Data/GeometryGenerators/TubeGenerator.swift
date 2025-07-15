//
//  TubeGenerator.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 08/07/2025.
//

import Foundation
import simd

class TubeGenerator: CachedGeometryGenerator {
    init() {
        super.init(name: "Tube Generator", inputDependencies: ["Radius", "Height", "Slices", "Stacks", "TopRadiusFactor", "BottomRadiusFactor"])
    }
    
    override func generateGeometriesFromInputs(inputs: [String : Any]) -> [any Geometry] {
        var lines: [Line] = []
        
        
        
        
        return lines
    }
}
