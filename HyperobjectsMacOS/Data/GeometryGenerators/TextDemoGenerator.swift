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
        // let currChar = mutated[i]
        
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
    // let letters = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
    let letters = Array("$#%@*!+")
    // let letters = Array("پ")
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
        var inputString = stringFromInputs(inputs, name: "Title text")
        
        let statefulRotationX = floatFromInputs(inputs, name: "Stateful Rotation X")
        let statefulRotationY = floatFromInputs(inputs, name: "Stateful Rotation Y")
        let statefulRotationZ = floatFromInputs(inputs, name: "Stateful Rotation Z")
        
        
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
                replacementMap: &map
            )
        
        
        let textLines = textToBezierPaths(currentText, font: .custom("SF Mono", size: 48), size: 0.4, maxLineWidth: 5.0)
        
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
                    controlPoints: line.controlPoints
                )
                transformedLine = transformedLine.applyMatrix(charTransform)
                transformedLine = transformedLine.applyMatrix(rotationMatrixXYZ)
                lines.append(transformedLine)
            }
        }
        
        return lines
    }
}
