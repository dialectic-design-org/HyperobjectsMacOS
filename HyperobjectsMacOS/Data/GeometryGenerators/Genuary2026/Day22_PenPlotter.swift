//
//  Day22_PenPlotter.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 22/01/2026.
//

struct Day22_PenPlotter: GenuaryDayGenerator {
    let dayNumber = "22"

    func generateLines(
        inputs: [String: Any],
        scene: GeometriesSceneBase,
        time: Double,
        lineWidthBase: Float,
        state: Genuary2026State
    ) -> (lines: [Line], replacementProbability: Float) {
        var outputLines: [Line] = []
        
        
        let wanderer = traceCubeSurfacePath(
            startPoint: SIMD3<Float>(0.5, 0.0, 0.0),
            direction: SIMD3<Float>(0, 1, 0.3 + sin(Float(time * 0.005)) * 0.1),
            length: 100.0,
            cornerTurn: 0.01 + (sin(Float(time * 0.0022)) + 1.0) * 0.1,
            halfSize: 0.5,
            pointsPerUnit: 1.0
        )
        
        var wandererLines = pointsToRoundedLines(points: wanderer, radius: 0.1, lineWidth: lineWidthBase)
        let blackColor: SIMD4<Float> = SIMD4<Float>(0.0, 0.0, 0.0, 1.0)
        
        for i in wandererLines.indices {
            wandererLines[i] = wandererLines[i].setBasicEndPointColors(startColor: blackColor, endColor: blackColor)
        }
        
        let rotationX = matrix_rotation(angle: Float(time * 0.031), axis: SIMD3<Float>(1.0, 0.0, 0.0))
        let rotationY = matrix_rotation(angle: Float(time * 0.047), axis: SIMD3<Float>(0.0, 1.0, 0.0))
        let rotationZ = matrix_rotation(angle: Float(time * 0.023), axis: SIMD3<Float>(0.0, 0.0, 1.0))
        
        let totalRotation = rotationX * rotationY * rotationZ
        
        for i in wandererLines.indices {
            wandererLines[i] = wandererLines[i].applyMatrix(totalRotation)
        }
        
        outputLines.append(contentsOf: wandererLines)
        
        
        
        
        return (outputLines, 0.0) // default replacement probability
    }
    
    private func pointsToRoundedLines(points: [SIMD3<Float>], radius: Float, lineWidth: Float) -> [Line] {
        guard points.count >= 2 else { return [] }
        var lines: [Line] = []
        
        // Calculate cut distances
        var cuts: [Float] = Array(repeating: 0.0, count: points.count)
        
        for i in 1..<points.count-1 {
            let pPrev = points[i-1]
            let pCurr = points[i]
            let pNext = points[i+1]
            
            let vIn = pCurr - pPrev
            let vOut = pNext - pCurr
            
            let lenIn = length(vIn)
            let lenOut = length(vOut)
            
            if lenIn < 1e-4 || lenOut < 1e-4 {
                cuts[i] = 0
                continue
            }
            
            let nIn = vIn / lenIn
            let nOut = vOut / lenOut
            
            // Interior angle alpha is between -nIn and nOut
            // cosAlpha = dot(-nIn, nOut)
            let cosAlpha = dot(-nIn, nOut)
            
            var d: Float = 0.0
            if cosAlpha > 0.999 {
                d = 0.0
            } else if cosAlpha < -0.999 {
                d = 0.0
            } else {
                let valSq = (1.0 + cosAlpha) / (1.0 - cosAlpha)
                d = radius * sqrt(max(0, valSq))
            }
            
            d = min(d, lenIn * 0.45)
            d = min(d, lenOut * 0.45)
            
            cuts[i] = d
        }
        
        for i in 0..<points.count-1 {
            let pStart = points[i]
            let pEnd = points[i+1]
            let dist = length(pEnd - pStart)
            
            let cutStart = cuts[i]
            let cutEnd = cuts[i+1]
            
            if dist > cutStart + cutEnd {
                let v = normalize(pEnd - pStart)
                let actualStart = pStart + v * cutStart
                let actualEnd = pEnd - v * cutEnd
                
                lines.append(Line(startPoint: actualStart, endPoint: actualEnd, lineWidthStart: lineWidth, lineWidthEnd: lineWidth))
            }
            
            // Add curve for corner i+1
            if i < points.count - 2 {
                let radiusHere = cuts[i+1]
                if radiusHere > 1e-5 {
                    let center = points[i+1]
                    // previous segment (i) vector v = normalize(p[i+1] - p[i])
                    let vIn = normalize(points[i+1] - points[i])
                    let curveStart = center - vIn * radiusHere
                    
                    // next segment (i+1) vector vNext = normalize(points[i+2] - points[i+1])
                    let vNext = normalize(points[i+2] - points[i+1])
                    let curveEnd = center + vNext * radiusHere
                    
                    lines.append(Line(startPoint: curveStart, endPoint: curveEnd, degree: 2, controlPoints: [center], lineWidthStart: lineWidth, lineWidthEnd: lineWidth))
                }
            }
        }
        
        return lines
    }
}
