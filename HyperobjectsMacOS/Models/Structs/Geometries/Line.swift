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

// Start with very high value for generic lines so that lower values can be used for specific paths
private var idIncrement: Int = 100000

struct Line: Geometry {
    let id = UUID()
    var pathID = Int(0)
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
    
    var lineWidthStart: Float = 0.6
    var lineWidthEnd: Float = 0.6
    var noiseFloor: Float = 1.0
    
    init(startPoint: SIMD3<Float>,
         endPoint: SIMD3<Float>,
         degree: Int = 1,
         controlPoints: [SIMD3<Float>] = [],
         colorStart: SIMD4<Float> = SIMD4<Float>(1.0, 1.0, 1.0, 1.0),
         colorStartOuterLeft: SIMD4<Float> = SIMD4<Float>(1.0, 1.0, 1.0, 1.0),
         colorStartOuterRight: SIMD4<Float> = SIMD4<Float>(1.0, 1.0, 1.0, 1.0),
         colorEnd: SIMD4<Float> = SIMD4<Float>(1.0, 1.0, 1.0, 1.0),
         colorEndOuterLeft: SIMD4<Float> = SIMD4<Float>(1.0, 1.0, 1.0, 1.0),
         colorEndOuterRight: SIMD4<Float> = SIMD4<Float>(1.0, 1.0, 1.0, 1.0),
         sigmoidSteepness0: Float = 6.0,
         sigmoidMidpoint0: Float = 0.5,
         sigmoidSteepness1: Float = 6.0,
         sigmoidMidpoint1: Float = 0.5,
         lineWidthStart: Float = 0.6,
         lineWidthEnd: Float = 0.6,
         noiseFloor: Float = 1.0) {
        self.pathID = idIncrement
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.degree = degree
        self.controlPoints = controlPoints
        self.colorStart = colorStart
        self.colorEnd = colorEnd
        self.colorStartOuterLeft = colorStartOuterLeft
        self.colorEndOuterLeft = colorEndOuterLeft
        self.colorStartOuterRight = colorStartOuterRight
        self.colorEndOuterRight = colorEndOuterRight
        self.sigmoidSteepness0 = sigmoidSteepness0
        self.sigmoidMidpoint0 = sigmoidMidpoint0
        self.sigmoidSteepness1 = sigmoidSteepness1
        self.sigmoidMidpoint1 = sigmoidMidpoint1
        self.lineWidthStart = lineWidthStart
        self.lineWidthEnd = lineWidthEnd
        self.noiseFloor = noiseFloor
        
        idIncrement += 1
    }
    
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
    
    func length() -> Double {
        if degree == 1 || controlPoints.isEmpty {
            // Straight line case
            let diff = endPoint - startPoint
            return Double(sqrt(diff.x * diff.x + diff.y * diff.y + diff.z * diff.z))
        } else {
            // Bézier curve case - use numerical approximation
            return approximateBezierLength()
        }
    }
    
    func direction() -> SIMD3<Float> {
        return simd_normalize(endPoint - startPoint)
    }
    
    func midPoint() -> SIMD3<Float> {
        0.5 * (endPoint + startPoint)
    }
    
    
    private func approximateBezierLength(segments: Int = 100) -> Double {
        var totalLength: Double = 0.0
        let step = 1.0 / Double(segments)
        
        var previousPoint = evaluateBezier(t: 0.0)
        
        for i in 1...segments {
            let t = Double(i) * step
            let currentPoint = evaluateBezier(t: t)
            
            let diff = currentPoint - previousPoint
            let segmentLength = sqrt(diff.x * diff.x + diff.y * diff.y + diff.z * diff.z)
            totalLength += Double(segmentLength)
            
            previousPoint = currentPoint
        }
        
        return totalLength
    }

