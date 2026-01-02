//
//  Genuary2026Generator.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 01/01/2026.
//

import Foundation
import simd
import SwiftUI

private var currentTextMainTitle = "Genuary"
private var mapMainTitle: [Int: Character] = [:]

private var currentTextDay = "Day 2"
private var mapDay: [Int: Character] = [:]

private var currentTextYear = "2026"
private var mapYear: [Int: Character] = [:]

private var currentTextPrompt = "Ten principles of animation."
private var mapPrompt: [Int: Character] = [:]

private var currentTextCredit = "socratism.io"
private var mapCredit: [Int: Character] = [:]

private var replacementCharacters = "genuaryGENUARY2026"

private func mutateString(
    original: String,
    current: String,
    pReplace: Double,
    pRestore: Double,
    replacementMap: inout [Int: Character],
    replacementCharacters: String
) -> String {
    var mutated = Array(current)
    let originalArray = Array(original)
    
    // [HARDENING] Guard against length mismatches to prevent out-of-bounds.
    let limit = min(originalArray.count, mutated.count)  // <-- CHANGE
    
    // [HARDENING] If previous indices exist beyond the current safe bound, drop them.
    if !replacementMap.isEmpty {                          // <-- CHANGE
        replacementMap.keys
            .filter { $0 < 0 || $0 >= limit }
            .forEach { replacementMap.removeValue(forKey: $0) }
    }
    
    // Iterate only over the safe bound.
    for i in 0..<limit {                                   // <-- CHANGE (used limit)
        let origChar = originalArray[i]
        
        if replacementMap[i] != nil {
            // Already replaced
            if Double.random(in: 0...1) < pRestore {
                mutated[i] = origChar
                replacementMap.removeValue(forKey: i)
            }
        } else {
            // Not yet replaced
            if Double.random(in: 0...1) < pReplace {
                let newChar = randomCharacter(excluding: origChar, sampleSet: replacementCharacters)
                mutated[i] = newChar
                replacementMap[i] = newChar
            }
        }
    }
    
    // If original is longer than current (shouldn’t normally happen), leave tail as-is.
    // If current is longer than original, also untouched; rendering side already uses currentText’s glyphs.
    return String(mutated)
}

// [HARDENING] Eliminate force unwraps and infinite loop when sampleSet cannot differ from `excluded`.
private func randomCharacter(excluding excluded: Character, sampleSet: String = "$#%@*!+") -> Character {
    let letters = Array(sampleSet)
    
    // Prefer any character different from `excluded`
    let pool = letters.filter { $0 != excluded }
    
    if let pick = (pool.isEmpty ? letters.randomElement() : pool.randomElement()) {
        // If pool was empty and letters contained only `excluded`, we still return `excluded` here.
        // That keeps behavior stable while avoiding an infinite loop/crash.
        return pick
    }
    
    // Ultimate fallback if sampleSet is empty (shouldn’t happen, but safe).
    // Pick a deterministic distinct fallback if possible.
    if excluded != "?" { return "?" }
    if excluded != "!" { return "!" }
    return "#"  // last-resort fallback
}


class Genuary2026Generator: CachedGeometryGenerator {
    init() {
        super.init(name: "Genuary 2026 Generator", inputDependencies: [
            "Main title",
            "Year",
            "Prompt",
            "Line width base"
        ])
    }
    
