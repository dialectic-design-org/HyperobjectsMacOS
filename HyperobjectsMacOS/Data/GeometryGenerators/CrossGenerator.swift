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
        
        let size = floatFromInputs(inputs, name: "Size")
        let rotation = floatFromInputs(inputs, name: "Rotation")
        
        let rotationMatrix = matrix_rotation(angle: rotation, axis: SIMD3<Float>(x: 0, y: 0, z: 1))
        
        var lineOne = Line(
            startPoint: SIMD3<Float>(x: -1.0, y: -1.0, z: 0.0) * size,
            endPoint: SIMD3<Float>(x: 1.0, y: 1.0, z: 0.0) * size
        )
        
        var lineTwo = Line(
            startPoint: SIMD3<Float>(x: -1.0, y: 1.0, z: 0.0) * size,
            endPoint: SIMD3<Float>(x: 1.0, y: -1.0, z: 0.0) * size
        )
        
        lineOne = lineOne.applyMatrix(rotationMatrix)
        lineTwo = lineTwo.applyMatrix(rotationMatrix)
        
        lines.append(lineOne)
        lines.append(lineTwo)
        
        return lines
    }
}
