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
    var degree: Int = 1;
    var controlPoints: [SIMD3<Float>] = []
    var colorStart: SIMD4<Float> = SIMD4<Float>(1.0, 1.0, 1.0, 1.0)
    var colorStartOuterLeft: SIMD4<Float> = SIMD4<Float>(1.0, 1.0, 1.0, 1.0)
    var colorStartOuterRight: SIMD4<Float> = SIMD4<Float>(1.0, 1.0, 1.0, 1.0)
    
    var colorEnd: SIMD4<Float> = SIMD4<Float>(1.0, 1.0, 1.0, 1.0)
    var colorEndOuterLeft: SIMD4<Float> = SIMD4<Float>(1.0, 1.0, 1.0, 1.0)
    var colorEndOuterRight: SIMD4<Float> = SIMD4<Float>(1.0, 1.0, 1.0, 1.0)
    
    var sigmoidSteepness0: Float = 6.0
    var sigmoidMidpoint0: Float = 0.5
    var sigmoidSteepness1: Float = 6.0
    var sigmoidMidpoint1: Float = 0.5
    
    var lineWidthStart: Float = 0.0005
    var lineWidthEnd: Float = 0.00005
    
    func getPoints() -> [SIMD3<Float>] {
        return [startPoint, endPoint]
    }
    
    
    mutating func applyMatrix(_ matrix: matrix_float4x4) -> Line {
        let vecStartRotated = matrix * SIMD4<Float>(startPoint.x, startPoint.y, startPoint.z, 1.0)
        let vecEndRotated = matrix * SIMD4<Float>(endPoint.x, endPoint.y, endPoint.z, 1.0)
        startPoint = SIMD3<Float>(vecStartRotated.x, vecStartRotated.y, vecStartRotated.z)
        endPoint = SIMD3<Float>(vecEndRotated.x, vecEndRotated.y, vecEndRotated.z)
        // Iterate over control points
        for (i, point) in controlPoints.enumerated() {
            let vecRotated = matrix * SIMD4<Float>(point.x, point.y, point.z, 1.0)
            controlPoints[i] = SIMD3<Float>(vecRotated.x, vecRotated.y, vecRotated.z)
        }
        return self
    }
    
    func initBasic(p1: SIMD3<Float>, p2: SIMD3<Float>) -> Line {
        return Line(startPoint: p1, endPoint: p2)
    }
    
    func initWithColor(p1: SIMD3<Float>, p2: SIMD3<Float>, c: SIMD4<Float>) -> Line {
        var l = self.initBasic(p1: p1, p2: p2)
        l.colorStart = c
        l.colorStartOuterLeft = c
        l.colorStartOuterRight = c
        l.colorEnd = c
        l.colorEndOuterLeft = c
        l.colorEndOuterRight = c
        return l
    }
    
    mutating func setBasicEndPointColors(startColor: SIMD4<Float>, endColor: SIMD4<Float>) -> Line {
        self.colorStart = startColor
        self.colorStartOuterLeft = startColor
        self.colorStartOuterRight = startColor
        self.colorEnd = endColor
        self.colorEndOuterLeft = endColor
        self.colorEndOuterRight = endColor
        return self
    }
    
    func interpolate(t: Float) -> SIMD3<Float> {
        switch degree {
        case 1:
            return mix(startPoint, endPoint, t: t)
        case 2:
            guard controlPoints.count >= 1 else { return mix(startPoint, endPoint, t: t)}
            let p0 = startPoint
            let p1 = controlPoints[0]
            let p2 = endPoint
            let a = mix(p0, p1, t: t)
            let b = mix(p1, p2, t: t)
            return mix(a, b, t: t)
        case 3:
            guard controlPoints.count >= 2 else { return mix(startPoint, endPoint, t: t) }
            let p0 = startPoint
            let p1 = controlPoints[0]
            let p2 = controlPoints[1]
            let p3 = endPoint
            let a = mix(p0, p1, t: t)
            let b = mix(p1, p2, t: t)
            let c = mix(p2, p3, t: t)
            let d = mix(a, b, t: t)
            let e = mix(b, c, t: t)
            return mix(d, e, t: t)
        default:
            return mix(startPoint, endPoint, t: t)
        }
    }
}
