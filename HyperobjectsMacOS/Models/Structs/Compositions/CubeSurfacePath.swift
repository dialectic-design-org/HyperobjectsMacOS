//
//  CubeSurfacePath.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 22/01/2026.
//

import simd

func traceCubeSurfacePath(
    startPoint: SIMD3<Float>,
    direction: SIMD3<Float>,
    length: Float,
    cornerTurn: Float = 0.0,
    halfSize: Float = 0.5,
    pointsPerUnit: Float = 100.0
) -> [SIMD3<Float>] {
    let epsilon: Float = 1e-6
    
    func snapToSurface(_ p: SIMD3<Float>) -> (point: SIMD3<Float>, faceAxis: Int, faceSign: Float) {
        var result = simd_clamp(p, SIMD3(repeating: -halfSize), SIMD3(repeating: halfSize))
        let absP = abs(result)
        let maxAxis = absP.x >= absP.y && absP.x >= absP.z ? 0 : (absP.y >= absP.z ? 1 : 2)
        let sign: Float = result[maxAxis] >= 0 ? 1 : -1
        result[maxAxis] = sign * halfSize
        return (result, maxAxis, sign)
    }
    
    func projectToFace(_ d: SIMD3<Float>, faceAxis: Int) -> SIMD3<Float> {
        var proj = d
        proj[faceAxis] = 0
        let len = simd_length(proj)
        return len > epsilon ? proj / len : SIMD3<Float>.zero
    }
    
    func nearestEdge(_ p: SIMD3<Float>, _ d: SIMD3<Float>, faceAxis: Int)
        -> (t: Float, axis: Int, sign: Float)? {
        var best: (t: Float, axis: Int, sign: Float)? = nil
        
        for axis in 0..<3 where axis != faceAxis && abs(d[axis]) > epsilon {
            let targetSign: Float = d[axis] > 0 ? 1 : -1
            let t = (targetSign * halfSize - p[axis]) / d[axis]
            
            if t > epsilon && (best == nil || t < best!.t) {
                best = (t, axis, targetSign)
            }
        }
        return best
    }
    
    func transformDirection(_ d: SIMD3<Float>, fromAxis: Int, fromSign: Float, toAxis: Int) -> SIMD3<Float> {
        let sharedAxis = 3 - fromAxis - toAxis
        var newDir = SIMD3<Float>.zero
        newDir[sharedAxis] = d[sharedAxis]                    // parallel to edge: unchanged
        newDir[fromAxis] = -fromSign * abs(d[toAxis])         // perpendicular: folds away from old face
        
        let len = simd_length(newDir)
        return len > epsilon ? newDir / len : .zero
    }
    
    func rotateInFace(_ d: SIMD3<Float>, faceAxis: Int, angle: Float) -> SIMD3<Float> {
        let axes = [0, 1, 2].filter { $0 != faceAxis }
        let (a1, a2) = (axes[0], axes[1])
        
        let cosA = cos(angle)
        let sinA = sin(angle)
        
        var result = SIMD3<Float>.zero
        result[a1] = d[a1] * cosA - d[a2] * sinA
        result[a2] = d[a1] * sinA + d[a2] * cosA
        return simd_normalize(result)
    }
    
    var (pos, faceAxis, faceSign) = snapToSurface(startPoint)
    var dir = projectToFace(direction, faceAxis: faceAxis)
    
    guard simd_length(dir) > epsilon else { return [pos] }
    
    // Collect exact segments (edge-to-edge paths)
    var segments: [(start: SIMD3<Float>, end: SIMD3<Float>)] = []
    var remaining = length
    
    while remaining > epsilon {
        guard let edge = nearestEdge(pos, dir, faceAxis: faceAxis) else {
            segments.append((pos, pos + dir * remaining))
            break
        }
        
        if edge.t >= remaining {
            segments.append((pos, pos + dir * remaining))
            break
        }
        
        // Record segment to edge
        let edgePoint = pos + dir * edge.t
        segments.append((pos, edgePoint))
        remaining -= edge.t
        
        // Check for corner: is the other tangent axis also at boundary?
        let otherAxis = 3 - faceAxis - edge.axis
        let atCorner = abs(abs(edgePoint[otherAxis]) - halfSize) < epsilon * 100
        
        // Transform direction to new face
        var newDir = transformDirection(dir, fromAxis: faceAxis, fromSign: faceSign, toAxis: edge.axis)
        
        // Apply corner turn bias
        if atCorner && abs(cornerTurn) > epsilon {
            let turnAngle = cornerTurn * Float.pi * 0.25
            newDir = rotateInFace(newDir, faceAxis: edge.axis, angle: turnAngle)
        }
        
        // Transition to new face
        pos = edgePoint
        faceAxis = edge.axis
        faceSign = edge.sign
        dir = newDir
        
        if simd_length(dir) < epsilon { break }
    }
    
    var points: [SIMD3<Float>] = []
    
    for (start, end) in segments {
        let segLength = simd_length(end - start)
        let count = max(1, Int(ceil(segLength * pointsPerUnit)))
        
        for i in 0..<count {
            let t = Float(i) / Float(count)
            points.append(start + (end - start) * t)
        }
    }
    
    // Add final point
    if let last = segments.last {
        points.append(last.end)
    }
    
    return points
}
