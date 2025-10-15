//
//  LineGenerator.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 19/07/2025.
//

import Foundation
import simd
import SwiftUI

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
    
    override func generateGeometriesFromInputs(inputs: [String : Any], withScene: GeometriesSceneBase) -> [any Geometry] {
        var lines: [Line] = []
        
        let length = floatFromInputs(inputs, name: "Length")
        let rotation = floatFromInputs(inputs, name: "Rotation")
        
        let startLineWidth = floatFromInputs(inputs, name: "Start line width")
        let endLineWidth = floatFromInputs(inputs, name: "End line width")
        
        let startColorInner = colorFromInputs(inputs, name: "Start color inner")
        let startColorOuterLeft = colorFromInputs(inputs, name: "Start color outer left")
        let startColorOuterRight = colorFromInputs(inputs, name: "Start color outer right")
        
        let endColorInner = colorFromInputs(inputs, name: "End color inner")
        let endColorOuterLeft = colorFromInputs(inputs, name: "End color outer left")
        let endColorOuterRight = colorFromInputs(inputs, name: "End color outer right")
        
        let startSigmoidSteepness = floatFromInputs(inputs, name: "Start sigmoid steepness")
        let startSigmoidMidpoint = floatFromInputs(inputs, name: "Start sigmoid midpoint")
        
        let endSigmoidSteepness = floatFromInputs(inputs, name: "End sigmoid steepness")
        let endSigmoidMidpoint = floatFromInputs(inputs, name: "End sigmoid midpoint")
        
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
        
        return lines
    }
}
