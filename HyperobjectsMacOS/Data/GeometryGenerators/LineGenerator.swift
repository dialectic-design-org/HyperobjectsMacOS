//
//  LineGenerator.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 19/07/2025.
//

import Foundation
import simd

class LineGenerator: CachedGeometryGenerator {
    init() {
        super.init(name: "Line Generator",
                   inputDependencies: [
                    "Length",
                    "Rotation",
                    "Start line width",
                    "End line width",
                    
                    "Start color inner",
                    "Start color outer left",
                    "Start color outer right",
                    
                    "End color inner",
                    "End color outer left",
                    "End color outer right",
                   ])
    }
    
    override func generateGeometriesFromInputs(inputs: [String : Any]) -> [any Geometry] {
        var lines: [Line] = []
        
        var length = floatFromInputs(inputs, name: "Length")
        var rotation = floatFromInputs(inputs, name: "Rotation")
        
        var startLineWidth = floatFromInputs(inputs, name: "Start line width")
        var endLineWidth = floatFromInputs(inputs, name: "End line width")
        
        var startColorInner = colorFromInputs(inputs, name: "Start color inner")
        var startColorOuterLeft = colorFromInputs(inputs, name: "Start color outer left")
        var startColorOuterRight = colorFromInputs(inputs, name: "Start color outer right")
        
        var endColorInner = colorFromInputs(inputs, name: "End color inner")
        var endColorOuterLeft = colorFromInputs(inputs, name: "End color outer left")
        var endColorOuterRight = colorFromInputs(inputs, name: "End color outer right")
        
        var startSigmoidSteepness = floatFromInputs(inputs, name: "Start sigmoid steepness")
        var startSigmoidMidpoint = floatFromInputs(inputs, name: "Start sigmoid midpoint")
        
        var endSigmoidSteepness = floatFromInputs(inputs, name: "End sigmoid steepness")
        var endSigmoidMidpoint = floatFromInputs(inputs, name: "End sigmoid midpoint")
        
        lines.append(Line(
            startPoint: SIMD3<Float>(-length / 2.0, 0, 0),
            endPoint: SIMD3<Float>(length / 2.0, 0.0, 0.0),
            colorStart: startColorInner.toSIMD4(),
            colorStartOuterLeft: startColorOuterLeft.toSIMD4(),
            colorStartOuterRight: startColorOuterRight.toSIMD4(),
            colorEnd: endColorInner.toSIMD4(),
            colorEndOuterLeft: endColorOuterLeft.toSIMD4(),
            colorEndOuterRight: endColorOuterRight.toSIMD4(),
            sigmoidSteepness0: startSigmoidSteepness,
            sigmoidMidpoint0: startSigmoidMidpoint,
            sigmoidSteepness1: endSigmoidSteepness,
            sigmoidMidpoint1: endSigmoidMidpoint,
            
            lineWidthStart: startLineWidth,
            lineWidthEnd: endLineWidth,
        ))
        
        let rotationMatrix = matrix_rotation(angle: rotation, axis: SIMD3<Float>(x: 0, y: 0, z: 1))
        
        for i in 0..<lines.count {
            lines[i] = lines[i].applyMatrix(rotationMatrix)
        }
        
        return lines
    }
}
