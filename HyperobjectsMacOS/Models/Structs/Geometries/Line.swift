//
//  Line.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 11/10/2024.
//

import Foundation
import simd

struct Line: Geometry {
    let id = UUID()
    let type: GeometryType = .line
    var startPoint: SIMD3<Float>
    var endPoint: SIMD3<Float>
    
    func getPoints() -> [SIMD3<Float>] {
        return [startPoint, endPoint]
    }
}