    override func generateGeometriesFromInputs(inputs: [String : Any], withScene: GeometriesSceneBase) -> [any Geometry] {
        var lines: [Line] = []
        
        lines.append(
            Line(
                startPoint: SIMD3<Float>(-1000.0, 0.0, 0.0), endPoint: SIMD3<Float>(-1000.1, 0.0, 0.0)
            )
        )
        
        var mainFont = stringFromInputs(inputs, name: "Main font")
        var secondaryFont = stringFromInputs(inputs, name: "Secondary font")
        
        var dayNumber = stringFromInputs(inputs, name: "Day")
        var mainTitle = stringFromInputs(inputs, name: "Main title")
        var year = stringFromInputs(inputs, name: "Year")
        var prompt = stringFromInputs(inputs, name: "Prompt")
        var credit = stringFromInputs(inputs, name: "Credit")
        
        var width = floatFromInputs(inputs, name: "Width")
        var height = floatFromInputs(inputs, name: "Height")
        var depth = floatFromInputs(inputs, name: "Depth")
        
        var replacementProbability = floatFromInputs(inputs, name: "Replacement probability")
        let restoreProbability = floatFromInputs(inputs, name: "Restore probability")
        
        
        let lineWidthBase: Float = floatFromInputs(inputs, name: "Line width base")
        
        let mainFontSize: CGFloat = 0.075
        
        let leftAlignValue: Float = -0.8
        
        
        if dayNumber == "2" {
            replacementProbability = 0
        }
        
        
        
        
        
        let scaleMatrix = matrix_scale(scale: SIMD3<Float>(width, height, depth))
        
        // Time in milliseconds as float
        var timeAsFloat = Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 1000.0)
        
        let rotationMatrixX = matrix_rotation(angle: 0.0, axis: SIMD3<Float>(x: 1, y: 0, z: 0))
        var yAngle: Float = Float(timeAsFloat * 0.15)
        if dayNumber == "2" {
            yAngle = 0
        }
        let rotationMatrixY = matrix_rotation(angle: yAngle, axis: SIMD3<Float>(x: 0, y: 1, z: 0))
        let rotationMatrixZ = matrix_rotation(angle: 0.0, axis: SIMD3<Float>(x: 0, y: 0, z: 1))
        
        let translationMatrix = matrix_translation(translation: SIMD3<Float>(x: 0.0, y: 0.0, z: 0.0))
        

        let rotationMatrixXYZ = rotationMatrixX * rotationMatrixY * rotationMatrixZ
        
        
        var cubeLines = makeCube(size: 0.52, offset: 0)
        
        // func sigmoidFunction(input: Double, steepness: Double = 5.0, threshold: Double = 0.5, outputGain: Double = 1.0)

