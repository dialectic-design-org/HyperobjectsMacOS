//
//  CSGVertex.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 05/01/2026.
//

import simd

struct CSGVertex {
    var position: SIMD3<Float>
    
    init(_ position: SIMD3<Float>) {
        self.position = position
    }
    
    func interpolate(to other: CSGVertex, t: Float) -> CSGVertex {
        CSGVertex(position + (other.position - position) * t)
    }
}

extension CSGVertex: Equatable {
    static func == (lhs: CSGVertex, rhs: CSGVertex) -> Bool {
        simd_length(lhs.position - rhs.position) < CSG_EPSILON
    }
}
