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

private var currentTextDay = "Day 5"
private var mapDay: [Int: Character] = [:]

private var currentTextYear = "2026"
private var mapYear: [Int: Character] = [:]

private var currentTextPrompt = "No font."
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
    
    override func generateGeometriesFromInputs(inputs: [String : Any], withScene scene: GeometriesSceneBase) -> [any Geometry] {
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
        

        let widthInput = scene.getInputWithName(name: "Width")
        let heightInput = scene.getInputWithName(name: "Height")
        let depthInput = scene.getInputWithName(name: "Depth")
        
        let brightnessInput = scene.getInputWithName(name: "Brightness")
        
        
        
        
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
        
        
        var outputLines:[Line] = []
        
        // func sigmoidFunction(input: Double, steepness: Double = 5.0, threshold: Double = 0.5, outputGain: Double = 1.0)
        
        
        if dayNumber == "1" {
            outputLines = makeCube(size: 0.52, offset: 0)
        } else if dayNumber == "2" {
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
            
            outputLines = animatedCubeLines
            
        } else if dayNumber == "3" {
            // replacementProbability = 0.0
            
            var totalCubes = 12
            
            var squares: [[SIMD2<Double>]] = fibonacciSquares(count: totalCubes, firstSquareSize: 0.008)
            
            // Get max bounds from the squares to center them
            var minX: Double = Double.greatestFiniteMagnitude
            var maxX: Double = -Double.greatestFiniteMagnitude
            var minY: Double = Double.greatestFiniteMagnitude
            var maxY: Double = -Double.greatestFiniteMagnitude

            for square in squares {
                for point in square {
                    if point.x < minX {
                        minX = point.x
                    }
                    if point.x > maxX {
                        maxX = point.x
                    }
                    if point.y < minY {
                        minY = point.y
                    }
                    if point.y > maxY {
                        maxY = point.y
                    }
                }
            }
            let centerX = (minX + maxX) / 2.0
            let centerY = (minY + maxY) / 2.0

            // Center the squares around (0,0)
            for i in 0..<squares.count {
                for j in 0..<squares[i].count {
                    squares[i][j].x -= centerX
                    squares[i][j].y -= centerY
                }
            }

            // Convert to 3d cubes with depth 0.1
            let depth: Double = 0.1

            var cubes: [[SIMD3<Double>]] = []
            struct CubeCorners {
                let top: [SIMD3<Double>]
                let bottom: [SIMD3<Double>]
            }
            
            var cubeStructs: [CubeCorners] = []

            for square in squares {
                var topPoints: [SIMD3<Double>] = []
                var bottomPoints: [SIMD3<Double>] = []
                
                for point in square {
                    // Create top face at +depth/2
                    let topPoint = SIMD3<Double>(point.x, point.y, depth / 2.0)
                    topPoints.append(topPoint)
                    
                    // Create bottom face at -depth/2
                    let bottomPoint = SIMD3<Double>(point.x, point.y, -depth / 2.0)
                    bottomPoints.append(bottomPoint)
                }
                
                cubeStructs.append(CubeCorners(top: topPoints, bottom: bottomPoints))
            }

            func createCrossOnPoint(point: SIMD3<Double>) -> [Line] {
                var crossLines: [Line] = []
                
                let size: Double = Double(ensureValueIsFloat(depthInput.getHistoryValue(millisecondsAgo: 0.0))) * 1.0
                
                let horizontalLine = Line(
                    startPoint: SIMD3<Float>(
                        Float(point.x - size),
                        Float(point.y),
                        Float(point.z)
                    ),
                    endPoint: SIMD3<Float>(
                        Float(point.x + size),
                        Float(point.y),
                        Float(point.z)
                    )
                )
                
                let verticalLine = Line(
                    startPoint: SIMD3<Float>(
                        Float(point.x),
                        Float(point.y - size),
                        Float(point.z)
                    ),
                    endPoint: SIMD3<Float>(
                        Float(point.x),
                        Float(point.y + size),
                        Float(point.z)
                    )
                )

                let depthLine = Line(
                    startPoint: SIMD3<Float>(
                        Float(point.x),
                        Float(point.y),
                        Float(point.z - size)
                    ),
                    endPoint: SIMD3<Float>(
                        Float(point.x),
                        Float(point.y),
                        Float(point.z + size)
                    )
                )
                
                crossLines.append(horizontalLine)
                crossLines.append(verticalLine)
                crossLines.append(depthLine)
                
                return crossLines
            }
            var cubeNr = 0
            for cube in cubeStructs {
                
                var crossLines: [Line] = []
                for p in cube.top {
                    crossLines.append(contentsOf: createCrossOnPoint(point: p))
                }
                for p in cube.bottom {
                    crossLines.append(contentsOf: createCrossOnPoint(point: p))
                }
                
                

                var cubeInset = 0.005
                var cubeLines: [Line] = []
                // Top face
                cubeLines.append(Line(
                    startPoint: SIMD3<Float>(
                        Float(cube.top[0].x + cubeInset),
                        Float(cube.top[0].y + cubeInset),
                        Float(cube.top[0].z)
                    ),
                    endPoint: SIMD3<Float>(
                        Float(cube.top[1].x - cubeInset),
                        Float(cube.top[1].y + cubeInset),
                        Float(cube.top[1].z)
                    )
                ))
                cubeLines.append(Line(
                    startPoint: SIMD3<Float>(
                        Float(cube.top[1].x - cubeInset),
                        Float(cube.top[1].y + cubeInset),
                        Float(cube.top[1].z)
                    ),
                    endPoint: SIMD3<Float>(
                        Float(cube.top[2].x - cubeInset),
                        Float(cube.top[2].y - cubeInset),
                        Float(cube.top[2].z)
                    )
                ))
                cubeLines.append(Line(
                    startPoint: SIMD3<Float>(
                        Float(cube.top[2].x - cubeInset),
                        Float(cube.top[2].y - cubeInset),
                        Float(cube.top[2].z)
                    ),
                    endPoint: SIMD3<Float>(
                        Float(cube.top[3].x + cubeInset),
                        Float(cube.top[3].y - cubeInset),
                        Float(cube.top[3].z)
                    )
                ))
                cubeLines.append(Line(
                    startPoint: SIMD3<Float>(
                        Float(cube.top[3].x + cubeInset),
                        Float(cube.top[3].y - cubeInset),
                        Float(cube.top[3].z)
                    ),
                    endPoint: SIMD3<Float>(
                        Float(cube.top[0].x + cubeInset),
                        Float(cube.top[0].y + cubeInset),
                        Float(cube.top[0].z)
                    )
                ))

                // Bottom face
                cubeLines.append(Line(
                    startPoint: SIMD3<Float>(
                        Float(cube.bottom[0].x + cubeInset),
                        Float(cube.bottom[0].y + cubeInset),
                        Float(cube.bottom[0].z)
                    ),
                    endPoint: SIMD3<Float>(
                        Float(cube.bottom[1].x - cubeInset),
                        Float(cube.bottom[1].y + cubeInset),
                        Float(cube.bottom[1].z)
                    )
                ))
                cubeLines.append(Line(
                    startPoint: SIMD3<Float>(
                        Float(cube.bottom[1].x - cubeInset),
                        Float(cube.bottom[1].y + cubeInset),
                        Float(cube.bottom[1].z)
                    ),
                    endPoint: SIMD3<Float>(
                        Float(cube.bottom[2].x - cubeInset),
                        Float(cube.bottom[2].y - cubeInset),
                        Float(cube.bottom[2].z)
                    )
                ))
                cubeLines.append(Line(
                    startPoint: SIMD3<Float>(
                        Float(cube.bottom[2].x - cubeInset),
                        Float(cube.bottom[2].y - cubeInset),
                        Float(cube.bottom[2].z)
                    ),
                    endPoint: SIMD3<Float>(
                        Float(cube.bottom[3].x + cubeInset),
                        Float(cube.bottom[3].y - cubeInset),
                        Float(cube.bottom[3].z)
                    )
                ))
                cubeLines.append(Line(
                    startPoint: SIMD3<Float>(
                        Float(cube.bottom[3].x + cubeInset),
                        Float(cube.bottom[3].y - cubeInset),
                        Float(cube.bottom[3].z)
                    ),
                    endPoint: SIMD3<Float>(
                        Float(cube.bottom[0].x + cubeInset),
                        Float(cube.bottom[0].y + cubeInset),
                        Float(cube.bottom[0].z)
                    )
                ))
                
                // Between lines
                // Vertical lines connecting top and bottom faces
                // 0: Top-Left (relative to square logic)
                cubeLines.append(Line(
                    startPoint: SIMD3<Float>(
                        Float(cube.top[0].x + cubeInset),
                        Float(cube.top[0].y + cubeInset),
                        Float(cube.top[0].z)
                    ),
                    endPoint: SIMD3<Float>(
                        Float(cube.bottom[0].x + cubeInset),
                        Float(cube.bottom[0].y + cubeInset),
                        Float(cube.bottom[0].z)
                    )
                ))
                
                // 1: Top-Right
                cubeLines.append(Line(
                    startPoint: SIMD3<Float>(
                        Float(cube.top[1].x - cubeInset),
                        Float(cube.top[1].y + cubeInset),
                        Float(cube.top[1].z)
                    ),
                    endPoint: SIMD3<Float>(
                        Float(cube.bottom[1].x - cubeInset),
                        Float(cube.bottom[1].y + cubeInset),
                        Float(cube.bottom[1].z)
                    )
                ))
                
                // 2: Bottom-Right
                cubeLines.append(Line(
                    startPoint: SIMD3<Float>(
                        Float(cube.top[2].x - cubeInset),
                        Float(cube.top[2].y - cubeInset),
                        Float(cube.top[2].z)
                    ),
                    endPoint: SIMD3<Float>(
                        Float(cube.bottom[2].x - cubeInset),
                        Float(cube.bottom[2].y - cubeInset),
                        Float(cube.bottom[2].z)
                    )
                ))
                
                // 3: Bottom-Left
                cubeLines.append(Line(
                    startPoint: SIMD3<Float>(
                        Float(cube.top[3].x + cubeInset),
                        Float(cube.top[3].y - cubeInset),
                        Float(cube.top[3].z)
                    ),
                    endPoint: SIMD3<Float>(
                        Float(cube.bottom[3].x + cubeInset),
                        Float(cube.bottom[3].y - cubeInset),
                        Float(cube.bottom[3].z)
                    )
                ))
                let cubeIndexDouble = Double(cubeNr)
                let angleMultiplier = 1.0 + ((Double(totalCubes) - cubeIndexDouble) * 0.33333333)
                let angle = Float(timeAsFloat * angleMultiplier * 0.05)
                
                var rotationMatrix = matrix_rotation(
                    angle: angle,
                    axis: SIMD3<Float>(1, 0, 0))
                
                let cubeIndexFloat = Float(cubeNr)
                let timeFloat = Float(timeAsFloat)
                let sineArg = ((Float(totalCubes) - cubeIndexFloat) * 0.5) + (timeFloat * 0.5)
                let sineRed = ((Float(totalCubes) - cubeIndexFloat) * 0.5) + (timeFloat * 0.7)
                let greenVal = (sin(sineArg) * 0.5) + 0.5
                let redVal = (sin(sineRed) * 0.5) + 0.5
                
                let brightness = ensureValueIsFloat(brightnessInput.getHistoryValue(millisecondsAgo: cubeIndexDouble * 30.0))
                let brightnessRed = ensureValueIsFloat(brightnessInput.getHistoryValue(millisecondsAgo: 90.0 + cubeIndexDouble * 20.0))
                let brightnessGreen = ensureValueIsFloat(brightnessInput.getHistoryValue(millisecondsAgo: 50.0 + cubeIndexDouble * 5.0))
                let brightnessBlue = ensureValueIsFloat(brightnessInput.getHistoryValue(millisecondsAgo: cubeIndexDouble * 35.0))
                
                var color = SIMD4<Float>(
                    0.5 + 0.5 * redVal * Float(1.0 * sigmoidFunction(input: Double(brightnessRed), steepness: 10.0)),
                    greenVal * Float(1.0 * sigmoidFunction(input: Double(brightnessGreen), steepness: 5.0)) * 3.0,
                    brightnessBlue * 0.2,
                    Float(sigmoidFunction(input: Double(brightness), steepness: 20.0)))

                // Increase overall brightness by brightness amount
                color.x += brightness * 0.9
                color.y += brightness * 0.9
                color.z += brightness * 0.3
                
                // Calculate center of the current cube
                // Since the cube is constructed from squares[cubeNr] centered at (0,0) relative to the square logic,
                // and then extruded by +/- depth/2, the center is simply the center of the square at z=0.
                // However, the square points were already centered globally in the `squares` loop earlier.
                // Let's calculate the centroid of the top face to find X,Y, and Z is 0.
                
                var centerSum = SIMD3<Double>(0, 0, 0)
                let allPoints = cube.top + cube.bottom
                for p in allPoints {
                    centerSum += p
                }
                let centerDouble = centerSum / Double(allPoints.count)
                let center = SIMD3<Float>(Float(centerDouble.x), Float(centerDouble.y), Float(centerDouble.z))
                
                let toOrigin = matrix_translation(translation: -center)
                let fromOrigin = matrix_translation(translation: center)
                let zScale = 1.0 - ensureValueIsFloat(depthInput.getHistoryValue(millisecondsAgo: cubeIndexDouble * 70.0))
                let zScaleMatrix = matrix_scale(scale: SIMD3<Float>(1.0, 1.0, zScale))
                
                let xScale = 1.0 - ensureValueIsFloat(widthInput.getHistoryValue(millisecondsAgo: cubeIndexDouble * 50.0))
                let xScaleMatrix = matrix_scale(scale: SIMD3<Float>(xScale, 1.0, 1.0))
                
                let yScale = 1.0 - ensureValueIsFloat(heightInput.getHistoryValue(millisecondsAgo: cubeIndexDouble * 90.0))
                let yScaleMatrix = matrix_scale(scale: SIMD3<Float>(1.0, yScale, 1.0))
                
                let combinedMatrix = fromOrigin * rotationMatrix * toOrigin

                for l in cubeLines {
                    var l_t = Line(
                        startPoint: l.startPoint,
                        endPoint: l.endPoint,
                        degree: l.degree,
                        controlPoints: l.controlPoints,
                        lineWidthStart: lineWidthBase + 2 * brightness,
                        lineWidthEnd: lineWidthBase + 2 * brightness
                    )
                    l_t = l_t.setBasicEndPointColors(startColor: color, endColor: color)
                    var l_tMain = l_t
                    var l_Height = l_t
                    var l_Width = l_t
                    
                    
                    
                    
                    l_t = l_t.applyMatrix(fromOrigin)
                    l_t = l_t.applyMatrix(zScaleMatrix)
                    // l_t = l_t.applyMatrix(rotationMatrix)
                    l_t = l_t.applyMatrix(toOrigin)
                    
                    l_Height = l_Height.applyMatrix(fromOrigin * zScaleMatrix * yScaleMatrix * toOrigin)
                    l_Width = l_Width.applyMatrix(fromOrigin * zScaleMatrix * xScaleMatrix * toOrigin)
                    
                    l_t = l_t.applyMatrix(combinedMatrix)
                    l_tMain = l_tMain.applyMatrix(combinedMatrix)
                    l_Height = l_Height.applyMatrix(combinedMatrix)
                    l_Width = l_Width.applyMatrix(combinedMatrix)
                    
                    lines.append(l_t)
                    lines.append(l_tMain)
                    lines.append(l_Height)
                    lines.append(l_Width)
                }
                
                
                var crossColor = SIMD4<Float>(0.0, 0.0, 0.0, 0.5)
                var crossLinesTransformed: [Line] = []
                for l in crossLines {
                    var l_t = Line(
                        startPoint: l.startPoint,
                        endPoint: l.endPoint,
                        degree: l.degree,
                        controlPoints: l.controlPoints,
                        lineWidthStart: 0.7,
                        lineWidthEnd: 0.7
                    )
                    l_t = l_t.setBasicEndPointColors(startColor: crossColor, endColor: crossColor)
                    l_t = l_t.applyMatrix(combinedMatrix)
                    
                    crossLinesTransformed.append(l_t)
                }

                // lines.append(contentsOf: crossLinesTransformed)
                
                cubeNr += 1
            }
        } else if dayNumber == "4" {
            replacementProbability = Float(sigmoidFunction(input: (0.5 + sin(timeAsFloat * 2.0) * 0.5) * 0.51, steepness: 10.0))
            
            var spiral = Spiral()
            spiral.rotations = 2
            spiral.radius = 0.5
            spiral.height = 2.5
            spiral.offset = Float(timeAsFloat * 0.25)
            
            // var spiralLines = spiral.toLines(stepSize: 0.005)
            // lines.append(contentsOf: spiralLines)
            
            var voxelGrid = VoxelGrid(
                dimensions: (8, 8, 8),
                voxelSize: 0.15
            )
            
            let gridCenter = voxelGrid.gridCenter()
            let centeringMatrix = matrix_translation(translation: -gridCenter)
            
            var voxels = voxelGrid.voxels()
            
            for v in voxels {
                // Apply centering to the voxel center point first
                let centeredVoxelCenter = matrix_multiply(centeringMatrix, SIMD4<Float>(v.center, 1.0))
                let centeredPoint = SIMD3<Float>(centeredVoxelCenter.x, centeredVoxelCenter.y, centeredVoxelCenter.z)
                
                let distanceToSpiral = spiral.distanceToPoint(centeredPoint)
                
                
                
                // Calculate scaling factor based on distance (closer = larger, or vice versa depending on desired effect)
                // Example: Scale down as distance increases, normalized by voxelSize
                var scaleFactor = max(0.1, 1.0 - (distanceToSpiral / (voxelGrid.voxelSize * 1.5)))
                scaleFactor = Float(sigmoidFunction(input: Double(scaleFactor), steepness: 45.0)) * 0.9
                
                if scaleFactor > 0.01 {
                    
                    // Create scaling matrix
                    let scaleMatrix = matrix_scale(scale: SIMD3<Float>(scaleFactor, scaleFactor, scaleFactor))
                    
                    // Matrices to scale around the voxel's own center (before centering in grid)
                    let toVoxelOrigin = matrix_translation(translation: -v.center)
                    let fromVoxelOrigin = matrix_translation(translation: v.center)
                    
                    let voxelLines = v.toCube().wallOutlines()
                    // Apply centering translation to each line for rendering
                    
                    
                    let tFloat = Float(timeAsFloat)
                    
                    // Use more varied spatial frequencies to break uniformity
                    let greenInput = (v.center.z * 3.5) + (v.center.x * 1.2) + tFloat
                    // Map cosine from [-1, 1] to [0.2, 1.0] to avoid dipping into black
                    var green: Float = (cos(greenInput) * 0.4) + 0.6
                    
                    let blueInput = (v.center.y * 4.0) - (v.center.x * 2.0) + (tFloat * 1.3)
                    // Map sine from [-1, 1] to [0.3, 1.0]
                    var blue: Float = (sin(blueInput) * 0.35) + 0.65
                    
                    // Add a red component based on distance from center for a gradient effect
                    let dist = length(v.center)
                    let red = 0.2 + (sin(dist * 5.0 - tFloat * 2.0) * 0.2)

                    var voxelColor = SIMD4<Float>(
                        red,
                        green,
                        blue,
                        1.0
                    )
                    
                    // Use a cosine-based palette to ensure harmonious color transitions
                    // Based on: https://iquilezles.org/articles/palettes/
                    // Formula: color = a + b * cos(2 * pi * (c * t + d))
                    
                    // Calculate a scalar 't' based on position and time
                    // Combining radial distance and a bit of axial position creates a dynamic flow
                    let t = length(v.center) * 0.6 - tFloat * 0.15 + (v.center.x + v.center.y) * 0.1
                    
                    // Palette parameters for a vibrant, non-clashing spectrum
                    let pal_a = SIMD3<Float>(0.5, 0.5, 0.5)
                    let pal_b = SIMD3<Float>(0.5, 0.5, 0.5)
                    let pal_c = SIMD3<Float>(1.0, 1.0, 1.0)
                    let pal_d = SIMD3<Float>(0.00, 0.33, 0.67) // Phase shifts for R, G, B
                    
                    let twoPi: Float = 6.2831853
                    
                    let pRed = pal_a.x + pal_b.x * cos(twoPi * (pal_c.x * t + pal_d.x))
                    let pGreen = pal_a.y + pal_b.y * cos(twoPi * (pal_c.y * t + pal_d.y))
                    let pBlue = pal_a.z + pal_b.z * cos(twoPi * (pal_c.z * t + pal_d.z))
                    
                    voxelColor = SIMD4<Float>(pRed, pGreen, pBlue, 1.0)
                    
                    for line in voxelLines {
                        var centeredLine = line
                        
                        // Scale the voxel around its own center
                        centeredLine = centeredLine.applyMatrix(fromVoxelOrigin * scaleMatrix * toVoxelOrigin)
                        
                        // Move to centered grid position
                        centeredLine = centeredLine.applyMatrix(centeringMatrix)
                        centeredLine.lineWidthStart = lineWidthBase * 5 * scaleFactor
                        centeredLine.lineWidthEnd = lineWidthBase * 5 * scaleFactor
                        centeredLine = centeredLine.setBasicEndPointColors(startColor: voxelColor, endColor: voxelColor)
                        lines.append(centeredLine)
                    }
                }
            }
        } else if dayNumber == "5" {
            let style = CubeLetterStyle(
                maxLineWidth: 12.0,
                worldScale: 0.26,
                baseCubeSize: 0.06,
                cubesPerLetter: 20,
                coherence: 1.0,
                rotationJitter: 0.0,
            )

            var cubes = cubesForAbstractCubeText("GENUARY", origin: SIMD3<Float>(-1.1, 0.0, 0), style: style, seed: 42)
            
            var rotationMatrix = matrix_rotation(angle: Float(sin(timeAsFloat)) * 0.0, axis: SIMD3<Float>(0.0, 1.0, 0.0))
            
            var scaleMatrix = matrix_scale(scale: SIMD3<Float>(1.2, 2.1, 1.0))
            
            var cubeLines: [Line] = []
            var waveAmplitude:Float = 0.05
            for i in cubes.indices {
                var cubeT = Double(i) / Double(cubes.count)
                
//                if i % 4 == 0 {
//                    cubes[i].center.y += waveAmplitude * Float(sin(timeAsFloat + cubeT))
//                } else if i % 4 == 1 {
//                    cubes[i].center.y += waveAmplitude * Float(cos(timeAsFloat + cubeT))
//                } else if i % 4 == 2 {
//                    cubes[i].center.y += waveAmplitude * Float(sin(timeAsFloat * 0.5 + cubeT))
//                } else if i % 4 == 3 {
//                    cubes[i].center.y += waveAmplitude * Float(cos(timeAsFloat * 0.5 + cubeT))
//                }
                
//                if i % 2 == 0 {
//                    cubes[i].center.y += waveAmplitude * Float(sin(timeAsFloat + cubeT))
//                } else {
//                    cubes[i].center.y += waveAmplitude * Float(cos(timeAsFloat + cubeT))
//                }
                
                cubes[i].axisScale.x *= 1.0
                cubes[i].axisScale.y *= 1.0
                cubes[i].axisScale.z *= 0.5 // + pulsedWave(t: Float(-timeAsFloat * 0.25 + 1.0 + cubeT * 3), frequency: 0.25, steepness: 20.0) * 20.0
                
                var linesForCube = cubes[i].wallOutlines()
                // Rotate the cube lines around the cube center based on timeAsFloat and offset by cubeT
                let angle = -timeAsFloat * 0.5 + cubeT * 3
                let cubeRotationMatrix = matrix_rotation(angle: Float(angle), axis: SIMD3<Float>(0.0, 1.0, 0.0))
                let toCubeCenter = matrix_translation(translation: -cubes[i].center)
                let fromCubeCenter = matrix_translation(translation: cubes[i].center)
                let rotationAroundCenterMatrix = fromCubeCenter * cubeRotationMatrix * toCubeCenter
                for j in linesForCube.indices {
                    linesForCube[j] = linesForCube[j].applyMatrix(rotationAroundCenterMatrix)
                }
                cubeLines.append(contentsOf: linesForCube)
            }
            
            replacementProbability = pulsedWave(t: Float(timeAsFloat * 0.25 + 1.0), frequency: 0.25, steepness: 1.0) * 0.025
            
            var textColor = SIMD4<Float>(0.0, 0.0, 0.0, 1.0)
            for i in cubeLines.indices {
                cubeLines[i] = cubeLines[i].applyMatrix(rotationMatrix)
                cubeLines[i] = cubeLines[i].applyMatrix(scaleMatrix)
                cubeLines[i] = cubeLines[i].setBasicEndPointColors(startColor: textColor, endColor: textColor)
                cubeLines[i].lineWidthStart = lineWidthBase * 1.0
                cubeLines[i].lineWidthEnd = lineWidthBase * 1.0
            }
            
            lines.append(contentsOf: cubeLines)

        }
        
        // return lines

        
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
        
        for line in outputLines {
            var tLine = Line(
                startPoint: line.startPoint,
                endPoint: line.endPoint,
                degree: line.degree,
                controlPoints: line.controlPoints,
                lineWidthStart: lineWidthBase,
                lineWidthEnd: lineWidthBase
            )
            tLine = tLine.setBasicEndPointColors(startColor: cubeColor, endColor: cubeColor)
            
            if dayNumber == "1" {
                tLine = tLine.applyMatrix(scaleMatrix)
                tLine = tLine.applyMatrix(rotationMatrixXYZ)
            } else if dayNumber == "2" {
                let scaling:Float = 1.1
                let day2ScaleMatrix = matrix_scale(scale: SIMD3<Float>(scaling, scaling, scaling))
                tLine = tLine.applyMatrix(day2ScaleMatrix)
            }
            
            
            
            tLine = tLine.applyMatrix(translationMatrix)
            lines.append(tLine)
        }
        
        
    
        // TEXT
        
        var offWhite = SIMD4<Float>(0.9, 0.9, 0.9, 1.0)
        
        var textColor = SIMD4<Float>(
            1.0,
            1.0,
            1.0,
            1.0
        )
        
        textColor = SIMD4<Float>(
            0.7,
            0.7,
            0.7,
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



