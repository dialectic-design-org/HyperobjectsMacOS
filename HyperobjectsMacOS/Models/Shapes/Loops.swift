//
//  Loops.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 30/07/2025.
//


func generateLoopsSegments(nSegments: Int) -> [Line] {
    precondition(nSegments >= 1, "At least 1 segment required")
    let anglePerSegment = (2 * Float.pi) / Float(nSegments)
    let radius: Float = 1
    var segments: [Line] = []
    let k = (4.0 / 3.0) * tan(anglePerSegment / 4.0)
    
    for i in 0..<nSegments {
        let theta0 = Float(i) * anglePerSegment
        let theta1 = Float(i + 1) * anglePerSegment
        let cos0 = cos(theta0), sin0 = sin(theta0)
        let cos1 = cos(theta1), sin1 = sin(theta1)
        
        let p0 = SIMD3<Float>(radius * cos0, radius * sin0, 0)
        let p3 = SIMD3<Float>(radius * cos1, radius * sin1, 0)
        
        let tangent0 = SIMD3<Float>(sin0, -cos0, 0)
        let tangent1 = SIMD3<Float>(sin1, -cos1, 0)
        
        let p1 = p0 + k * anglePerSegment * tangent0
        let p2 = p3 - k * anglePerSegment * tangent1
        let segment = Line(
            startPoint: p0,
            endPoint: p3,
            degree: 3,
            controlPoints: [p1, p2]
        )
        segments.append(segment)
    }
    var maxDeviation: Float = 0.0
    for segment in segments {
        let t: Float = 0.5
        let p = segment.interpolate(t: t)
        let radial = length(SIMD2<Float>(p.x, p.y))
        maxDeviation = max(maxDeviation, abs(radial - radius))
    }
    print("Max radial deviation from unit circle: \(maxDeviation)")
    
    return segments
}
