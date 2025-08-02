//
//  smoothedBezierPath.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 02/08/2025.
//

import simd
import Foundation

func smoothedBezierPath(points: [SIMD3<Float>], tolerance: Float) -> [Line] {
    guard points.count >= 2 else { return [] }
    
    let simplified = douglasPeucker(points: points, epsilon: tolerance)
    
    if simplified.count < 2 {
        return [Line(
            startPoint: points.first!,
            endPoint: points.last!)]
    }
    
// Step 2: Create a smooth interpolating spline using Catmull-Rom, convert each segment to cubic Bezier
    // Need at least four points for standard Catmull-Rom; we'll pad start/end by duplicating.
    var extended: [SIMD3<Float>] = []
    if simplified.count == 2 {
        // Degenerate: just straight cubic from A to B with controls as linear
        let p0 = simplified[0]
        let p1 = simplified[1]
        // Simple linear cubic: control points on the line
        let ctrl1 = p0 + (p1 - p0) / 3
        let ctrl2 = p0 + 2 * (p1 - p0) / 3
        let line = Line(startPoint: p0, endPoint: p1, degree: 3, controlPoints: [ctrl1, ctrl2])
        return [line]
    } else {
        // Pad endpoints to allow Catmull-Rom to cover first and last.
        extended.append(simplified.first!) // P_{-1} as duplicate of first
        extended.append(contentsOf: simplified)
        extended.append(simplified.last!)  // P_{n+1} as duplicate of last
    }
    
    var result: [Line] = []
    // For each segment between Pi and P_{i+1} in the original simplified array, we use points:
    // P_{i-1}, P_i, P_{i+1}, P_{i+2} from extended.
    // Indexing offset: simplified[0] is at extended[1]
    for i in 1 ..< extended.count - 2 {
        let p0 = extended[i - 1]
        let p1 = extended[i]
        let p2 = extended[i + 1]
        let p3 = extended[i + 2]
        
        // Convert Catmull-Rom segment from p1 to p2 into cubic Bezier
        let (b0, b1, b2, b3) = catmullRomToBezier(p0: p0, p1: p1, p2: p2, p3: p3)
        // b0 should equal p1, b3 equal p2 (within float precision)
        let line = Line(startPoint: b0, endPoint: b3, degree: 3, controlPoints: [b1, b2])
        result.append(line)
    }
    
    return result
}


private func douglasPeucker(points: [SIMD3<Float>], epsilon: Float) -> [SIMD3<Float>] {
    guard points.count >= 3 else { return points }
    
    let first = points.first!
    let last = points.last!
    var maxDist: Float = 0
    var index = 0
    for i in 1..<(points.count - 1) {
        let d = pointLineDistance(point: points[i], lineStart: first, lineEnd: last)
        if d > maxDist {
            maxDist = d
            index = i
        }
    }
    
    if maxDist > epsilon {
        let left = Array(points[0...index])
        let right = Array(points[index...])
        let rec1 = douglasPeucker(points: left, epsilon: epsilon)
        let rec2 = douglasPeucker(points: right, epsilon: epsilon)
        
        var out = rec1
        out.removeLast()
        out.append(contentsOf: rec2)
        return out
    } else {
        return [first, last]
    }
}

/// Distance from point to line segment in 3D (perpendicular)
private func pointLineDistance(point: SIMD3<Float>, lineStart: SIMD3<Float>, lineEnd: SIMD3<Float>) -> Float {
    let v = lineEnd - lineStart
    let w = point - lineStart
    let c1 = dot(w, v)
    if c1 <= 0 {
        return length(point - lineStart)
    }
    let c2 = dot(v, v)
    if c2 <= c1 {
        return length(point - lineEnd)
    }
    let t = c1 / c2
    let projection = lineStart + v * t
    return length(point - projection)
}

private func catmullRomToBezier(p0: SIMD3<Float>, p1: SIMD3<Float>, p2: SIMD3<Float>, p3: SIMD3<Float>) -> (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>, SIMD3<Float>) {
    // Standard formula: for uniform Catmull-Rom, the equivalent Bezier control points are:
    // B0 = p1
    // B1 = p1 + (p2 - p0)/6
    // B2 = p2 - (p3 - p1)/6
    // B3 = p2
    let b0 = p1
    let b1 = p1 + (p2 - p0) / 6.0
    let b2 = p2 - (p3 - p1) / 6.0
    let b3 = p2
    return (b0, b1, b2, b3)
}
