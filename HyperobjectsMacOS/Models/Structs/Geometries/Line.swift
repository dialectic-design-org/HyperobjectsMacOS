//
//  Line.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 11/10/2024.
//

import Foundation
import simd

enum LineColorMode: String, CaseIterable, Identifiable {
    case uniform = "uniform"
    case gradient = "gradient"
    
    var id: String { self.rawValue }
}

struct Line: Geometry {
    let id = UUID()
    let type: GeometryType = .line
    var startPoint: SIMD3<Float>
    var endPoint: SIMD3<Float>
    var lineWidth: Float = 1.0
    var color: SIMD4<Float> = SIMD4<Float>(1.0, 1.0, 1.0, 1.0)
    var colorStart: SIMD4<Float> = SIMD4<Float>(1.0, 1.0, 1.0, 1.0)
    var colorEnd: SIMD4<Float> = SIMD4<Float>(1.0, 1.0, 1.0, 1.0)
    
    func getPoints() -> [SIMD3<Float>] {
        return [startPoint, endPoint]
    }
    
    func getLineWidth() -> Float {
        return lineWidth
    }
    
    mutating func applyMatrix(_ matrix: matrix_float4x4) -> Line {
        let vecStartRotated = matrix * SIMD4<Float>(startPoint.x, startPoint.y, startPoint.z, 1.0)
        let vecEndRotated = matrix * SIMD4<Float>(endPoint.x, endPoint.y, endPoint.z, 1.0)
        startPoint = SIMD3<Float>(vecStartRotated.x, vecStartRotated.y, vecStartRotated.z)
        endPoint = SIMD3<Float>(vecEndRotated.x, vecEndRotated.y, vecEndRotated.z)
        return self
    }
}
