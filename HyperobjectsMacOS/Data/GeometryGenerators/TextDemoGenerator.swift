//
//  TextDemoGenerator.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 02/08/2025.
//

import Foundation
import simd
import SwiftUI

// private var originalText = "SOCRATISM VISUALS"
private var originalText = "SATISFACTION"
private var currentText = originalText
private var map: [Int: Character] = [:]

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

class TextDemoGenerator: CachedGeometryGenerator {
    init() {
        super.init(name: "Text Demo Generator",
                   inputDependencies: [
                    "Start color",
                    "End color",
                    "Spacing"
                   ])
    }
    
    override func generateGeometriesFromInputs(inputs: [String : Any], withScene: GeometriesSceneBase) -> [any Geometry] {
        
        let spacing = floatFromInputs(inputs, name: "Spacing")
        let replacementProbability = floatFromInputs(inputs, name: "Replacement probability")
        let restoreProbability = floatFromInputs(inputs, name: "Restore probability")
        var inputString = stringFromInputs(inputs, name: "Title text")
        var replacementCharacters = stringFromInputs(inputs, name: "Replacement characters")
        
        // Keep original intent: if empty, use a space.
        if replacementCharacters.count == 0 {
            replacementCharacters = " "
        }
        
        let statefulRotationX = floatFromInputs(inputs, name: "Stateful Rotation X")
        let statefulRotationY = floatFromInputs(inputs, name: "Stateful Rotation Y")
        let statefulRotationZ = floatFromInputs(inputs, name: "Stateful Rotation Z")
        
        let lineWidthBase = floatFromInputs(inputs, name: "Line width base")
        
        let startColor = colorFromInputs(inputs, name: "Start color")
        let endColor = colorFromInputs(inputs, name: "End color")
        
        let colorScale = ColorScale(colors: [startColor, endColor], mode: .hsl)
        
        if inputString == "" {
            // inputString = "PLACEHOLDER"
        }
        if originalText != inputString {
            originalText = inputString
            currentText = inputString
            map.removeAll()
        }
        
        var lines: [Line] = []
        
        // Line to protect against returning a 0 array
        lines.append(
            Line(
                startPoint: SIMD3<Float>(-1000.0, 0.0, 0.0), endPoint: SIMD3<Float>(-1000.1, 0.0, 0.0)
            )
        )
        
        currentText = mutateString(
            original: originalText,
            current: currentText,
            pReplace: Double(replacementProbability),
            pRestore: Double(restoreProbability),
            replacementMap: &map,
            replacementCharacters: replacementCharacters
        )
        
        let textLines = textToBezierPaths(currentText, font: .custom("SF Mono", size: 48), size: 0.4, maxLineWidth: 10.0)
        
        var transformMatrix = matrix_translation(
            translation: SIMD3<Float>(
                -Float(originalText.count) * 0.25,
                 0.0,
                 0.0
            ))
        
        let rotationMatrixX = matrix_rotation(angle: statefulRotationX, axis: SIMD3<Float>(x: 1, y: 0, z: 0))
        let rotationMatrixY = matrix_rotation(angle: statefulRotationY, axis: SIMD3<Float>(x: 0, y: 1, z: 0))
        let rotationMatrixZ = matrix_rotation(angle: statefulRotationZ, axis: SIMD3<Float>(x: 0, y: 0, z: 1))

        let rotationMatrixXYZ = rotationMatrixX * rotationMatrixY * rotationMatrixZ
        
        var charIndex = 0
        var charT = 0.0
        for char in textLines {
            charIndex += 1
            charT = Double(charIndex) / Double(textLines.count)
            
            let charTransform = transformMatrix + matrix_translation(
                translation: SIMD3<Float>(Float((charT - 0.5) * 2.0) * spacing, 0.0, 0.0))
            for line in char {
                var transformedLine = Line(
                    startPoint: line.startPoint,
                    endPoint: line.endPoint,
                    degree: line.degree,
                    controlPoints: line.controlPoints,
                    lineWidthStart: lineWidthBase,
                    lineWidthEnd: lineWidthBase
                )
                transformedLine = transformedLine.setBasicEndPointColors(
                    startColor: colorScale.color(at: Double(charT)).toSIMD4(),
                    endColor: colorScale.color(at: Double(charT)).toSIMD4()
                )
                transformedLine = transformedLine.applyMatrix(charTransform)
                transformedLine = transformedLine.applyMatrix(rotationMatrixXYZ)
                lines.append(transformedLine)
            }
        }
        
        return lines
    }
}
