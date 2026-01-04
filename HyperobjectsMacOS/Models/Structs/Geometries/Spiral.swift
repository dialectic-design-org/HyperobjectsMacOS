//
//  Spiral.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 04/01/2026.
//

import simd

struct Spiral {
    var rotations: Float = 1
    var radius: Float = 0.5
    var height: Float = 1.0
    var offset: Float = 0.0
    
    func pointAtTime(_ t: Float) -> SIMD3<Float> {
        let angle = t * Float.pi * 2 * rotations
        let x = cos(angle + offset) * radius
        let y = (t - 0.5) * height
        let z = sin(angle + offset) * radius * 1.0
        
        return SIMD3<Float>(x, y, z)
    }
    
    func toLines(stepSize: Float = 0.1) -> [Line] {
        var lines: [Line] = []
        var t: Float = 0.0
        var previousPoint = pointAtTime(t)
        
        while t <= 1.0 {
            t += stepSize
            let currentPoint = pointAtTime(t)
            lines.append(Line(startPoint: previousPoint, endPoint: currentPoint))
            previousPoint = currentPoint
        }
        return lines
    }

    func distanceToPoint(_ point: SIMD3<Float>, samples: Int = 100) -> Float {
        var startT: Float = 0.0
        var endT: Float = 1.0
        var minDistanceSq = Float.greatestFiniteMagnitude
        var bestT: Float = 0.0
        
        // Iterative refinement to find the closest point on the continuous curve.
        // Instead of one pass, we do multiple passes, zooming in on the best spot found.
        let passes = 4
        let samplesPerPass = max(10, samples / passes)
        
        for _ in 0..<passes {
            let step = (endT - startT) / Float(samplesPerPass)
            
            for i in 0...samplesPerPass {
                let t = startT + Float(i) * step
                let clampedT = max(0.0, min(1.0, t))
                
                let spiralPoint = pointAtTime(clampedT)
                let distanceSq = simd_distance_squared(spiralPoint, point)
                
                if distanceSq < minDistanceSq {
                    minDistanceSq = distanceSq
                    bestT = clampedT
                }
            }
            
            // Zoom in: set the new search range around the best T found so far.
            // We expand by 'step' on both sides to ensure the true minimum is included.
            startT = max(0.0, bestT - step)
            endT = min(1.0, bestT + step)
        }
        
        return sqrt(minDistanceSq)
    }
}
