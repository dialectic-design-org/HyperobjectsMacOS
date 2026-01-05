//
//  Plane.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 05/01/2026.
//

import simd

struct Plane {
    var normal: SIMD3<Float>
    var w: Float
    
    init(normal: SIMD3<Float>, w: Float) {
        self.normal = simd_normalize(normal)
        self.w = w
    }
    
    init(a: SIMD3<Float>, b: SIMD3<Float>, c: SIMD3<Float>) {
        let ab = b - a
        let ac = c - a
        self.normal = simd_normalize(simd_cross(ab, ac))
        self.w = simd_dot(self.normal, a)
    }
    
    func signedDistance(to point: SIMD3<Float>) -> Float {
        simd_dot(normal, point) - w
    }
    
    func classify(_ point: SIMD3<Float>) -> PointClassification {
        let dist = signedDistance(to: point)
        if dist > CSG_EPSILON {
            return .front
        } else if dist < -CSG_EPSILON {
            return .back
        } else {
            return .coplanar
        }
    }
    
    func flipped() -> Plane {
        Plane(normal: -normal, w: -w)
    }
    
    func intersect(lineStart: SIMD3<Float>, lineEnd: SIMD3<Float>) -> Float? {
        let direction = lineEnd - lineStart
        let denom = simd_dot(normal, direction)
        
        if abs(denom) < CSG_EPSILON {
            return nil
        }
        
        let t = (w - simd_dot(normal, lineStart)) / denom
        return t
    }
}
