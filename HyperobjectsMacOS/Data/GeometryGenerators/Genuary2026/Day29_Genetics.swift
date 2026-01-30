//
//  Day29_Genetics.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 27/01/2026.
//

import Foundation
import simd
import SwiftUI

struct HelixSection {
    var center: SIMD3<Float>
    var direction: SIMD3<Float>
    var radius: Float
    var angleStart: Float
    var angleEnd: Float
    var height: Float // Length of this segment
    var thickness: Float
    var basePairGap: Float // Distance between rungs
    var twistRate: Float // Radians per unit height
    
    func generateBasePairs() -> [(sideA: SIMD3<Float>, sideB: SIMD3<Float>, label: String)] {
        var pairs: [(SIMD3<Float>, SIMD3<Float>, String)] = []
        let count = Int(height / basePairGap)
        
        // Simple basis construction
        let arbitrary = (abs(direction.z) < 0.999) ? SIMD3<Float>(0, 0, 1) : SIMD3<Float>(1, 0, 0)
        let tangent = normalize(cross(direction, arbitrary))
        let bitangent = normalize(cross(direction, tangent))
        
        let bases = ["A-T", "T-A", "G-C", "C-G"]
        
        for i in 0..<count {
            let h = Float(i) * basePairGap
            let angle = angleStart + h * twistRate
            
            // Rotation in the plane defined by tangent/bitangent
            let offsetDir = tangent * cos(angle) + bitangent * sin(angle)
            let centerPos = center + direction * h
            
            let p1 = centerPos + offsetDir * radius
            let p2 = centerPos - offsetDir * radius
            
            // Deterministic pseudo-random choice based on index to be stable
            let pairIndex = (i * 7 + 3) % bases.count
            pairs.append((p1, p2, bases[pairIndex]))
        }
        return pairs
    }
}

struct Day29_Genetics: GenuaryDayGenerator {
    let dayNumber = "29"

