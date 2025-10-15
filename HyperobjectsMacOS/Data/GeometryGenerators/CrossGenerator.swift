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
        super.init(name: "Cross Generator",
                   inputDependencies: [
                    "Size",
                    "Rotation",
                    "Line spacing",
                    "Line width",
                    "Rotation Y"
                   ])
    }
    
    override func generateGeometriesFromInputs(inputs: [String : Any], withScene scene: GeometriesSceneBase?) -> [any Geometry] {
        var lines: [Line] = []
        
        let size = floatFromInputs(inputs, name: "Size")
        let rotation = floatFromInputs(inputs, name: "Rotation")
        let lineSpacing = floatFromInputs(inputs, name: "Line spacing")
        let lineWidth = floatFromInputs(inputs, name: "Line width")
        let rotationY = floatFromInputs(inputs, name: "Rotation Y")
        let colorA = colorFromInputs(inputs, name: "Color A")
        let colorB = colorFromInputs(inputs, name: "Color B")
        let lineAlphaMultiplier = floatFromInputs(inputs, name: "Line alpha multiplier")
        
        let rotationMatrix = matrix_rotation(angle: rotation, axis: SIMD3<Float>(x: 0, y: 0, z: 1))
        let rotationMatrixY = matrix_rotation(angle: rotationY, axis: SIMD3<Float>(x: 0, y: 1, z: 0))
        
        var lineOne = Line(
            startPoint: SIMD3<Float>(x: -1.0, y: -1.0, z: lineSpacing) * size,
            endPoint: SIMD3<Float>(x: 1.0, y: 1.0, z: lineSpacing) * size,
            lineWidthStart: lineWidth,
            lineWidthEnd: lineWidth
        )
        
        lineOne = lineOne.setBasicEndPointColors(startColor: colorA.toSIMD4(), endColor: colorA.toSIMD4())
        
        var lineTwo = Line(
            startPoint: SIMD3<Float>(x: -1.0, y: 1.0, z: -lineSpacing) * size,
            endPoint: SIMD3<Float>(x: 1.0, y: -1.0, z: -lineSpacing) * size,
            lineWidthStart: lineWidth,
            lineWidthEnd: lineWidth
        )
        lineTwo = lineTwo.setBasicEndPointColors(startColor: colorB.toSIMD4(), endColor: colorB.toSIMD4())
        
        lines.append(lineOne)
        lines.append(lineTwo)
        
        var transforms = rotationMatrix * rotationMatrixY
        
        for i in 0..<lines.count {
            lines[i] = lines[i].applyMatrix(transforms)
        }
        
        return lines
    }
}
