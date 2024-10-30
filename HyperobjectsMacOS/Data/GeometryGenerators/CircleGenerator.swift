//
//  circleGenerator.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 12/10/2024.
//

import Foundation
import simd

class CircleGenerator: CachedGeometryGenerator {
    init() {
        super.init(name: "Circle Generator", inputDependencies: ["Radius", "Segments"])
    }
    
    override func generateGeometriesFromInputs(inputs: [String : Any]) -> [any Geometry] {
        var lines: [Line] = []
        
        let segmentsCount: Int = 16
        for i in 0..<segmentsCount {
            let angle: Float = Float(i) / Float(segmentsCount) * 2.0 * .pi
            
            guard let radiusValue = inputs["Radius"],
                  let radius = (radiusValue as? Float) ?? (radiusValue as? Int).map(Float.init) else {
                fatalError("Radius must be a number")
            }
            
            let x: Float = radius * cos(angle)
            let y: Float = radius * sin(angle)
            let nextAngle: Float = Float(i + 1) / Float(segmentsCount) * 2.0 * .pi
            let nextX: Float = radius * cos(nextAngle)
            let nextY: Float = radius * sin(nextAngle)
            lines.append(Line(
                startPoint: SIMD3<Float>(x: x, y: y, z: 0),
                endPoint: SIMD3<Float>(x: nextX, y: nextY, z: 0)
                ))
        }
        return lines
    }
}