    private func evaluateBezier(t: Double) -> SIMD3<Float> {
        let ft = Float(t)
        
        if degree == 2 {
            // Quadratic Bézier: B(t) = (1-t)²P₀ + 2(1-t)tP₁ + t²P₂
            guard controlPoints.count >= 1 else { return startPoint }
            
            let oneMinusT = 1.0 - ft
            let oneMinusTSquared = oneMinusT * oneMinusT
            let tSquared = ft * ft
            let twoOneMinusTt = 2.0 * oneMinusT * ft
            
            return oneMinusTSquared * startPoint +
                   twoOneMinusTt * controlPoints[0] +
                   tSquared * endPoint
                   
        } else if degree == 3 {
            // Cubic Bézier: B(t) = (1-t)³P₀ + 3(1-t)²tP₁ + 3(1-t)t²P₂ + t³P₃
            guard controlPoints.count >= 2 else { return startPoint }
            
            let oneMinusT = 1.0 - ft
            let oneMinusTCubed = oneMinusT * oneMinusT * oneMinusT
            let tCubed = ft * ft * ft
            let threeOneMinusTSquaredT = 3.0 * oneMinusT * oneMinusT * ft
            let threeOneMinusTtSquared = 3.0 * oneMinusT * ft * ft
            
            return oneMinusTCubed * startPoint +
                   threeOneMinusTSquaredT * controlPoints[0] +
                   threeOneMinusTtSquared * controlPoints[1] +
                   tCubed * endPoint
                   
        } else {
            // For higher degree curves, use De Casteljau's algorithm
            return evaluateBezierDeCasteljau(t: ft)
        }
    }

    private func evaluateBezierDeCasteljau(t: Float) -> SIMD3<Float> {
        // Create array of all control points (start, control points, end)
        var points: [SIMD3<Float>] = [startPoint] + controlPoints + [endPoint]
        
        // De Casteljau's algorithm
        for i in 1...degree {
            for j in 0..<(degree - i + 1) {
                points[j] = (1.0 - t) * points[j] + t * points[j + 1]
            }
        }
        
        return points[0]
    }

    func subdivide(at t: Float) -> (Line, Line) {
        let midPoint = interpolate(t: t)
        
        var firstLine = Line(
            startPoint: startPoint,
            endPoint: midPoint,
            degree: degree,
            controlPoints: []
        )
        
        var secondLine = Line(
            startPoint: midPoint,
            endPoint: endPoint,
            degree: degree,
            controlPoints: []
        )
        
        // Calculate new control points for first line
        if degree >= 2 {
            let cp1 = controlPoints[0]
            let newCP1 = mix(startPoint, cp1, t: t)
            firstLine.controlPoints.append(newCP1)
        }
        
        if degree == 3 {
            let cp1 = controlPoints[0]
            let cp2 = controlPoints[1]
            let newCP1 = mix(startPoint, cp1, t: t)
            let newCP2 = mix(cp1, cp2, t: t)
            firstLine.controlPoints[0] = newCP1
            firstLine.controlPoints.append(newCP2)
        }
        
        // Calculate new control points for second line
        if degree >= 2 {
            let cpLast = controlPoints.last!
            let newCPLast = mix(cpLast, endPoint, t: t)
            secondLine.controlPoints.insert(newCPLast, at: 0)
        }
        
        if degree == 3 {
            let cp1 = controlPoints[0]
            let cp2 = controlPoints[1]
            let newCP2 = mix(cp2, endPoint, t: t)
            secondLine.controlPoints.insert(newCP2, at: 0)
        }
        
        return (firstLine, secondLine)
    }

    func subdivide(accuracy: Float) -> [Line] {
        var segments: [Line] = [self]
        var i = 0
        while i < segments.count {
            let segment = segments[i]
            let approxLength = Float(segment.length())
            if approxLength > accuracy {
                let (firstHalf, secondHalf) = segment.subdivide(at: 0.5)
                segments.remove(at: i)
                segments.insert(secondHalf, at: i)
                segments.insert(firstHalf, at: i)
            } else {
                i += 1
            }
        }
        return segments
    }
}

extension Line: Equatable {
    static func == (lhs: Line, rhs: Line) -> Bool {
        simd_length(lhs.startPoint - rhs.startPoint) < CSG_EPSILON &&
        simd_length(lhs.endPoint - rhs.endPoint) < CSG_EPSILON
    }
}

extension Line: Hashable {
    func hash(into hasher: inout Hasher) {
        let scale = 1.0 / CSG_EPSILON
        hasher.combine(Int(startPoint.x * scale))
        hasher.combine(Int(startPoint.y * scale))
        hasher.combine(Int(startPoint.z * scale))
        hasher.combine(Int(endPoint.x * scale))
        hasher.combine(Int(endPoint.y * scale))
        hasher.combine(Int(endPoint.z * scale))
    }
}
