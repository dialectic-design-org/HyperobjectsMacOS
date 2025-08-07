//
//  Path.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 03/08/2025.
//

import Foundation
import simd


struct PathGeometry: Geometry {
    let id = UUID()
    var type: GeometryType = .path
    var lines: [Line]
    
    func getPoints() -> [SIMD3<Float>] {
        return []
    }
    
    func getLength() -> Double {
        return lines.reduce(0.0) { total, line in
            total + line.length()
        }
    }
    
    func interpolate(t: Double) -> SIMD3<Float> {
        guard !lines.isEmpty else {
            return SIMD3<Float>(0, 0, 0)
        }
        
        // Clamp t to [0, 1] range
        let clampedT = max(0.0, min(1.0, t))
        
        // Handle edge cases
        if clampedT == 0.0 {
            return lines.first!.startPoint
        }
        if clampedT == 1.0 {
            return lines.last!.endPoint
        }
        
        let totalLength = getLength()
        if totalLength == 0.0 {
            return lines.first!.startPoint
        }
        
        let targetDistance = clampedT * totalLength
        var cumulativeLength: Double = 0.0
        
        for line in lines {
            let lineLength = line.length()
            
            if cumulativeLength + lineLength >= targetDistance {
                // The target point is on this line segment
                let distanceAlongLine = targetDistance - cumulativeLength
                let lineT = lineLength > 0 ? distanceAlongLine / lineLength : 0.0
                
                // Use the Line's interpolate method
                return line.interpolate(t: Float(lineT))
            }
            
            cumulativeLength += lineLength
        }
        
        // Fallback (shouldn't reach here with proper clamping)
        return lines.last!.endPoint
    }
}