        if dayNumber == "2" {
            cubeLines = []
            var steepnessFactor = 1.5
            var animatedCubeLines: [Line] = []
            let topDistance:Float = -0.5 + Float(sigmoidFunction(input: 0.5 + sin(timeAsFloat) * 0.5, steepness: 10.0 * steepnessFactor)) * 0.95
            let bottomDistance:Float = 0.5 - Float(sigmoidFunction(input: 0.5 + sin(timeAsFloat * 1.35) * 0.5, steepness: 15.0 * steepnessFactor)) * 0.95
            let leftDistance:Float = -0.5 + Float(sigmoidFunction(input: 0.5 + cos(timeAsFloat * 0.5) * 0.5, steepness: 13.0 * steepnessFactor)) * 0.95
            let rightDistance:Float = 0.5 - Float(sigmoidFunction(input: 0.5 + cos(0.1 + timeAsFloat * 0.4) * 0.5, steepness: 20.0 * steepnessFactor)) * 0.95
            let frontDistance:Float = -0.5 + Float(sigmoidFunction(input: 0.5 + cos(timeAsFloat * 0.25) * 0.5, steepness: 12.0 * steepnessFactor)) * 1.0
            let backDistance:Float = 0.5 - Float(sigmoidFunction(input: 0.5 + cos(1.1 + timeAsFloat * 0.2) * 0.5, steepness: 10.0 * steepnessFactor)) * 1.5
            
            let delta:Double = 0.1
            let topDistance_plusT:Float = -0.5 + Float(sigmoidFunction(input: 0.5 + sin(timeAsFloat + delta) * 0.5, steepness: 10.0 * steepnessFactor)) * 0.95
            let bottomDistance_plusT:Float = 0.5 - Float(sigmoidFunction(input: 0.5 + sin(timeAsFloat * 1.35 + delta) * 0.5, steepness: 15.0 * steepnessFactor)) * 0.95
            let leftDistance_plusT:Float = -0.5 + Float(sigmoidFunction(input: 0.5 + cos(timeAsFloat * 0.5 + delta) * 0.5, steepness: 13.0 * steepnessFactor)) * 0.95
            let rightDistance_plusT:Float = 0.5 - Float(sigmoidFunction(input: 0.5 + cos(0.1 + timeAsFloat * 0.4 + delta) * 0.5, steepness: 20.0 * steepnessFactor)) * 0.95
            let frontDistance_plusT:Float = -0.5 + Float(sigmoidFunction(input: 0.5 + cos(timeAsFloat * 0.25 + delta) * 0.5, steepness: 12.0 * steepnessFactor)) * 1.0
            let backDistance_plusT:Float = 0.5 - Float(sigmoidFunction(input: 0.5 + cos(1.1 + timeAsFloat * 0.2 + delta) * 0.5, steepness: 10.0 * steepnessFactor)) * 1.5
            
            // Deltas
            let topDistanceDelta:Float = topDistance_plusT - topDistance
            let bottomDistanceDelta:Float = bottomDistance_plusT - bottomDistance
            let leftDistanceDelta:Float = leftDistance_plusT - leftDistance
            let rightDistanceDelta:Float = rightDistance_plusT - rightDistance
            let frontDistanceDelta:Float = frontDistance_plusT - frontDistance
            let backDistanceDelta:Float = backDistance_plusT - backDistance
            
            let allDeltas = [topDistanceDelta, bottomDistanceDelta, leftDistanceDelta, rightDistanceDelta, frontDistanceDelta, backDistanceDelta]
            let allDeltasAbsolute = allDeltas.map(\.magnitude)
            var allDeltasSum = allDeltasAbsolute.reduce(0, +)
            allDeltasSum = Float(sigmoidFunction(input: Double(allDeltasSum), steepness: 15.0))
            print(allDeltasSum)
            
            replacementProbability = allDeltasSum
            
            let topLeftFrontPoint = SIMD3<Float>(
                leftDistance,
                topDistance,
                frontDistance
            )
            let topRightFrontPoint = SIMD3<Float>(
                rightDistance,
                topDistance,
                frontDistance
            )
            let topRightBackPoint = SIMD3<Float>(
                rightDistance,
                topDistance,
                backDistance
            )
            let topLeftBackPoint = SIMD3<Float>(
                leftDistance,
                topDistance,
                backDistance
            )
            
            let bottomLeftFrontPoint = SIMD3<Float>(
                leftDistance,
                bottomDistance,
                frontDistance
            )
            let bottomRightFrontPoint = SIMD3<Float>(
                rightDistance,
                bottomDistance,
                frontDistance
            )
            let bottomRightBackPoint = SIMD3<Float>(
                rightDistance,
                bottomDistance,
                backDistance
            )
            let bottomLeftBackPoint = SIMD3<Float>(
                leftDistance,
                bottomDistance,
                backDistance
            )
            
            // Top
            animatedCubeLines.append(Line(
                startPoint: topLeftFrontPoint,
                endPoint: topRightFrontPoint
            ))
            animatedCubeLines.append(Line(
                startPoint: topRightFrontPoint,
                endPoint: topRightBackPoint
            ))
            animatedCubeLines.append(Line(
                startPoint: topRightBackPoint,
                endPoint: topLeftBackPoint
            ))
            animatedCubeLines.append(Line(
                startPoint: topLeftBackPoint,
                endPoint: topLeftFrontPoint
            ))
            
            // Bottom
            animatedCubeLines.append(Line(
                startPoint: bottomLeftFrontPoint,
                endPoint: bottomRightFrontPoint
            ))
            animatedCubeLines.append(Line(
                startPoint: bottomRightFrontPoint,
                endPoint: bottomRightBackPoint
            ))
            animatedCubeLines.append(Line(
                startPoint: bottomRightBackPoint,
                endPoint: bottomLeftBackPoint
                ))
            animatedCubeLines.append(Line(
                startPoint: bottomLeftBackPoint,
                endPoint: bottomLeftFrontPoint
            ))
            
            // Corners
            animatedCubeLines.append(Line(
                startPoint: topLeftFrontPoint,
                endPoint: bottomLeftFrontPoint
            ))
            animatedCubeLines.append(Line(
                startPoint: topRightFrontPoint,
                endPoint: bottomRightFrontPoint
            ))
            animatedCubeLines.append(Line(
                startPoint: topRightBackPoint,
                endPoint: bottomRightBackPoint
            ))
            animatedCubeLines.append(Line(
                startPoint: topLeftBackPoint,
                endPoint: bottomLeftBackPoint
            ))
            
            cubeLines = animatedCubeLines
            
        }
        
        
        var cubeColor = SIMD4<Float>(
            0.4,
            0.85,
            0.7,
            1.0
        )
        cubeColor = SIMD4<Float>(
            0.1,
            0.35,
            0.35,
            1.0
        )
        
