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
        
        
        
        var radius: Float = 100.0
        if let radiusValue: Double = inputs["Radius"] as? Double {
            radius = Float(radiusValue)
        } else if let radiusValue: Float = inputs["Radius"] as? Float {
            radius = radiusValue
        }
        
        let statefulRotationX = floatFromInputs(inputs, name: "Stateful Rotation X")
        let statefulRotationY = floatFromInputs(inputs, name: "Stateful Rotation Y")
        let statefulRotationZ = floatFromInputs(inputs, name: "Stateful Rotation Z")
        
        
        for i in 0..<segmentsCount {
            let angle: Float = Float(i) / Float(segmentsCount) * 2.0 * .pi
            
            
            
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
        
        if statefulRotationX != 0 {
            let rotationMatrix = matrix_rotation(angle: statefulRotationX, axis: SIMD3<Float>(x: 1, y: 0, z: 0))
            for i in 0..<lines.count {
                lines[i] = lines[i].applyMatrix(rotationMatrix)
            }
        }
        
        if statefulRotationY != 0 {
            let rotationMatrix = matrix_rotation(angle: statefulRotationY, axis: SIMD3<Float>(x: 0, y: 1, z: 0))
            for i in 0..<lines.count {
                lines[i] = lines[i].applyMatrix(rotationMatrix)
            }
        }
        
        if statefulRotationZ != 0 {
            let rotationMatrix = matrix_rotation(angle: statefulRotationZ, axis: SIMD3<Float>(x: 0, y: 0, z: 1))
            for i in 0..<lines.count {
                lines[i] = lines[i].applyMatrix(rotationMatrix)
            }
        }
        
        
        return lines
    }
}
