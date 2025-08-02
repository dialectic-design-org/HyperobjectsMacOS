//
//  TextDemoGenerator.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 02/08/2025.
//


import Foundation
import simd
import SwiftUICore

// private var originalText = "SOCRATISM VISUALS"
private var originalText = "SATISFACTION"
private var currentText = originalText
private var map: [Int: Character] = [:]

private func mutateString(
    original: String,
    current: String,
    pReplace: Double,
    pRestore: Double,
    replacementMap: inout [Int: Character]
) -> String {
    var mutated = Array(current)
    let originalArray = Array(original)
    
    for i in 0..<originalArray.count {
        let origChar = originalArray[i]
        let currChar = mutated[i]
        
        if replacementMap[i] != nil {
            // Already replaced
            if Double.random(in: 0...1) < pRestore {
                mutated[i] = origChar
                replacementMap.removeValue(forKey: i)
            }
        } else {
            // Not yet replaced
            if Double.random(in: 0...1) < pReplace {
                let newChar = randomCharacter(excluding: origChar)
                mutated[i] = newChar
                replacementMap[i] = newChar
            }
        }
    }
    
    return String(mutated)
}

private func randomCharacter(excluding excluded: Character) -> Character {
    let letters = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
    var candidate: Character
    repeat {
        candidate = letters.randomElement()!
    } while candidate == excluded
    return candidate
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
    
    override func generateGeometriesFromInputs(inputs: [String : Any]) -> [any Geometry] {
        
        let spacing = floatFromInputs(inputs, name: "Spacing")
        let replacementProbability = floatFromInputs(inputs, name: "Replacement probability")
        let restoreProbability = floatFromInputs(inputs, name: "Restore probability")
        
        var lines: [Line] = []
        
        
        currentText = mutateString(
                original: originalText,
                current: currentText,
                pReplace: Double(replacementProbability),
                pRestore: Double(restoreProbability),
                replacementMap: &map
            )
        
        
        let textLines = textToBezierPaths(currentText, font: .custom("SF Mono", size: 48), size: 0.4)
        
        let transformMatrix = matrix_translation(
            translation: SIMD3<Float>(
                -Float(originalText.count) * 0.25,
                 0.0,
                 0.0
            ))
        
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
                    controlPoints: line.controlPoints
                )
                transformedLine = transformedLine.applyMatrix(charTransform)
                lines.append(transformedLine)
            }
        }
        
        return lines
    }
}