        for line in cubeLines {
            var tLine = Line(
                startPoint: line.startPoint,
                endPoint: line.endPoint,
                degree: line.degree,
                controlPoints: line.controlPoints,
                lineWidthStart: lineWidthBase * 2,
                lineWidthEnd: lineWidthBase * 2
            )
            tLine = tLine.setBasicEndPointColors(startColor: cubeColor, endColor: cubeColor)
            
            if dayNumber == "1" {
                tLine = tLine.applyMatrix(scaleMatrix)
            } else if dayNumber == "2" {
                let scaling:Float = 1.1
                let day2ScaleMatrix = matrix_scale(scale: SIMD3<Float>(scaling, scaling, scaling))
                tLine = tLine.applyMatrix(day2ScaleMatrix)
            }
            
            
            tLine = tLine.applyMatrix(rotationMatrixXYZ)
            tLine = tLine.applyMatrix(translationMatrix)
            lines.append(tLine)
        }
        
        
    
        // TEXT
        
        let offWhite = SIMD4<Float>(0.9, 0.9, 0.9, 1.0)
        
        var textColor = SIMD4<Float>(
            1.0,
            1.0,
            1.0,
            1.0
        )
        
        
        currentTextMainTitle = mutateString(
            original: mainTitle,
            current: currentTextMainTitle,
            pReplace: Double(replacementProbability),
            pRestore: Double(restoreProbability),
            replacementMap: &mapMainTitle,
            replacementCharacters: replacementCharacters
        )
        
        currentTextDay = mutateString(
            original: "Day \(dayNumber)",
            current: currentTextDay,
            pReplace: Double(replacementProbability),
            pRestore: Double(restoreProbability),
            replacementMap: &mapDay,
            replacementCharacters: replacementCharacters
        )
        
        currentTextYear = mutateString(
            original: year,
            current: currentTextYear,
            pReplace: Double(replacementProbability),
            pRestore: Double(restoreProbability),
            replacementMap: &mapYear,
            replacementCharacters: replacementCharacters
        )
        
        currentTextPrompt = mutateString(
            original: prompt,
            current: currentTextPrompt,
            pReplace: Double(replacementProbability),
            pRestore: Double(restoreProbability),
            replacementMap: &mapPrompt,
            replacementCharacters: replacementCharacters
        )
        
        currentTextCredit = mutateString(
            original: credit,
            current: currentTextCredit,
            pReplace: Double(replacementProbability),
            pRestore: Double(restoreProbability),
            replacementMap: &mapCredit,
            replacementCharacters: replacementCharacters
        )
        
        
        
        // Main title
        let mainTitleLines = textToBezierPaths(currentTextMainTitle, font: .custom(mainFont, size: 48), fontName: mainFont, size: mainFontSize * 0.5, maxLineWidth: 10.0)
        
        let mainTitleTransform = matrix_translation(translation: SIMD3<Float>(
            leftAlignValue * 0.5,
            0.0 + 0.043,
            1.0
        ))
        
        for char in mainTitleLines {
            for line in char {
                var transformedLine = Line(
                    startPoint: line.startPoint,
                    endPoint: line.endPoint,
                    degree: line.degree,
                    controlPoints: line.controlPoints,
                    lineWidthStart: lineWidthBase,
                    lineWidthEnd: lineWidthBase
                )
                
                transformedLine = transformedLine.setBasicEndPointColors(startColor: textColor, endColor: textColor)
                transformedLine = transformedLine.applyMatrix(mainTitleTransform)
                
                lines.append(transformedLine)
            }
        }
        
