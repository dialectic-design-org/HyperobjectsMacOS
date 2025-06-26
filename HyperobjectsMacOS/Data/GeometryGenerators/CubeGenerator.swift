//
//  CubeGenerator.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 06/11/2024.
//

import Foundation
import simd

class CubeGenerator: CachedGeometryGenerator {
    init() {
        super.init(name: "Cube Generator", inputDependencies: ["Size", "Rotation"])
    }
    
    override func generateGeometriesFromInputs(inputs: [String : Any]) -> [any Geometry] {
        var lines: [Line] = []

        let size = floatFromInputs(inputs, name: "Size")
        let width = floatFromInputs(inputs, name: "Width")
        let height = floatFromInputs(inputs, name: "Height")
        let depth = floatFromInputs(inputs, name: "Depth")
        
        let rotationX = floatFromInputs(inputs, name: "Rotation X")
        let rotationY = floatFromInputs(inputs, name: "Rotation Y")
        let rotationZ = floatFromInputs(inputs, name: "Rotation Z")
        
        // Front
        lines.append(
            Line(
                startPoint: SIMD3<Float>(x: -1.0, y: -1.0, z: -1.0),
                endPoint: SIMD3<Float>(x: 1.0, y: -1.0, z: -1.0)
            )
        )
        lines.append(
            Line(
                startPoint: SIMD3<Float>(x: 1.0, y: -1.0, z: -1.0),
                endPoint: SIMD3<Float>(x: 1.0, y: 1.0, z: -1.0)
            )
        )
        lines.append(
            Line(
                startPoint: SIMD3<Float>(x: 1.0, y: 1.0, z: -1.0),
                endPoint: SIMD3<Float>(x: -1.0, y: 1.0, z: -1.0)
            )
        )
        lines.append(
            Line(
                startPoint: SIMD3<Float>(x: -1.0, y: 1.0, z: -1.0),
                endPoint: SIMD3<Float>(x: -1.0, y: -1.0, z: -1.0)
            )
        )
        
        
        // Back
        lines.append(
            Line(
                startPoint: SIMD3<Float>(x: -1.0, y: -1.0, z: 1.0),
                endPoint: SIMD3<Float>(x: 1.0, y: -1.0, z: 1.0)
            )
        )
        lines.append(
            Line(
                startPoint: SIMD3<Float>(x: 1.0, y: -1.0, z: 1.0),
                endPoint: SIMD3<Float>(x: 1.0, y: 1.0, z: 1.0)
            )
        )
        lines.append(
            Line(
                startPoint: SIMD3<Float>(x: 1.0, y: 1.0, z: 1.0),
                endPoint: SIMD3<Float>(x: -1.0, y: 1.0, z: 1.0)
            )
        )
        lines.append(
            Line(
                startPoint: SIMD3<Float>(x: -1.0, y: 1.0, z: 1.0),
                endPoint: SIMD3<Float>(x: -1.0, y: -1.0, z: 1.0)
            )
        )
        
        
        // Connecting Lines
        lines.append(
            Line(
                startPoint: SIMD3<Float>(x: -1.0, y: -1.0, z: -1.0),
                endPoint: SIMD3<Float>(x: -1.0, y: -1.0, z: 1.0)
            )
        )
        lines.append(
            Line(
                startPoint: SIMD3<Float>(x: 1.0, y: -1.0, z: -1.0),
                endPoint: SIMD3<Float>(x: 1.0, y: -1.0, z: 1.0)
            )
        )
        lines.append(
            Line(
                startPoint: SIMD3<Float>(x: 1.0, y: 1.0, z: -1.0),
                endPoint: SIMD3<Float>(x: 1.0, y: 1.0, z: 1.0)
            )
        )
        lines.append(
            Line(
                startPoint: SIMD3<Float>(x: -1.0, y: 1.0, z: -1.0),
                endPoint: SIMD3<Float>(x: -1.0, y: 1.0, z: 1.0)
            )
        )
        // Apply width, height, depth transforms
        for i in 0..<lines.count {
            lines[i].startPoint.y *= height
            lines[i].endPoint.y *= height
            
            lines[i].startPoint.x *= width
            lines[i].endPoint.x *= width
            
            lines[i].startPoint.z *= depth
            lines[i].endPoint.z *= depth
        }
        
        // Apply size and rotation
        for i in 0..<lines.count {
            let line = lines[i]
            lines[i] = Line(
                startPoint: line.startPoint * size,
                endPoint: line.endPoint * size
            )
        }
        if rotationX != 0 {
            let rotationMatrix = matrix_rotation(angle: rotationX, axis: SIMD3<Float>(x: 1, y: 0, z: 0))
            for i in 0..<lines.count {
                lines[i] = lines[i].applyMatrix(rotationMatrix)
            }
        }

        if rotationY != 0 {
            let rotationMatrix = matrix_rotation(angle: rotationY, axis: SIMD3<Float>(x: 0, y: 1, z: 0))
            for i in 0..<lines.count {
                lines[i] = lines[i].applyMatrix(rotationMatrix)
            }
        }

        if rotationZ != 0 {
            let rotationMatrix = matrix_rotation(angle: rotationZ, axis: SIMD3<Float>(x: 0, y: 0, z: 1))
            for i in 0..<lines.count {
                lines[i] = lines[i].applyMatrix(rotationMatrix)
            }
        }
        
        return lines
    }
}
