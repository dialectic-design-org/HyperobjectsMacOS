//
//  Day18_RuleLine.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 18/01/2026.
//


var ruleLineLatestPoint: SIMD3<Float> = .zero
var ruleLineOutputLines: [Line] = []
var currentZRotation: Float = 0.0

struct Day18_RuleLine: GenuaryDayGenerator {
    let dayNumber = "18"

    func generateLines(
        inputs: [String: Any],
        scene: GeometriesSceneBase,
        time: Double,
        lineWidthBase: Float,
        state: Genuary2026State
    ) -> (lines: [Line], replacementProbability: Float) {

        
        
        let brightnessInput = scene.getInputWithName(name: "Brightness")
        let brightnessInputValueNow = ensureValueIsFloat(brightnessInput.getHistoryValue(millisecondsAgo: 0.0))
        
        let distancePerTick: Float = 0.01
        
        
        let nextPoint: SIMD3<Float> = SIMD3<Float>(distancePerTick, 0.0, 0.0)
        
        let tMat = matrix_translation(translation: ruleLineLatestPoint)
        
        
        var  l = Line(
            startPoint: .zero,
            endPoint: nextPoint,
        )
        
        var nextColor: SIMD4<Float> = SIMD4<Float>(
            sin(Float(time * 5.45)) * 0.5 + 0.5 * 1.1,
            sin(Float(time * 5.45)) * 0.5 + 0.5 * 1.1,
            cos(Float(time * 5.45)) * 0.5 + 0.5 * 1.1,
            1.0
        )
        
        if ruleLineOutputLines.count > 1 {
            var lastColor = ruleLineOutputLines[ruleLineOutputLines.count - 1].colorEnd
            l = l.setBasicEndPointColors(startColor: lastColor, endColor: nextColor)
            l.lineWidthStart = ruleLineOutputLines[ruleLineOutputLines.count - 1].lineWidthEnd
            l.lineWidthEnd = lineWidthBase + lineWidthBase * brightnessInputValueNow * 25.0
        }
        
        
        
        
        
        
        
        currentZRotation += (brightnessInputValueNow - 0.5) * 0.2
        
        let rMatAudio = matrix_rotation(angle: currentZRotation, axis: SIMD3<Float>(0.0, 0.0, 1.0))
        let rMatAnimY = matrix_rotation(angle: Float(time * 0.15), axis: SIMD3<Float>(0.0, 1.0, 0.0))
        
        let rMatAnimZ = matrix_rotation(angle: Float(time * -0.05), axis: SIMD3<Float>(1.0, 0.0, 0.0))
        
        
        let rotationsCombined = rMatAnimZ * rMatAnimY * rMatAudio
        l = l.applyMatrix(rotationsCombined)
        l = l.applyMatrix(tMat)
        
        ruleLineLatestPoint = l.endPoint
        
        ruleLineOutputLines.append(l)

        // Cap number of output lines by removing the oldest ones
        let maxLines = 1000
        if ruleLineOutputLines.count > maxLines {
            ruleLineOutputLines.removeFirst(ruleLineOutputLines.count - maxLines)
        }

        // Create a copy of the lines and translate them based on last lines end point
        var finalOutputLines = ruleLineOutputLines
        
        if ruleLineOutputLines.count > 100 {
            // Calculate the average position of the last 100 lines
            var averagePosition: SIMD3<Float> = .zero
            let count = 100
            let startIndex = ruleLineOutputLines.count - count
            
            for i in 0..<count {
                averagePosition += ruleLineOutputLines[startIndex + i].endPoint
            }
            averagePosition /= Float(count)
            
            let centerTranslation = -averagePosition
            let centerMatrix = matrix_translation(translation: centerTranslation)
            
            for i in finalOutputLines.indices {
                finalOutputLines[i] = finalOutputLines[i].applyMatrix(centerMatrix)
            }
            
        }

        // Apply smoothing of line width along the whole path of finalOutputLines
        if finalOutputLines.count > 1 {
            var allWidths: [Float] = []
            allWidths.append(finalOutputLines.first!.lineWidthStart)
            for line in finalOutputLines {
                allWidths.append(line.lineWidthEnd)
            }
            
            var smoothedWidths: [Float] = []
            let smoothWindow = 20
            
            for i in 0..<allWidths.count {
                var sum: Float = 0
                var count: Int = 0
                for j in (i - smoothWindow / 2)...(i + smoothWindow / 2) {
                    if j >= 0 && j < allWidths.count {
                        sum += allWidths[j]
                        count += 1
                    }
                }
                smoothedWidths.append(sum / Float(count))
            }
            
            for i in finalOutputLines.indices {
                finalOutputLines[i].lineWidthStart = smoothedWidths[i]
                finalOutputLines[i].lineWidthEnd = smoothedWidths[i+1]
            }
        }
        
        return (finalOutputLines, brightnessInputValueNow - 0.3) // default replacement probability
    }
}