        // Year
        let yearLines = textToBezierPaths(currentTextYear, font: .custom(mainFont, size: 48), fontName: mainFont, size: mainFontSize * 7.95, maxLineWidth: 10.0)
        
        let yearTransform = matrix_translation(translation: SIMD3<Float>(
            leftAlignValue - 0.441,
            -0.1  + 0.1,
            -0.5
        ))
        
        
        
        for char in yearLines {
            for line in char {
                var transformedLine = Line(
                    startPoint: line.startPoint,
                    endPoint: line.endPoint,
                    degree: line.degree,
                    controlPoints: line.controlPoints,
                    lineWidthStart: lineWidthBase,
                    lineWidthEnd: lineWidthBase
                )
                
                transformedLine = transformedLine.setBasicEndPointColors(startColor: offWhite, endColor: offWhite)
                transformedLine = transformedLine.applyMatrix(yearTransform)
                
                lines.append(transformedLine)
            }
        }
        
        // Day text
        
        let dayLines = textToBezierPaths(currentTextDay, font: .custom(mainFont, size: 48), fontName: mainFont, size: mainFontSize * 0.5, maxLineWidth: 10.0)
        
        let dayTransform = matrix_translation(translation: SIMD3<Float>(
            leftAlignValue * 0.5,
            -0.1  + 0.1,
            1.0
        ))
        
        for char in dayLines {
            for line in char {
                var transformedLine = Line(
                    startPoint: line.startPoint,
                    endPoint: line.endPoint,
                    degree: line.degree,
                    controlPoints: line.controlPoints,
                    lineWidthStart: lineWidthBase,
                    lineWidthEnd: lineWidthBase
                )
                
                transformedLine = transformedLine.setBasicEndPointColors(startColor: textColor, endColor: textColor)
                transformedLine = transformedLine.applyMatrix(dayTransform)
                
                lines.append(transformedLine)
            }
        }
        
        
        // Prompt text
        
        let promptLines = textToBezierPaths(currentTextPrompt, font: .custom(secondaryFont, size: 48), fontName: secondaryFont, size: mainFontSize * 0.25, maxLineWidth: 10.0)
        
        let promptTransform = matrix_translation(translation: SIMD3<Float>(
            leftAlignValue * 0.5,
            -0.1,
            1.0
        ))
        
        for char in promptLines {
            for line in char {
                var transformedLine = Line(
                    startPoint: line.startPoint,
                    endPoint: line.endPoint,
                    degree: line.degree,
                    controlPoints: line.controlPoints,
                    lineWidthStart: lineWidthBase * 0.5,
                    lineWidthEnd: lineWidthBase * 0.5
                )
                
                transformedLine = transformedLine.setBasicEndPointColors(startColor: textColor, endColor: textColor)
                transformedLine = transformedLine.applyMatrix(promptTransform)
                
                lines.append(transformedLine)
            }
        }
        
        // Credit text
        
        let creditLines = textToBezierPaths(currentTextCredit, font: .custom(secondaryFont, size: 48), fontName: secondaryFont, size: mainFontSize * 0.25, maxLineWidth: 10.0)
        
        let creditTransform = matrix_translation(translation: SIMD3<Float>(
            0.25,
            -0.1,
            1.0
        ))
        
        for char in creditLines {
            for line in char {
                var transformedLine = Line(
                    startPoint: line.startPoint,
                    endPoint: line.endPoint,
                    degree: line.degree,
                    controlPoints: line.controlPoints,
                    lineWidthStart: lineWidthBase * 0.5,
                    lineWidthEnd: lineWidthBase * 0.5
                )
                
                transformedLine = transformedLine.setBasicEndPointColors(startColor: textColor, endColor: textColor)
                transformedLine = transformedLine.applyMatrix(creditTransform)
                
                lines.append(transformedLine)
            }
        }
        
        
        
        return lines
    }
}



