//
//  Day13_SelfPortrait.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 18/01/2026.
//

struct Day13_SelfPortrait: GenuaryDayGenerator {
    let dayNumber = "13"

    func generateLines(
        inputs: [String: Any],
        scene: GeometriesSceneBase,
        time: Double,
        lineWidthBase: Float,
        state: Genuary2026State
    ) -> (lines: [Line], replacementProbability: Float) {
        
        var selfPortraitLines: [Line] = []
        
        
        var headPos: SIMD3<Float> = SIMD3<Float>(
            0.0,
            0.0,
            0.0
        )
        
        var eyeSize: Float = 0.39
        var eyePadding: Float = 0.0
        var eyeThickness: Float = 0.2
        var innerPadding: Float = 0.1
        var topPadding: Float = 0.1
        
        var eyeDepthScaling = matrix_scale(scale: SIMD3<Float>(1.0, 1.0, eyeThickness))
        
        
        var totalHeadSize = eyeSize * 2 + eyePadding * 4 + innerPadding * 2
        
        var leftEyePos: SIMD3<Float> = SIMD3<Float>(
            -eyeSize * 0.5 - eyePadding - innerPadding,
             totalHeadSize * 0.5  - eyeSize * 0.5 - eyePadding - topPadding,
             totalHeadSize * 0.5 + eyeThickness * 0.2
        )
        
        var rightEyePos: SIMD3<Float> = SIMD3<Float>(
            eyeSize * 0.5 + eyePadding + innerPadding,
             totalHeadSize * 0.5 - eyeSize * 0.5 - eyePadding - topPadding,
             totalHeadSize * 0.5 + eyeThickness * 0.2
        )
        
        var headCube = Cube(center: headPos, size: totalHeadSize)
        
        var leftEyeCube = Cube(center: SIMD3<Float>(repeating: 0.0), size: eyeSize)
        var rightEyeCube = Cube(center: SIMD3<Float>(repeating: 0.0), size: eyeSize)
        


        var leftEyeCubeLines = leftEyeCube.wallOutlines()
        // Map and apply matrix using leftEyePos
        var leftEyeTranslationMatrix = matrix_translation(translation: leftEyePos)
        let leftCombined = leftEyeTranslationMatrix * eyeDepthScaling;
        for i in leftEyeCubeLines.indices { leftEyeCubeLines[i] = leftEyeCubeLines[i].applyMatrix(leftCombined) }

        var rightEyeCubeLines = rightEyeCube.wallOutlines()
        // Map and apply matrix using rightEyePos
        var rightEyeTranslationMatrix = matrix_translation(translation: rightEyePos)
        let rightCombined = rightEyeTranslationMatrix * eyeDepthScaling;
        for i in rightEyeCubeLines.indices { rightEyeCubeLines[i] = rightEyeCubeLines[i].applyMatrix(rightCombined) }

        selfPortraitLines.append(contentsOf: headCube.wallOutlines())
        selfPortraitLines.append(contentsOf: leftEyeCubeLines)
        selfPortraitLines.append(contentsOf: rightEyeCubeLines)
        
        
        /// EYE SLITS
        let eyeSlitLeftCube = Cube(center: SIMD3<Float>(repeating: 0.0), size: eyeSize)
        let eyeSlitRightCube = Cube(center: SIMD3<Float>(repeating: 0.0), size: eyeSize)
        
        
        let eyeSlitScalingMatrix = matrix_scale(scale: SIMD3<Float>(0.9, 0.025, eyeThickness * 0.5))
        let eyeSlitLeftPositioningMatrix = matrix_translation(translation: SIMD3<Float>(
            -eyeSize * 0.5 - eyePadding - innerPadding - eyeSize * 0.05,
             totalHeadSize * 0.5 - eyeSize * 0.5 - eyePadding - topPadding,
             totalHeadSize * 0.5 + eyeThickness * 0.3
        ))
        let eyeSlitLeftCombinedMatrix = eyeSlitLeftPositioningMatrix * eyeSlitScalingMatrix
        var eyeSlitLeftCubeLines = eyeSlitLeftCube.wallOutlines()
        for i in eyeSlitLeftCubeLines.indices { eyeSlitLeftCubeLines[i] = eyeSlitLeftCubeLines[i].applyMatrix(eyeSlitLeftCombinedMatrix) }
        let eyeSlitRightPositioningMatrix = matrix_translation(translation: SIMD3<Float>(
            eyeSize * 0.5 + eyePadding + innerPadding + eyeSize * 0.05,
             totalHeadSize * 0.5 - eyeSize * 0.5 - eyePadding - topPadding,
            totalHeadSize * 0.5 + eyeThickness * 0.3
        ))
        let eyeSlitRightCombinedMatrix = eyeSlitRightPositioningMatrix * eyeSlitScalingMatrix
        var eyeSlitRightCubeLines = eyeSlitRightCube.wallOutlines()
        for i in eyeSlitRightCubeLines.indices { eyeSlitRightCubeLines[i] = eyeSlitRightCubeLines[i].applyMatrix(eyeSlitRightCombinedMatrix) }
        selfPortraitLines.append(contentsOf: eyeSlitLeftCubeLines)
        selfPortraitLines.append(contentsOf: eyeSlitRightCubeLines)
        
        
        
        /// NOSE
        let noseCube = Cube(center: SIMD3<Float>(repeating: 0.0), size: 1.0)
        let noseCubeScalingMatrix = matrix_scale(scale: SIMD3<Float>(0.025, 0.4, 0.025))
        let noseCubePositioningMatrix = matrix_translation(translation: SIMD3<Float>(
            0.0,
            0.05,
            totalHeadSize * 0.5 + 0.025
        ))
        let noseCombinedMatrix = noseCubePositioningMatrix * noseCubeScalingMatrix
        var noseCubeLines = noseCube.wallOutlines()
        for i in noseCubeLines.indices { noseCubeLines[i] = noseCubeLines[i].applyMatrix(noseCombinedMatrix) }
        selfPortraitLines.append(contentsOf: noseCubeLines)
        
        /// MOUTH
        let mouthCube = Cube(center: SIMD3<Float>(repeating: 0.0), size: 1.0)
        let mouthCubeScalingMatrix = matrix_scale(scale: SIMD3<Float>(0.5, 0.025, 0.025))
        let mouthCubePositioningMatrix = matrix_translation(translation: SIMD3<Float>(
            0.0,
            -totalHeadSize * 0.25,
            totalHeadSize * 0.5 + 0.025
        ))
        var mouthCombinedMatrix = mouthCubePositioningMatrix * mouthCubeScalingMatrix
        var mouthCubeLines = mouthCube.wallOutlines()
        for i in mouthCubeLines.indices { mouthCubeLines[i] = mouthCubeLines[i].applyMatrix(mouthCombinedMatrix) }
        selfPortraitLines.append(contentsOf: mouthCubeLines)
        

        
        var selfportraitLineCountBeforePods = selfPortraitLines.count
        
        
        // AIRPODS
        let leftPodCube = Cube(center: SIMD3<Float>(repeating: 0.0), size: 1.0)
        let rightPodCube = Cube(center: SIMD3<Float>(repeating: 0.0), size: 1.0)
        let leftPodStemCube = Cube(center: SIMD3<Float>(repeating: 0.0), size: 1.0)
        let rightPodStemCube = Cube(center: SIMD3<Float>(repeating: 0.0), size: 1.0)
        
        let podSize: Float = 0.12
        
        let podCubeScalingMatrix = matrix_scale(scale: SIMD3<Float>(repeating: podSize))
        let leftPodCubePositioningMatrix = matrix_translation(translation: SIMD3<Float>(
            -totalHeadSize * 0.5 - podSize * 0.6,
             0.1,
             0.0
        ))
        
        let leftPodCubeCombinedMatrix = leftPodCubePositioningMatrix * podCubeScalingMatrix
        var leftPodCubeLines = leftPodCube.wallOutlines()
        for i in leftPodCubeLines.indices { leftPodCubeLines[i] = leftPodCubeLines[i].applyMatrix(leftPodCubeCombinedMatrix) }
        selfPortraitLines.append(contentsOf: leftPodCubeLines)
        
        let rightPodCubePositioningMatrix = matrix_translation(translation: SIMD3<Float>(
            totalHeadSize * 0.5 + podSize * 0.6,
             0.1,
             0.0
        ))
        let rightPodCubeCombinedMatrix = rightPodCubePositioningMatrix * podCubeScalingMatrix
        var rightPodCubeLines = rightPodCube.wallOutlines()
        for i in rightPodCubeLines.indices { rightPodCubeLines[i] = rightPodCubeLines[i].applyMatrix(rightPodCubeCombinedMatrix) }
        selfPortraitLines.append(contentsOf: rightPodCubeLines)

        // Attach stem to back outer bottom of pods with sizing of 0.6 of podSize and length of 0.4
        // Refactored: Stem is vertical, connecting to the Back-Right-Bottom wall (Inner-Back-Bottom for Left Pod)
        let stemWidth = podSize * 0.4
        let stemHeight = podSize * 1.5
        let stemDepth = podSize * 0.4
        let podStemScalingMatrix = matrix_scale(scale: SIMD3<Float>(stemWidth, stemHeight, stemDepth))
        
        // Left Pod Stem (Symmetric: Outer)
        let leftPodX = -totalHeadSize * 0.5 - podSize * 0.6
        let leftPodY: Float = 0.1
        let leftPodZ: Float = 0.0
        
        let leftPodStemPositioningMatrix = matrix_translation(translation: SIMD3<Float>(
            leftPodX - podSize * 0.5 + stemWidth * 0.5, // Left (Outer)
            leftPodY - podSize * 0.5 - stemHeight * 0.5, // Bottom (hanging down)
            leftPodZ + podSize * 0.5 - stemDepth * 0.5   // Front
        ))
        let leftPodStemCombinedMatrix = leftPodStemPositioningMatrix * podStemScalingMatrix
        var leftPodStemCubeLines = leftPodStemCube.wallOutlines()
        for i in leftPodStemCubeLines.indices { leftPodStemCubeLines[i] = leftPodStemCubeLines[i].applyMatrix(leftPodStemCombinedMatrix) }
        selfPortraitLines.append(contentsOf: leftPodStemCubeLines)

        // Right Pod Stem (Symmetric: Outer)
        let rightPodX = totalHeadSize * 0.5 + podSize * 0.6
        let rightPodY: Float = 0.1
        let rightPodZ: Float = 0.0

        let rightPodStemPositioningMatrix = matrix_translation(translation: SIMD3<Float>(
            rightPodX + podSize * 0.5 - stemWidth * 0.5, // Right (Outer)
            rightPodY - podSize * 0.5 - stemHeight * 0.5, // Bottom (hanging down)
            rightPodZ + podSize * 0.5 - stemDepth * 0.5   // Front
        ))
        let rightPodStemCombinedMatrix = rightPodStemPositioningMatrix * podStemScalingMatrix
        var rightPodStemCubeLines = rightPodStemCube.wallOutlines()
        for i in rightPodStemCubeLines.indices { rightPodStemCubeLines[i] = rightPodStemCubeLines[i].applyMatrix(rightPodStemCombinedMatrix) }
        selfPortraitLines.append(contentsOf: rightPodStemCubeLines)

        
        var totalPortraitRotation = matrix_rotation(angle: sin(Float(time * 0.125)) * 0.125, axis: SIMD3<Float>(0.0, 1.0, 0.0))


        var totalPortraitRotationX = matrix_rotation(angle: sin(Float(time * 0.25)) * 0.25, axis: SIMD3<Float>(1.0, 0.0, 0.0))
        
        let totalScaling = matrix_scale(scale: SIMD3<Float>(repeating: 0.9))
        
        
        var allMatrices = totalPortraitRotationX * totalPortraitRotation * totalScaling
        for i in selfPortraitLines.indices {
            selfPortraitLines[i] = selfPortraitLines[i].applyMatrix(allMatrices)
            selfPortraitLines[i].lineWidthStart = lineWidthBase * 3
            selfPortraitLines[i].lineWidthEnd = lineWidthBase * 3
        }
        
        func fluidSpherePath(time t: Float) -> SIMD3<Float> {
            // Build a quasi-periodic 3D signal from several incommensurate frequencies
            let x = sin(0.73 * t) + 0.37 * sin(2.19 * t + 0.5)
            let y = cos(1.11 * t) + 0.29 * cos(2.93 * t + 1.3)
            let z = 0.85 * sin(0.53 * t + 1.0) + 0.52 * sin(1.87 * t + 2.2)
            
            let v = SIMD3<Float>(x, y, z)
            // Project onto sphere
            return simd_normalize(v)
        }
        
        
        
        var lightPoint = fluidSpherePath(time: Float(time * 0.5))
        var lightPoint2 = fluidSpherePath(time: Float(time * 0.45 + 200.0))
        
        

        // For each line in selfPortraitlines, set the color of the line start and end point based on distance towards lightPoint
        func calculateLitColor(for point: SIMD3<Float>, lightPos: SIMD3<Float>) -> SIMD4<Float> {
            let toLight = lightPos - point
            let distanceToLight = simd_length(toLight)
            let maxDistance: Float = 2.5
            
            // Normalize distance and apply sigmoid for non-linear falloff
            let normalizedDist = min(distanceToLight / maxDistance, 1.0)
            let input = Double(1.0 - normalizedDist) // Approximate range [0.3, 0.8] given head size ~1.0 vs light dist ~1.0
            
            // Different thresholds creating a color shift from White -> Yellow -> Red -> Black as distance increases
            let rSig = Float(sigmoidFunction(input: input, steepness: 15.0, threshold: 0.65))
            let gSig = Float(sigmoidFunction(input: input, steepness: 25.0, threshold: 0.55))
            let bSig = Float(sigmoidFunction(input: input, steepness: 25.0, threshold: 0.45))
            
            return SIMD4<Float>(
                0.0 + 1.4 * rSig,    // R (Extends furthest)
                0.0 + 1.8 * gSig,    // G
                0.0 + 2.0 * bSig,    // B (Confined to closest highlight)
                1.0
            )
        }
        
        func calculateRedHighlight(for point: SIMD3<Float>, lightPos: SIMD3<Float>) -> SIMD4<Float> {
            let toLight = lightPos - point
            let distanceToLight = simd_length(toLight)
            let maxDistance: Float = 2.5
            
            let normalizedDist = min(distanceToLight / maxDistance, 1.0)
            let input = Double(1.0 - normalizedDist)
            
            let rSig = Float(sigmoidFunction(input: input, steepness: 30.0, threshold: 0.6))
            
            return SIMD4<Float>(
                0.0 + 2.5 * rSig,
                0.0,
                0.0,
                0.0
            )
        }

        for i in selfPortraitLines.indices {
            // Calculate colors individually for start and end points
            var startColor = calculateLitColor(for: selfPortraitLines[i].startPoint, lightPos: lightPoint)
            var endColor = calculateLitColor(for: selfPortraitLines[i].endPoint, lightPos: lightPoint)
            
            let startRed = calculateRedHighlight(for: selfPortraitLines[i].startPoint, lightPos: lightPoint2)
            let endRed = calculateRedHighlight(for: selfPortraitLines[i].endPoint, lightPos: lightPoint2)
            
            startColor += startRed
            endColor += endRed
            
            selfPortraitLines[i] = selfPortraitLines[i].setBasicEndPointColors(startColor: startColor, endColor: endColor)
        }
        
        
        return (selfPortraitLines, 0.0) // default replacement probability
    }
}
