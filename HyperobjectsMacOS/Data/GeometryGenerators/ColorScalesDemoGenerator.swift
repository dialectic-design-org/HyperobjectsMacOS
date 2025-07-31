//
//  ColorScalesDemoGenerator.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 31/07/2025.
//

import Foundation
import simd

class ColorScalesDemoGenerator: CachedGeometryGenerator {
    init() {
        super.init(
            name: "Color Scales Demo Generator",
            inputDependencies: [
                "Color start",
                "Color end",
                "Rotation",
                "Brightness",
                "Saturation"
            ]
        )
    }
    
    override func generateGeometriesFromInputs(inputs: [String : Any]) -> [any Geometry] {
        var lines: [Line] = []
        var startColor = colorFromInputs(inputs, name: "Color start")
        var endColor = colorFromInputs(inputs, name: "Color end")
        
        var brightness = floatFromInputs(inputs, name: "Brightness")
        var saturation = floatFromInputs(inputs, name: "Saturation")
        
        let scale = ColorScale(colors: [startColor, endColor], mode: .hsl)
        
        
        print(brightness)
        
        for i in 0...100 {
            var t = Float(i) / 99.0
            let color = scale.color(at: Double(t), saturation: Double(saturation), brightness: Double(brightness))
            
            var line = Line(
                startPoint: SIMD3<Float>((t - 0.5) * 3.0, -1.0, 0.0),
                endPoint: SIMD3<Float>((t - 0.5) * 3.0, 1.0, 0.0),
                lineWidthStart: 2.0,
                lineWidthEnd: 2.0
            )
            
            line.setBasicEndPointColors(startColor: color.toSIMD4(), endColor: color.toSIMD4())
            
            
            lines.append(
                line
            )
        }
        
        
        
        return lines
    }
}
