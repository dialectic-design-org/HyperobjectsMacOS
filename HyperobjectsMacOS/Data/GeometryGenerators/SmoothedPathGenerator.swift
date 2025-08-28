//
//  SmoothedPathGenerator.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 02/08/2025.
//

import Foundation
import simd
import SwiftUI

// Generate N random points inside a cube of side length `size` centered at origin.
private func generateRandomPoints(count: Int, size: Float) -> [SIMD3<Float>] {
    return (0..<count).map { _ in
        let half = size / 2
        let x = Float.random(in: -half...half)
        let y = Float.random(in: -half...half)
        let z = Float.random(in: -half...half)
        return SIMD3<Float>(x, y, z)
    }
}


// Greedy nearest-neighbor ordering starting from a random point.
private func greedyOrder(points: [SIMD3<Float>]) -> [SIMD3<Float>] {
    guard !points.isEmpty else { return [] }
    var remaining = points
    var ordered: [SIMD3<Float>] = []
    
    // Start at a random index
    let startIdx = Int.random(in: 0..<remaining.count)
    ordered.append(remaining.remove(at: startIdx))
    
    while !remaining.isEmpty {
        let last = ordered.last!
        // Find index of closest remaining point
        var bestIdx = 0
        var bestDist = distance(last, remaining[0])
        for i in 1..<remaining.count {
            let d = distance(last, remaining[i])
            if d < bestDist {
                bestDist = d
                bestIdx = i
            }
        }
        ordered.append(remaining.remove(at: bestIdx))
    }
    return ordered
}

class SmoothedPathGenerator: CachedGeometryGenerator {
    var randomPoints: [SIMD3<Float>] = []
    var sortedPoints: [SIMD3<Float>] = []
    var smoothedLines: [Line] = []
    var previousSmoothingValue: Float = 0.0
    var pointT: Double = 0.0
    var prevTolerance: Float = 0.5
    
    
    init() {
        super.init(name: "Smoothed Path Generator",
                   inputDependencies: [
                    "Length",
                    "Tolerance",
                    "Stateful Rotation X",
                    "Stateful Rotation Y",
                    "Stateful Rotation Z"
                   ])
    }
    
    override func generateGeometriesFromInputs(inputs: [String : Any]) -> [any Geometry] {
        
        let statefulRotationX = floatFromInputs(inputs, name: "Stateful Rotation X")
        let statefulRotationY = floatFromInputs(inputs, name: "Stateful Rotation Y")
        let statefulRotationZ = floatFromInputs(inputs, name: "Stateful Rotation Z")
        let toleranceInput = floatFromInputs(inputs, name: "Tolerance")
        
        var startColor = colorFromInputs(inputs, name: "Color start")
        var endColor = colorFromInputs(inputs, name: "Color end")
        
        let pointsCount = intFromInputs(inputs, name: "Points count")
        
        
        var lines: [Line] = []
        
        let scale = ColorScale(colors: [startColor, endColor], mode: .hsl)
        
        var pointsUpdated: Bool = false
        if pointsCount != randomPoints.count {
            pointsUpdated = true
            randomPoints = generateRandomPoints(count: pointsCount, size: 5.0)
            sortedPoints = greedyOrder(points: randomPoints)
            
        }
        if prevTolerance != toleranceInput || pointsUpdated {
            prevTolerance = toleranceInput
            smoothedLines = smoothedBezierPath(points: sortedPoints, tolerance: toleranceInput)
            
            var tIncrement = 1.0 / Double(smoothedLines.count)
            for i in 0..<smoothedLines.count {
                var lineT = Double(i) / Double(smoothedLines.count)
                smoothedLines[i].lineWidthStart = 3.0
                smoothedLines[i].lineWidthEnd = 3.0
                smoothedLines[i].setBasicEndPointColors(
                    startColor: scale.color(at: lineT).toSIMD4(),
                    endColor: scale.color(at: lineT + tIncrement).toSIMD4()
                )
                smoothedLines[i].pathID = 1
            }
        }
        
        pointT += 0.0001
        pointT = fmod(pointT, 1.0)
        
        var smoothedPath = PathGeometry(lines: smoothedLines)
        var smoothedPathPoint = smoothedPath.interpolate(t: pointT)
        
        var pointLinesWidth: Float = 0.5
        var lineExtension: Float = 1.0
        
        var pointLines: [Line] = [
            Line(
                startPoint: smoothedPathPoint + SIMD3<Float>(0.0, -lineExtension, 0.0),
                endPoint: smoothedPathPoint + SIMD3<Float>(0.0, lineExtension, 0.0),
                lineWidthStart: pointLinesWidth,
                lineWidthEnd: pointLinesWidth
            ),
            Line(
                startPoint: smoothedPathPoint + SIMD3<Float>(-lineExtension, 0.0, 0.0),
                endPoint: smoothedPathPoint + SIMD3<Float>(lineExtension, 0.0, 0.0),
                lineWidthStart: pointLinesWidth,
                lineWidthEnd: pointLinesWidth
            ),
            Line(
                startPoint: smoothedPathPoint + SIMD3<Float>(0.0, 0.0, -lineExtension),
                endPoint: smoothedPathPoint + SIMD3<Float>(0.0, 0.0, lineExtension),
                lineWidthStart: pointLinesWidth,
                lineWidthEnd: pointLinesWidth
            ),
        ]
        for i in 0..<pointLines.count {
            pointLines[i].setBasicEndPointColors(
                startColor: Color.green.toSIMD4(),
                endColor: Color.green.toSIMD4()
            )
        }
        lines += pointLines
        
        for i in stride(from: 0, to: randomPoints.count, by: 1) {
            let p1 = randomPoints[i]
            let p2 = randomPoints[(i + 1) % randomPoints.count]
            var line = Line(startPoint: p1, endPoint: p2)
            line.setBasicEndPointColors(startColor: SIMD4<Float>(repeating: 0.2), endColor: SIMD4<Float>(repeating: 0.2))
            lines.append(line)
        }
        
        for i in stride(from: 0, to: sortedPoints.count, by: 1) {
            let p1 = sortedPoints[i]
            let p2 = sortedPoints[(i + 1) % sortedPoints.count]
            var line = Line(startPoint: p1, endPoint: p2)
            line.setBasicEndPointColors(startColor: SIMD4<Float>(repeating: 0.6), endColor: SIMD4<Float>(repeating: 0.6))
            lines.append(line)
        }
        
        lines += smoothedLines
        
        let textLines = textToBezierPaths("TEST", font: .custom("SF Mono", size: 48), size: 0.4, maxLineWidth: 5.0)
        
        for char in textLines {
            lines += char
        }
        
        let rotationMatrixX = matrix_rotation(angle: statefulRotationX, axis: SIMD3<Float>(x: 1, y: 0, z: 0))
        let rotationMatrixY = matrix_rotation(angle: statefulRotationY, axis: SIMD3<Float>(x: 0, y: 1, z: 0))
        let rotationMatrixZ = matrix_rotation(angle: statefulRotationZ, axis: SIMD3<Float>(x: 0, y: 0, z: 1))

        let rotationMatrixXYZ = rotationMatrixX * rotationMatrixY * rotationMatrixZ
        for i in 0..<lines.count {
            lines[i] = lines[i].applyMatrix(rotationMatrixXYZ)
        }
        
        return lines
    }
}