    func generateLines(
        inputs: [String: Any],
        scene: GeometriesSceneBase,
        time: Double,
        lineWidthBase: Float,
        state: Genuary2026State
    ) -> (lines: [Line], replacementProbability: Float) {
        var outputLines: [Line] = []
        
        
        var brightness = scene.getInputWithName(name: "Brightness")
        
        let gap: Float = 0.34
        // Twist of ~36 degrees per base pair (approx 10.5 bp per turn)
        let twistPerHeight = (36.0 * Float.pi / 180.0) / gap
        
        let helix = HelixSection(
            center: SIMD3<Float>(0, 0, 0),
            direction: SIMD3<Float>(0, 1, 0),
            radius: 0.6,
            angleStart: Float(time) * 0.2,
            angleEnd: 0,
            height: gap * 14.1, // Ensure 5 items
            thickness: 0.1,
            basePairGap: gap,
            twistRate: twistPerHeight
        )
        
        var finalOffset = matrix_translation(translation: SIMD3<Float>(0.0, -helix.height * 0.43, 0.0))
        var finalRotateZ = matrix_rotation(angle: 0.3, axis: SIMD3<Float>(0.0, 0.0, 1.0))
        var finalRotateZTime = matrix_rotation(angle: Float(time * 0.012), axis: SIMD3<Float>(0.0, 0.0, 1.0))
        var finalRotateXTime = matrix_rotation(angle: Float(time * 0.05), axis: SIMD3<Float>(1.0, 0.0, 0.0))
        var finalRotateZBefore = matrix_rotation(angle: 0.3, axis: SIMD3<Float>(0.0, 0.0, 1.0))
        var finalRotateY = matrix_rotation(angle: Float(time * 0.1), axis: SIMD3<Float>(0.0, 1.0, 0.0))
        var finalMat = finalRotateZ * finalRotateZTime * finalRotateXTime * finalRotateY * finalRotateZBefore * finalOffset
        
        let rawPairs = helix.generateBasePairs()
        
        // Text Geometry Cache
        let fontName = (inputs["Main font"] as? String) ?? "SF Mono Heavy"
        let letterSize: CGFloat = 0.1
        let alphabetString = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let baseLetters = alphabetString.map { String($0) }
        var letterCache: [String: [Line]] = [:]
        
        for letter in baseLetters {
            let letterLinesGroup = textToBezierPaths(letter, font: .custom(fontName, size: 20), fontName: fontName, size: letterSize, maxLineWidth: 10.0)
            letterCache[letter] = letterLinesGroup.flatMap { $0 }
        }

        let backboneOffsetFactor: Float = 0.1
        let backboneExtensionFactor: Float = 0.1
        let sideOffsetFactor: Float = 0.2
        
        // Apply geometry effects (Pulse + Rotate) to raw pairs first, then transform to world space
        let pulsedPairs = rawPairs.enumerated().map { (i, pair) -> (sideA: SIMD3<Float>, sideB: SIMD3<Float>, type: String) in
            var (sideA, sideB, type) = pair
            
            let t = Double(i) / Double(rawPairs.count)
            let t_inv = 1.0 - t
            
            // Extension (Pulse)
            let brightnessExtend = ensureValueIsFloat(brightness.getHistoryValue(millisecondsAgo: t * 340)) * 2
            let brightnessExtendInv = ensureValueIsFloat(brightness.getHistoryValue(millisecondsAgo: t_inv * 500)) * 2
            
            // Standard pulse logic from previous step
            let brightnessExtendTwo = ensureValueIsFloat(brightness.getHistoryValue(millisecondsAgo: t * 100))
            let brightnessExtendInvTwo = ensureValueIsFloat(brightness.getHistoryValue(millisecondsAgo: t_inv * 80))
            
            let rungCenter = (sideA + sideB) * 0.5
            let scaleFactor = (1 + (brightnessExtend + brightnessExtendInv + brightnessExtendTwo + brightnessExtendInvTwo) * 0.05)
            
            sideA = rungCenter + (sideA - rungCenter) * scaleFactor
            sideB = rungCenter + (sideB - rungCenter) * scaleFactor
            
            // Rotation (Twist) - Offset timing
            // Using slightly different timing factor (0.9 vs 1.0) and offset (50ms) to desync
            let brightnessRotate = ensureValueIsFloat(brightness.getHistoryValue(millisecondsAgo: t * 200 + 50.0))
            let brightnessRotateInv = ensureValueIsFloat(brightness.getHistoryValue(millisecondsAgo: t_inv * 400 + 0.0))
            let twistAngle = brightnessRotate * 0.1 + brightnessRotateInv * 0.1 // Add extra twist based on loudness
            
            let rotation = matrix_rotation(angle: twistAngle, axis: SIMD3<Float>(0, 1, 0))
            
            let vA_rot = simd_mul(rotation, simd_float4(sideA, 1.0))
            let vB_rot = simd_mul(rotation, simd_float4(sideB, 1.0))
            
            let vA = simd_mul(finalMat, vA_rot)
            let vB = simd_mul(finalMat, vB_rot)
            
            return (sideA: SIMD3<Float>(vA.x, vA.y, vA.z), sideB: SIMD3<Float>(vB.x, vB.y, vB.z), type: type)
        }
        
        for (i, pair) in pulsedPairs.enumerated() {
            let (sideA, sideB, type) = pair
            
            // Color logic
            let waveSpeed = 0.5
            let colorPhase = Float(time * waveSpeed) + Float(i) * 0.15
            
            // Generate two slightly different colors for the two sides to create asymmetry
            // Side A: Base phase
            let t = Double(i) / Double(pulsedPairs.count)
            let brightnessFastA = ensureValueIsFloat(brightness.getHistoryValue(millisecondsAgo: t * 100))
            // Center hue 300 (Magenta) +/- 70 sweeps from 230 (Blue) to 370/10 (Red)
            let hueA = 300.0 + sin(colorPhase) * 70.0
            
            // Tune for forceful dips to black (lightness ~0) and high peaks (lightness ~0.9)
            let chromaA = 0.02 + brightnessFastA * 0.35
            let lightnessA = 0.02 + brightnessFastA * 0.9
            let waveColorA = OKLCH(L: lightnessA, C: chromaA, H: hueA).simd
            
            // Side B: Phase offset + Time inversion for brightness lookup (asymmetric pulsing)
            let t_inv = 1.0 - t
            let brightnessFastB = ensureValueIsFloat(brightness.getHistoryValue(millisecondsAgo: t_inv * 100))
            let hueB = 300.0 + sin(colorPhase + Float.pi * 0.5) * 70.0
            
            let chromaB = 0.02 + brightnessFastB * 0.35
            let lightnessB = 0.02 + brightnessFastB * 0.9
            let waveColorB = OKLCH(L: lightnessB, C: chromaB, H: hueB).simd
            
            // Rungs
            let vec = sideB - sideA
            let letterStart = sideA + SIMD3<Float>(-Float(letterSize) * 0.3, -Float(letterSize) * 0.3, 0.0)
            let letterEnd = sideB + SIMD3<Float>(-Float(letterSize) * 0.3, -Float(letterSize) * 0.3, 0.0)
            let pStart = sideA + vec * backboneOffsetFactor
            let pEnd = sideA + vec * (1.0 - backboneOffsetFactor)
            
            var line = Line(startPoint: pStart, endPoint: pEnd)
            line.lineWidthStart = lineWidthBase
            line.lineWidthEnd = lineWidthBase
            line.colorStart = waveColorA
            line.colorEnd = waveColorB
            
            outputLines.append(line)
            
            // Extensions
            let extLeftStart = sideA - vec * (backboneOffsetFactor + backboneExtensionFactor)
            let extLeftEnd = sideA - vec * backboneOffsetFactor
            var leftExt = Line(startPoint: extLeftStart, endPoint: extLeftEnd)
            leftExt.lineWidthStart = lineWidthBase
            leftExt.lineWidthEnd = lineWidthBase
            leftExt.colorStart = waveColorA
            leftExt.colorEnd = waveColorA
            outputLines.append(leftExt)
            
            let extRightStart = sideB + vec * backboneOffsetFactor
            let extRightEnd = sideB + vec * (backboneOffsetFactor + backboneExtensionFactor)
            var rightExt = Line(startPoint: extRightStart, endPoint: extRightEnd)
            rightExt.lineWidthStart = lineWidthBase
            rightExt.lineWidthEnd = lineWidthBase
            rightExt.colorStart = waveColorB
            rightExt.colorEnd = waveColorB
            outputLines.append(rightExt)
            
            // Letters
            var charA = String(type.prefix(1))
            var charB = String(type.suffix(1))
            
            // Mutation Logic: Delayed brightness triggers random character replacement
            let mutationDelay: Double = 200.0
            let brightnessMutation = ensureValueIsFloat(brightness.getHistoryValue(millisecondsAgo: t * 200 + mutationDelay))
            // Probability increases with brightness (threshold 0.4)
            let mutationProb = max(0.0, (brightnessMutation - 0.4) * 4.0)
            
            if Float.random(in: 0...1) < mutationProb {
                charA = String(alphabetString.randomElement()!)
            }
            if Float.random(in: 0...1) < mutationProb {
                charB = String(alphabetString.randomElement()!)
            }
            
            // Extra brightness for letters for readability
            let letterColA = OKLCH(L: min(1.0, lightnessA + 0.45), C: chromaA * 0.5, H: hueA).simd
            let letterColB = OKLCH(L: min(1.0, lightnessB + 0.45), C: chromaB * 0.5, H: hueB).simd
            
            if let linesA = letterCache[charA] {
                let mat = matrix_translation(translation: letterStart)
                for l in linesA {
                   var mutableL = l
                   var newLine = mutableL.applyMatrix(mat)
                   newLine.lineWidthStart = lineWidthBase * 0.5
                   newLine.lineWidthEnd = lineWidthBase * 0.5
                   newLine.colorStart = letterColA
                   newLine.colorEnd = letterColA
                   outputLines.append(newLine)
                }
            }
            if let linesB = letterCache[charB] {
                 let mat = matrix_translation(translation: letterEnd)
                 for l in linesB {
                   var mutableL = l
                   var newLine = mutableL.applyMatrix(mat)
                   newLine.lineWidthStart = lineWidthBase * 0.5
                   newLine.lineWidthEnd = lineWidthBase * 0.5
                   newLine.colorStart = letterColB
                   newLine.colorEnd = letterColB
                   outputLines.append(newLine)
                }
            }
            
            // Sides
            if i < pulsedPairs.count - 1 {
                let next = pulsedPairs[i+1]
                
                // Calculate next colors for gradients on legs
                let nextI = i + 1
                let nextT = Double(nextI) / Double(pulsedPairs.count)
                let nextColorPhase = Float(time * waveSpeed) + Float(nextI) * 0.15
                
                // Side A Next
                let nextBrightnessFastA = ensureValueIsFloat(brightness.getHistoryValue(millisecondsAgo: nextT * 100))
                let nextHueA = 300.0 + sin(nextColorPhase) * 70.0
                let nextChromaA = 0.02 + nextBrightnessFastA * 0.35
                let nextLightnessA = 0.02 + nextBrightnessFastA * 0.9
                let nextWaveColorA = OKLCH(L: nextLightnessA, C: nextChromaA, H: nextHueA).simd

                // Side B Next
                let nextTInv = 1.0 - nextT
                let nextBrightnessFastB = ensureValueIsFloat(brightness.getHistoryValue(millisecondsAgo: nextTInv * 100))
                let nextHueB = 300.0 + sin(nextColorPhase + Float.pi * 0.5) * 70.0
                let nextChromaB = 0.02 + nextBrightnessFastB * 0.35
                let nextLightnessB = 0.02 + nextBrightnessFastB * 0.9
                let nextWaveColorB = OKLCH(L: nextLightnessB, C: nextChromaB, H: nextHueB).simd
                
                // Side A
                let vecA = next.sideA - sideA
                let legStartA = sideA + vecA * sideOffsetFactor
                let legEndA = next.sideA - vecA * sideOffsetFactor
                
                var legA = Line(startPoint: legStartA, endPoint: legEndA)
                legA.lineWidthStart = lineWidthBase
                legA.lineWidthEnd = lineWidthBase
                legA.colorStart = waveColorA
                legA.colorEnd = nextWaveColorA
                outputLines.append(legA)
                
                // Side B
                let vecB = next.sideB - sideB
                let legStartB = sideB + vecB * sideOffsetFactor
                let legEndB = next.sideB - vecB * sideOffsetFactor
                
                var legB = Line(startPoint: legStartB, endPoint: legEndB)
                legB.lineWidthStart = lineWidthBase
                legB.lineWidthEnd = lineWidthBase
                legB.colorStart = waveColorB
                legB.colorEnd = nextWaveColorB
                outputLines.append(legB)
            }
        }
        
        var totalSizing = matrix_scale(scale: SIMD3<Float>(repeating: 0.4))
        
        for i in outputLines.indices {
            outputLines[i] = outputLines[i].applyMatrix(totalSizing)
        }
        
        return (outputLines, ensureValueIsFloat(brightness.getHistoryValue(millisecondsAgo: 0.0)) * 0.5) // default replacement probability
    }
}
