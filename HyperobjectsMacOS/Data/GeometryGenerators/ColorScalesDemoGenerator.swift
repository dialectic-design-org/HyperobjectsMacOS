//
//  ColorScalesDemoGenerator.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 31/07/2025.
//

import Foundation
import simd
import SwiftUI

class ColorScalesDemoGenerator: CachedGeometryGenerator {
    var historyValues: FloatInterpolator = FloatInterpolator()
    init() {
        super.init(
            name: "Color Scales Demo Generator",
            inputDependencies: [
                "Color start",
                "Color end",
                "Brightness",
                "Saturation",
                "Rotation X",
                "Rotation Y",
                "Rotation Z",
                "Stateful Rotation X",
                "Stateful Rotation Y",
                "Stateful Rotation Z"
            ]
        )
        historyValues.addAbs(1.0, at: CACurrentMediaTime(), monotonic: true);
    }
    
    override func generateGeometriesFromInputs(inputs: [String : Any], withScene scene: GeometriesSceneBase?) -> [any Geometry] {
        var lines: [Line] = []
        var startColor = colorFromInputs(inputs, name: "Color start")
        var endColor = colorFromInputs(inputs, name: "Color end")
        
        var brightness = floatFromInputs(inputs, name: "Brightness")
        var saturation = floatFromInputs(inputs, name: "Saturation")
        
        let rotationX = floatFromInputs(inputs, name: "Rotation X")
        let rotationY = floatFromInputs(inputs, name: "Rotation Y")
        let rotationZ = floatFromInputs(inputs, name: "Rotation Z")
        
        let length = floatFromInputs(inputs, name: "Length")
        let historyDelay = floatFromInputs(inputs, name: "History delay (ms)")
        
        let statefulRotationX = floatFromInputs(inputs, name: "Stateful Rotation X")
        let statefulRotationY = floatFromInputs(inputs, name: "Stateful Rotation Y")
        let statefulRotationZ = floatFromInputs(inputs, name: "Stateful Rotation Z")
        
        let scale = ColorScale(colors: [startColor, endColor], mode: .hsl)
        
        historyValues.addAbs(Double(length), at: CACurrentMediaTime(), monotonic: true)
        
        
        for i in 0...100 {
            var t = Float(i) / 99.0
            let color = scale.color(at: Double(t), saturation: Double(saturation), brightness: Double(brightness))
            
            var line = Line(
                startPoint: SIMD3<Float>((t - 0.5) * 3.0,
                                         -Float(historyValues.valueAbs(at: CACurrentMediaTime() - Double(i) * Double(historyDelay) / 1000.0 )!),
                                         0.0),
                endPoint: SIMD3<Float>((t - 0.5) * 3.0,
                                       Float(historyValues.valueAbs(at: CACurrentMediaTime() - Double(i) * Double(historyDelay) / 1000.0 )!),
                                       0.0),
                lineWidthStart: 2.0,
                lineWidthEnd: 2.0
            )
            
            line.setBasicEndPointColors(startColor: color.toSIMD4(), endColor: color.toSIMD4())
            
            
            lines.append(
                line
            )
        }
        
        let rotationMatrixX = matrix_rotation(angle: rotationX + statefulRotationX, axis: SIMD3<Float>(x: 1, y: 0, z: 0))
        for i in 0..<lines.count {
            lines[i] = lines[i].applyMatrix(rotationMatrixX)
        }

        let rotationMatrixY = matrix_rotation(angle: rotationY + statefulRotationY, axis: SIMD3<Float>(x: 0, y: 1, z: 0))
        for i in 0..<lines.count {
            lines[i] = lines[i].applyMatrix(rotationMatrixY)
        }

        let rotationMatrixZ = matrix_rotation(angle: rotationZ + statefulRotationZ, axis: SIMD3<Float>(x: 0, y: 0, z: 1))
        for i in 0..<lines.count {
            lines[i] = lines[i].applyMatrix(rotationMatrixZ)
        }
        
        
        
        return lines
    }
}
