//
//  CubeGenerator.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 06/11/2024.
//

import Foundation
import simd
import SwiftUI

class CubeGenerator: CachedGeometryGenerator {
    init() {
        super.init(name: "Cube Generator", inputDependencies: ["Size", "Rotation"])
    }
    
    override func generateGeometriesFromInputs(inputs: [String : Any], withScene scene: GeometriesSceneBase) -> [any Geometry] {
        var lines: [Line] = []
        
        
        let startColor = colorFromInputs(inputs, name: "Color start")
        let endColor = colorFromInputs(inputs, name: "Color end")
        let colorScale = ColorScale(colors: [startColor, endColor], mode: .hsl)

        let sceneRotationX = floatFromInputs(inputs, name: "Scene Rotation X")
        let sceneRotationY = floatFromInputs(inputs, name: "Scene Rotation Y")
        let sceneRotationZ = floatFromInputs(inputs, name: "Scene Rotation Z")

        let colorMode = stringFromInputs(inputs, name: "Color mode")
        let isRGBColorMode = (colorMode == "RGB")
        
        let size = floatFromInputs(inputs, name: "Size")
        let facesOffsetInput = scene.getInputWithName(name: "Face offset")
        let facesOffsetInputDelay = scene.getInputWithName(name: "Face offset delay")
        let facesOffsetInputOuterLoopDelay = scene.getInputWithName(name: "Face offset Outer Loop delay")
        let facesOffsetInputInnerLoopDelay = scene.getInputWithName(name: "Face offset Inner Loop delay")
        
        let outerLoopCubesCount: Int = intFromInputs(inputs, name: "Outer Loop Cubes Count")// 1 to 100
        let innerLoopCubesCount: Int = intFromInputs(inputs, name: "Inner Loop Cubes Count")
        
        
        let innerCubesScalingInput = scene.getInputWithName(name: "InnerCubesScaling")
        let innerCubesScalingInputOuterLoop = scene.getInputWithName(name: "InnerCubesScaling Outer Loop")
        let innerCubesScalingInputInnerLoop = scene.getInputWithName(name: "InnerCubesScaling Inner Loop")
        let innerCubesScalingDelay = scene.getInputWithName(name: "InnerCubesScaling delay")
        let innerCubesScalingOuterLoopDelay = scene.getInputWithName(name: "InnerCubesScaling Outer Loop delay")
        let innerCubesScalingInnerLoopDelay = scene.getInputWithName(name: "InnerCubesScaling Inner Loop delay")
        
        let rotationXInput = scene.getInputWithName(name: "Rotation X")
        let rotationXInputDelay = scene.getInputWithName(name: "Rotation X Delay")
        let rotationXOffsetInput = scene.getInputWithName(name: "Rotation X Offset")
        let rotationXOffsetInputDelay = scene.getInputWithName(name: "Rotation X Offset Delay")
        
        let rotationYInput = scene.getInputWithName(name: "Rotation Y")
        let rotationYInputDelay = scene.getInputWithName(name: "Rotation Y Delay")
        let rotationYOffsetInput = scene.getInputWithName(name: "Rotation Y Offset")
        let rotationYOffsetInputDelay = scene.getInputWithName(name: "Rotation Y Offset Delay")
        
        let rotationZInput = scene.getInputWithName(name: "Rotation Z")
        let rotationZInputDelay = scene.getInputWithName(name: "Rotation Z Delay")
        let rotationZOffsetInput = scene.getInputWithName(name: "Rotation Z Offset")
        let rotationZOffsetInputDelay = scene.getInputWithName(name: "Rotation Z Offset Delay")
        
        
        let lineWidthInput = scene.getInputWithName(name: "LineWidth")
        let lineWidthInputDelay = scene.getInputWithName(name: "LineWidth delay")
        let lineWidthInputOuterLoopDelay = scene.getInputWithName(name: "LineWidth Outer Loop delay")
        let lineWidthInputInnerLoopDelay = scene.getInputWithName(name: "LineWidth Inner Loop delay")
        
        let widthInput = scene.getInputWithName(name: "Width")
        let widthInputDelay = scene.getInputWithName(name: "Width delay")
        let widthInputOuterLoopDelay = scene.getInputWithName(name: "Width Outer Loop delay")
        let widthInputInnerLoopDelay = scene.getInputWithName(name: "Width Inner Loop delay")
        
        let heightInput = scene.getInputWithName(name: "Height")
        let heightInputDelay = scene.getInputWithName(name: "Height delay")
        let heightInputOuterLoopDelay = scene.getInputWithName(name: "Height Outer Loop delay")
        let heightInputInnerLoopDelay = scene.getInputWithName(name: "Height Inner Loop delay")
        
        let depthInput = scene.getInputWithName(name: "Depth")
        let depthInputDelay = scene.getInputWithName(name: "Depth delay")
        let depthInputOuterLoopDelay = scene.getInputWithName(name: "Depth Outer Loop delay")
        let depthInputInnerLoopDelay = scene.getInputWithName(name: "Depth Inner Loop delay")
        
        
        // Outer loop cubes
        let outerLoopCubesSpreadXInput = scene.getInputWithName(name: "Outer Loop Cubes spread x")
        let outerLoopCubesSpreadXInputDelay = scene.getInputWithName(name: "Outer Loop Cubes spread x delay")
        let outerLoopCubesSpreadXInputOuterLoopDelay = scene.getInputWithName(name: "Outer Loop Cubes spread x Outer Loop delay")
        let outerLoopCubesSpreadXInputInnerLoopDelay = scene.getInputWithName(name: "Outer Loop Cubes spread x Inner Loop delay")
        
        let outerLoopCubesSpreadYInput = scene.getInputWithName(name: "Outer Loop Cubes spread y")
        let outerLoopCubesSpreadYInputDelay = scene.getInputWithName(name: "Outer Loop Cubes spread y delay")
        let outerLoopCubesSpreadYInputOuterLoopDelay = scene.getInputWithName(name: "Outer Loop Cubes spread y Outer Loop delay")
        let outerLoopCubesSpreadYInputInnerLoopDelay = scene.getInputWithName(name: "Outer Loop Cubes spread y Inner Loop delay")
        
        let outerLoopCubesSpreadZInput = scene.getInputWithName(name: "Outer Loop Cubes spread z")
        let outerLoopCubesSpreadZInputDelay = scene.getInputWithName(name: "Outer Loop Cubes spread z delay")
        let outerLoopCubesSpreadZInputOuterLoopDelay = scene.getInputWithName(name: "Outer Loop Cubes spread z Outer Loop delay")
        let outerLoopCubesSpreadZInputInnerLoopDelay = scene.getInputWithName(name: "Outer Loop Cubes spread z Inner Loop delay")
        
        
        // Inner loop cubes
        let innerLoopCubesSpreadXInput = scene.getInputWithName(name: "Inner Loop Cubes spread x")
        let innerLoopCubesSpreadXInputDelay = scene.getInputWithName(name: "Inner Loop Cubes spread x delay")
        let innerLoopCubesSpreadXInputOuterLoopDelay = scene.getInputWithName(name: "Inner Loop Cubes spread x Outer Loop delay")
        let innerLoopCubesSpreadXInputInnerLoopDelay = scene.getInputWithName(name: "Inner Loop Cubes spread x Inner Loop delay")
        
        let innerLoopCubesSpreadYInput = scene.getInputWithName(name: "Inner Loop Cubes spread y")
        let innerLoopCubesSpreadYInputDelay = scene.getInputWithName(name: "Inner Loop Cubes spread y delay")
        let innerLoopCubesSpreadYInputOuterLoopDelay = scene.getInputWithName(name: "Inner Loop Cubes spread y Outer Loop delay")
        let innerLoopCubesSpreadYInputInnerLoopDelay = scene.getInputWithName(name: "Inner Loop Cubes spread y Inner Loop delay")
        
        let innerLoopCubesSpreadZInput = scene.getInputWithName(name: "Inner Loop Cubes spread z")
        let innerLoopCubesSpreadZInputDelay = scene.getInputWithName(name: "Inner Loop Cubes spread z delay")
        let innerLoopCubesSpreadZInputOuterLoopDelay = scene.getInputWithName(name: "Inner Loop Cubes spread z Outer Loop delay")
        let innerLoopCubesSpreadZInputInnerLoopDelay = scene.getInputWithName(name: "Inner Loop Cubes spread z Inner Loop delay")
        
        
        // Wave function inputs
        let waveAmplituteOuterLoopTranslateXInput = scene.getInputWithName(name: "Wave Amplitude Outer Loop translate x")
        let waveFrequencyOuterLoopTranslateXInput = scene.getInputWithName(name: "Wave Frequency Outer Loop translate x")
        let waveOffsetOuterLoopTranslateXInput = scene.getInputWithName(name: "Wave Offset Outer Loop translate x")

        let waveAmplituteOuterLoopTranslateYInput = scene.getInputWithName(name: "Wave Amplitude Outer Loop translate y")
        let waveFrequencyOuterLoopTranslateYInput = scene.getInputWithName(name: "Wave Frequency Outer Loop translate y")
        let waveOffsetOuterLoopTranslateYInput = scene.getInputWithName(name: "Wave Offset Outer Loop translate y")

        let waveAmplituteOuterLoopTranslateZInput = scene.getInputWithName(name: "Wave Amplitude Outer Loop translate z")
        let waveFrequencyOuterLoopTranslateZInput = scene.getInputWithName(name: "Wave Frequency Outer Loop translate z")
        let waveOffsetOuterLoopTranslateZInput = scene.getInputWithName(name: "Wave Offset Outer Loop translate z")

        let waveAmplituteInnerLoopTranslateXInput = scene.getInputWithName(name: "Wave Amplitude Inner Loop translate x")
        let waveFrequencyInnerLoopTranslateXInput = scene.getInputWithName(name: "Wave Frequency Inner Loop translate x")
        let waveOffsetInnerLoopTranslateXInput = scene.getInputWithName(name: "Wave Offset Inner Loop translate x")

        let waveAmplituteInnerLoopTranslateYInput = scene.getInputWithName(name: "Wave Amplitude Inner Loop translate y")
        let waveFrequencyInnerLoopTranslateYInput = scene.getInputWithName(name: "Wave Frequency Inner Loop translate y")
        let waveOffsetInnerLoopTranslateYInput = scene.getInputWithName(name: "Wave Offset Inner Loop translate y")

        let waveAmplituteInnerLoopTranslateZInput = scene.getInputWithName(name: "Wave Amplitude Inner Loop translate z")
        let waveFrequencyInnerLoopTranslateZInput = scene.getInputWithName(name: "Wave Frequency Inner Loop translate z")
        let waveOffsetInnerLoopTranslateZInput = scene.getInputWithName(name: "Wave Offset Inner Loop translate z")



        let waveAmlitudeOuterLoopWidth = scene.getInputWithName(name: "Wave Amplitude Outer Loop Width")
        let waveFrequencyOuterLoopWidth = scene.getInputWithName(name: "Wave Frequency Outer Loop Width")
        let waveOffsetOuterLoopWidth = scene.getInputWithName(name: "Wave Offset Outer Loop Width")

        let waveAmlitudeInnerLoopWidth = scene.getInputWithName(name: "Wave Amplitude Inner Loop Width")
        let waveFrequencyInnerLoopWidth = scene.getInputWithName(name: "Wave Frequency Inner Loop Width")
        let waveOffsetInnerLoopWidth = scene.getInputWithName(name: "Wave Offset Inner Loop Width")

        let waveAmplitudeOuterLoopHeight = scene.getInputWithName(name: "Wave Amplitude Outer Loop Height")
        let waveFrequencyOuterLoopHeight = scene.getInputWithName(name: "Wave Frequency Outer Loop Height")
        let waveOffsetOuterLoopHeight = scene.getInputWithName(name: "Wave Offset Outer Loop Height")

        let waveAmplitudeInnerLoopHeight = scene.getInputWithName(name: "Wave Amplitude Inner Loop Height")
        let waveFrequencyInnerLoopHeight = scene.getInputWithName(name: "Wave Frequency Inner Loop Height")
        let waveOffsetInnerLoopHeight = scene.getInputWithName(name: "Wave Offset Inner Loop Height")

        let waveAmplitudeOuterLoopDepth = scene.getInputWithName(name: "Wave Amplitude Outer Loop Depth")
        let waveFrequencyOuterLoopDepth = scene.getInputWithName(name: "Wave Frequency Outer Loop Depth")
        let waveOffsetOuterLoopDepth = scene.getInputWithName(name: "Wave Offset Outer Loop Depth")

        let waveAmplitudeInnerLoopDepth = scene.getInputWithName(name: "Wave Amplitude Inner Loop Depth")
        let waveFrequencyInnerLoopDepth = scene.getInputWithName(name: "Wave Frequency Inner Loop Depth")
        let waveOffsetInnerLoopDepth = scene.getInputWithName(name: "Wave Offset Inner Loop Depth")
        
        
        let redStartInput = scene.getInputWithName(name: "Red start")
        let redStartDelayInput = scene.getInputWithName(name: "Red start delay")
        let greenStartInput = scene.getInputWithName(name: "Green start")
        let greenStartDelayInput = scene.getInputWithName(name: "Green start delay")
        let blueStartInput = scene.getInputWithName(name: "Blue start")
        let blueStartDelayInput = scene.getInputWithName(name: "Blue start delay")
        
        let redEndInput = scene.getInputWithName(name: "Red end")
        let redEndDelayInput = scene.getInputWithName(name: "Red end delay")
        let greenEndInput = scene.getInputWithName(name: "Green end")
        let greenEndDelayInput = scene.getInputWithName(name: "Green end delay")
        let blueEndInput = scene.getInputWithName(name: "Blue end")
        let blueEndDelayInput = scene.getInputWithName(name: "Blue end delay")
        
        
        let brightnessInput = scene.getInputWithName(name: "Brightness")
        let brightnessInputDelay = scene.getInputWithName(name: "Brightness delay")
        
        let saturationInput = scene.getInputWithName(name: "Saturation")
        let saturationInputDelay = scene.getInputWithName(name: "Saturation delay")
        
        
        let statefulRotationX = floatFromInputs(inputs, name: "Stateful Rotation X")
        let statefulRotationY = floatFromInputs(inputs, name: "Stateful Rotation Y")
        let statefulRotationZ = floatFromInputs(inputs, name: "Stateful Rotation Z")
        
        let sceneStatefulRotationX = floatFromInputs(inputs, name: "Scene Stateful Rotation X")
        let sceneStatefulRotationY = floatFromInputs(inputs, name: "Scene Stateful Rotation Y")
        let sceneStatefulRotationZ = floatFromInputs(inputs, name: "Scene Stateful Rotation Z")
        
        let statefulColorShift = floatFromInputs(inputs, name: "Stateful Color Shift")
        
        
        
        func dimensionWaveContribution(amplitudeInput: SceneInput,
                                       frequencyInput: SceneInput,
                                       offsetInput: SceneInput,
                                       time: Float) -> Float {
            let amplitude = ensureValueIsFloat(amplitudeInput.getHistoryValue(millisecondsAgo: 0))
            if amplitude == 0.0 {
                return 0.0
            }
            let frequency = ensureValueIsFloat(frequencyInput.getHistoryValue(millisecondsAgo: 0))
            let phaseOffset = ensureValueIsFloat(offsetInput.getHistoryValue(millisecondsAgo: 0))
            let angle = Double((time * frequency) + phaseOffset) * 2.0 * Double.pi
            return amplitude * Float(sin(angle))
        }
        
        
        lines = []
        
        let cubeCounts: Int = outerLoopCubesCount
        let innerCubeCounts: Int = innerLoopCubesCount
        let totalCubesCount: Int = cubeCounts * innerCubeCounts
        
        for cubeCounter in 1...cubeCounts {
            let cubeOuterTime = Float(cubeCounter - 1) / Float(cubeCounts - 1)
            for innerCubeCounter in 1...innerCubeCounts {
                let cubeInnerTime = Float(innerCubeCounter - 1) / Float(innerCubeCounts - 1)
                
                let cubeTime = Float((cubeCounter + innerCubeCounter) - 1) / Float(totalCubesCount)
                
                let facesOffsetDelayed = facesOffsetInput.getHistoryValue(millisecondsAgo:
                                                                            Double(floatFromInputs(inputs, name: "Face offset delay")) * Double(cubeTime) * 1000)
                
                let innerCubesScalingValue = innerCubesScalingInput.getHistoryValue(millisecondsAgo:
                                                                                        Double(ensureValueIsFloat(innerCubesScalingDelay.getHistoryValue(millisecondsAgo: 0)) * cubeTime * 1000)
                )
                
                var cube = makeCube(size:  1.0 + cubeTime * ensureValueIsFloat(innerCubesScalingValue), offset: ensureValueIsFloat(facesOffsetDelayed))
                
                let delayedRotationX = rotationXInput.getHistoryValue(millisecondsAgo: Double(rotationXInputDelay.getHistoryValue(millisecondsAgo: 0) as! Float * cubeTime) * 1000)
                let delayedRotationY = rotationYInput.getHistoryValue(millisecondsAgo: Double(rotationYInputDelay.getHistoryValue(millisecondsAgo: 0) as! Float * cubeTime) * 1000)
                let delayedRotationZ = rotationZInput.getHistoryValue(millisecondsAgo: Double(rotationZInputDelay.getHistoryValue(millisecondsAgo: 0) as! Float * cubeTime) * 1000)
                
                let rotationXOffset = ensureValueIsFloat(rotationXOffsetInput.getHistoryValue(millisecondsAgo: Double(rotationXOffsetInputDelay.getHistoryValue(millisecondsAgo: 0) as! Float * cubeTime) * 1000)) * cubeTime
                let rotationYOffset = ensureValueIsFloat(rotationYOffsetInput.getHistoryValue(millisecondsAgo: Double(rotationYOffsetInputDelay.getHistoryValue(millisecondsAgo: 0) as! Float * cubeTime) * 1000)) * cubeTime
                let rotationZOffset = ensureValueIsFloat(rotationZOffsetInput.getHistoryValue(millisecondsAgo: Double(rotationZOffsetInputDelay.getHistoryValue(millisecondsAgo: 0) as! Float * cubeTime) * 1000)) * cubeTime
                
                
                let lineWidthDelayFloat: Float = ensureValueIsFloat(lineWidthInputDelay.getHistoryValue(millisecondsAgo: 0))
                let delayedLineWidth = lineWidthInput.getHistoryValue(millisecondsAgo: Double(lineWidthDelayFloat) * Double(cubeTime) * 1000)
                
                let delayedWidthDelay = widthInputDelay.getHistoryValue(millisecondsAgo: 0)
                let widthDelayFloat: Float = ensureValueIsFloat(delayedWidthDelay)
                let delayedWidth = widthInput.getHistoryValue(millisecondsAgo: Double(widthDelayFloat) * Double(cubeTime) * 1000)
                
                let heightDelay = heightInputDelay.getHistoryValue(millisecondsAgo: 0)
                let heightDelayFloat: Float = ensureValueIsFloat(heightDelay)
                let delayedHeight = heightInput.getHistoryValue(millisecondsAgo: Double(heightDelayFloat) * Double(cubeTime) * 1000)
                
                let depthDelay = depthInputDelay.getHistoryValue(millisecondsAgo: 0)
                let depthDelayFloat: Float = ensureValueIsFloat(depthDelay)
                let delayedDepth = depthInput.getHistoryValue(millisecondsAgo: Double(depthDelayFloat) * Double(cubeTime) * 1000)
                
                // Enforce delayed rotation to be a float
                let delayedRotationXFloat: Float = ensureValueIsFloat(delayedRotationX)
                let delayedRotationYFloat: Float = ensureValueIsFloat(delayedRotationY)
                let delayedRotationZFloat: Float = ensureValueIsFloat(delayedRotationZ)
                
                
                
                
                let delayedLineWidthFloat: Float = ensureValueIsFloat(delayedLineWidth)
                
                
                
                for i in 0..<cube.count {
                    cube[i].lineWidthStart = delayedLineWidthFloat
                    cube[i].lineWidthEnd = delayedLineWidthFloat
                }
                
                // Apply width, height, depth transforms
                let baseWidthScale = ensureValueIsFloat(delayedWidth)
                let baseHeightScale = ensureValueIsFloat(delayedHeight)
                let baseDepthScale = ensureValueIsFloat(delayedDepth)
                
                let widthOuterWave = dimensionWaveContribution(amplitudeInput: waveAmlitudeOuterLoopWidth,
                                                               frequencyInput: waveFrequencyOuterLoopWidth,
                                                               offsetInput: waveOffsetOuterLoopWidth,
                                                               time: cubeOuterTime)
                let widthInnerWave = dimensionWaveContribution(amplitudeInput: waveAmlitudeInnerLoopWidth,
                                                               frequencyInput: waveFrequencyInnerLoopWidth,
                                                               offsetInput: waveOffsetInnerLoopWidth,
                                                               time: cubeInnerTime)
                let finalWidthScale = baseWidthScale + widthOuterWave + widthInnerWave
                
                let heightOuterWave = dimensionWaveContribution(amplitudeInput: waveAmplitudeOuterLoopHeight,
                                                                frequencyInput: waveFrequencyOuterLoopHeight,
                                                                offsetInput: waveOffsetOuterLoopHeight,
                                                                time: cubeOuterTime)
                let heightInnerWave = dimensionWaveContribution(amplitudeInput: waveAmplitudeInnerLoopHeight,
                                                                frequencyInput: waveFrequencyInnerLoopHeight,
                                                                offsetInput: waveOffsetInnerLoopHeight,
                                                                time: cubeInnerTime)
                let finalHeightScale = baseHeightScale + heightOuterWave + heightInnerWave
                
                let depthOuterWave = dimensionWaveContribution(amplitudeInput: waveAmplitudeOuterLoopDepth,
                                                               frequencyInput: waveFrequencyOuterLoopDepth,
                                                               offsetInput: waveOffsetOuterLoopDepth,
                                                               time: cubeOuterTime)
                let depthInnerWave = dimensionWaveContribution(amplitudeInput: waveAmplitudeInnerLoopDepth,
                                                               frequencyInput: waveFrequencyInnerLoopDepth,
                                                               offsetInput: waveOffsetInnerLoopDepth,
                                                               time: cubeInnerTime)
                let finalDepthScale = baseDepthScale + depthOuterWave + depthInnerWave
                
                for i in 0..<cube.count {
                    cube[i].startPoint.y *= finalHeightScale
                    cube[i].endPoint.y *= finalHeightScale
                    
                    cube[i].startPoint.x *= finalWidthScale
                    cube[i].endPoint.x *= finalWidthScale
                    
                    cube[i].startPoint.z *= finalDepthScale
                    cube[i].endPoint.z *= finalDepthScale
                }
                
                // Apply size and rotation
                for i in 0..<cube.count {
                    cube[i].startPoint *= size
                    cube[i].endPoint *= size
                }
                let rotationMatrixX = matrix_rotation(angle: delayedRotationXFloat + statefulRotationX + rotationXOffset, axis: SIMD3<Float>(x: 1, y: 0, z: 0))
                let rotationMatrixY = matrix_rotation(angle: delayedRotationYFloat + statefulRotationY + rotationYOffset, axis: SIMD3<Float>(x: 0, y: 1, z: 0))
                let rotationMatrixZ = matrix_rotation(angle: delayedRotationZFloat + statefulRotationZ + rotationZOffset, axis: SIMD3<Float>(x: 0, y: 0, z: 1))

                let combinedRotationMatrix = rotationMatrixZ * rotationMatrixY * rotationMatrixX
                
//                for i in 0..<cube.count {
//                    cube[i] = cube[i].applyMatrix(rotationMatrixX)
//                }
//                
//                for i in 0..<cube.count {
//                    cube[i] = cube[i].applyMatrix(rotationMatrixY)
//                }
//                
//                for i in 0..<cube.count {
//                    cube[i] = cube[i].applyMatrix(rotationMatrixZ)
//                }
                  for i in 0..<cube.count {
                        cube[i] = cube[i].applyMatrix(combinedRotationMatrix)
                  }
                
                
                let scalingMatrix = matrix_scale(scale: SIMD3<Float>(repeating: 1.0))
                
                var xTranslateOuterLoop: Float = 0.0
                if cubeCounts > 1 {
                    xTranslateOuterLoop = (cubeOuterTime - 0.5)
                }
                var xTranslateInnerLoop: Float = 0.0
                if innerCubeCounts > 1 {
                    xTranslateInnerLoop = (cubeInnerTime - 0.5)
                }
                
                var yTranslateOuterLoop: Float = 0.0
                if cubeCounts > 1 {
                    yTranslateOuterLoop = (cubeOuterTime - 0.5)
                }
                var yTranslateInnerLoop: Float = 0.0
                if innerCubeCounts > 1 {
                    yTranslateInnerLoop = (cubeInnerTime - 0.5)
                }
                
                var zTranslateOuterLoop: Float = 0.0
                if cubeCounts > 1 {
                    zTranslateOuterLoop = (cubeOuterTime - 0.5)
                }
                var zTranslateInnerLoop: Float = 0.0
                if innerCubeCounts > 1 {
                    zTranslateInnerLoop = (cubeInnerTime - 0.5)
                }
                
                
                let outerLoopXTranslate = outerLoopCubesSpreadXInput.getHistoryValue(
                    millisecondsAgo: Double(ensureValueIsFloat(
                        outerLoopCubesSpreadXInputDelay.getHistoryValue(millisecondsAgo: 0))
                                            * cubeOuterTime * 1000
                                           )
                )
                let innerLoopXTranslate = innerLoopCubesSpreadXInput.getHistoryValue(
                    millisecondsAgo: Double(ensureValueIsFloat(
                        innerLoopCubesSpreadXInputDelay.getHistoryValue(millisecondsAgo: 0))
                                            * cubeInnerTime * 1000
                                           )
                )
                
                let outerLoopYTranslate = outerLoopCubesSpreadYInput.getHistoryValue(
                    millisecondsAgo: Double(ensureValueIsFloat(
                        outerLoopCubesSpreadYInputDelay.getHistoryValue(millisecondsAgo: 0))
                                            * cubeOuterTime * 1000
                                           )
                )
                let innerLoopYTranslate = innerLoopCubesSpreadYInput.getHistoryValue(
                    millisecondsAgo: Double(ensureValueIsFloat(
                        innerLoopCubesSpreadYInputDelay.getHistoryValue(millisecondsAgo: 0))
                                            * cubeInnerTime * 1000
                                           )
                )
                
                let outerLoopZTranslate = outerLoopCubesSpreadZInput.getHistoryValue(
                    millisecondsAgo: Double(ensureValueIsFloat(
                        outerLoopCubesSpreadZInputDelay.getHistoryValue(millisecondsAgo: 0))
                                            * cubeOuterTime * 1000
                                           )
                )
                let innerLoopZTranslate = innerLoopCubesSpreadZInput.getHistoryValue(
                    millisecondsAgo: Double(ensureValueIsFloat(
                        innerLoopCubesSpreadZInputDelay.getHistoryValue(millisecondsAgo: 0))
                                            * cubeInnerTime * 1000
                                           )
                )
                
                let translateXOuterWave = dimensionWaveContribution(
                    amplitudeInput: waveAmplituteOuterLoopTranslateXInput,
                    frequencyInput: waveFrequencyOuterLoopTranslateXInput,
                    offsetInput: waveOffsetOuterLoopTranslateXInput,
                    time: cubeOuterTime
                )
                let translateXInnerWave = dimensionWaveContribution(
                    amplitudeInput: waveAmplituteInnerLoopTranslateXInput,
                    frequencyInput: waveFrequencyInnerLoopTranslateXInput,
                    offsetInput: waveOffsetInnerLoopTranslateXInput,
                    time: cubeInnerTime
                )
                
                let translateYOuterWave = dimensionWaveContribution(
                    amplitudeInput: waveAmplituteOuterLoopTranslateYInput,
                    frequencyInput: waveFrequencyOuterLoopTranslateYInput,
                    offsetInput: waveOffsetOuterLoopTranslateYInput,
                    time: cubeOuterTime
                )
                let translateYInnerWave = dimensionWaveContribution(
                    amplitudeInput: waveAmplituteInnerLoopTranslateYInput,
                    frequencyInput: waveFrequencyInnerLoopTranslateYInput,
                    offsetInput: waveOffsetInnerLoopTranslateYInput,
                    time: cubeInnerTime
                )
                
                let translateZOuterWave = dimensionWaveContribution(
                    amplitudeInput: waveAmplituteOuterLoopTranslateZInput,
                    frequencyInput: waveFrequencyOuterLoopTranslateZInput,
                    offsetInput: waveOffsetOuterLoopTranslateZInput,
                    time: cubeOuterTime
                )
                let translateZInnerWave = dimensionWaveContribution(
                    amplitudeInput: waveAmplituteInnerLoopTranslateZInput,
                    frequencyInput: waveFrequencyInnerLoopTranslateZInput,
                    offsetInput: waveOffsetInnerLoopTranslateZInput,
                    time: cubeInnerTime
                )
                
                let translateX = (xTranslateOuterLoop * ensureValueIsFloat(outerLoopXTranslate)) +
                (xTranslateInnerLoop * ensureValueIsFloat(innerLoopXTranslate)) +
                translateXOuterWave + translateXInnerWave
                
                let translateY = (yTranslateOuterLoop * ensureValueIsFloat(outerLoopYTranslate)) +
                (yTranslateInnerLoop * ensureValueIsFloat(innerLoopYTranslate)) +
                translateYOuterWave + translateYInnerWave
                
                let translateZ = (zTranslateOuterLoop * ensureValueIsFloat(outerLoopZTranslate)) +
                (zTranslateInnerLoop * ensureValueIsFloat(innerLoopZTranslate)) +
                translateZOuterWave + translateZInnerWave
                
                var matrixTranslate = matrix_translation(translation: SIMD3<Float>(translateX,
                                                                                   translateY,
                                                                                   translateZ))
                
                
                let combinedMatrix = matrixTranslate * scalingMatrix
                
                let colorTime = (Double(cubeTime) + Double(statefulColorShift)).truncatingRemainder(dividingBy: 1.0)
                
                for i in 0..<cube.count {
                    cube[i] = cube[i].applyMatrix(combinedMatrix)
                    cube[i].lineWidthStart = delayedLineWidthFloat
                    cube[i].lineWidthEnd = delayedLineWidthFloat
                    
                    //                secondCube[i] = secondCube[i].setBasicEndPointColors(
                    //                    startColor: colorScale.color(at: Double(cubeTime)).toSIMD4(),
                    //                    endColor: colorScale.color(at: Double(cubeTime)).toSIMD4()
                    //                )
                    
                    let brightnessDelayValue = ensureValueIsFloat(
                        brightnessInputDelay.getHistoryValue(millisecondsAgo: 0)
                    )
                    let brightnessValue = brightnessInput.getHistoryValue(
                        millisecondsAgo: Double(brightnessDelayValue * cubeTime * 1000)
                    )
                    
                    let saturationDelayValue = ensureValueIsFloat(
                        saturationInputDelay.getHistoryValue(millisecondsAgo: 0)
                    )
                    let saturationValue = saturationInput.getHistoryValue(
                        millisecondsAgo: Double(saturationDelayValue * cubeTime * 1000)
                    )
                    
                    let brightnessFloat = ensureValueIsFloat(brightnessValue)
                    let saturationFloat = ensureValueIsFloat(saturationValue)
                    
                    let finalColor: SIMD4<Float>
                    if isRGBColorMode {
                        let redStartDelayValue = ensureValueIsFloat(
                            redStartDelayInput.getHistoryValue(millisecondsAgo: 0)
                        )
                        let redStartValue = redStartInput.getHistoryValue(
                            millisecondsAgo: Double(redStartDelayValue * cubeTime * 1000)
                        )
                        let redStartFloat = min(max(ensureValueIsFloat(redStartValue), 0.0), 1.0)
                        
                        let greenStartDelayValue = ensureValueIsFloat(
                            greenStartDelayInput.getHistoryValue(millisecondsAgo: 0)
                        )
                        let greenStartValue = greenStartInput.getHistoryValue(
                            millisecondsAgo: Double(greenStartDelayValue * cubeTime * 1000)
                        )
                        let greenStartFloat = min(max(ensureValueIsFloat(greenStartValue), 0.0), 1.0)
                        
                        let blueStartDelayValue = ensureValueIsFloat(
                            blueStartDelayInput.getHistoryValue(millisecondsAgo: 0)
                        )
                        let blueStartValue = blueStartInput.getHistoryValue(
                            millisecondsAgo: Double(blueStartDelayValue * cubeTime * 1000)
                        )
                        let blueStartFloat = min(max(ensureValueIsFloat(blueStartValue), 0.0), 1.0)
                        
                        let redEndDelayValue = ensureValueIsFloat(
                            redEndDelayInput.getHistoryValue(millisecondsAgo: 0)
                        )
                        let redEndValue = redEndInput.getHistoryValue(
                            millisecondsAgo: Double(redEndDelayValue * cubeTime * 1000)
                        )
                        let redEndFloat = min(max(ensureValueIsFloat(redEndValue), 0.0), 1.0)
                        
                        let greenEndDelayValue = ensureValueIsFloat(
                            greenEndDelayInput.getHistoryValue(millisecondsAgo: 0)
                        )
                        let greenEndValue = greenEndInput.getHistoryValue(
                            millisecondsAgo: Double(greenEndDelayValue * cubeTime * 1000)
                        )
                        let greenEndFloat = min(max(ensureValueIsFloat(greenEndValue), 0.0), 1.0)
                        
                        let blueEndDelayValue = ensureValueIsFloat(
                            blueEndDelayInput.getHistoryValue(millisecondsAgo: 0)
                        )
                        let blueEndValue = blueEndInput.getHistoryValue(
                            millisecondsAgo: Double(blueEndDelayValue * cubeTime * 1000)
                        )
                        let blueEndFloat = min(max(ensureValueIsFloat(blueEndValue), 0.0), 1.0)
                        
                        let rgbStartColor = Color(
                            red: Double(redStartFloat),
                            green: Double(greenStartFloat),
                            blue: Double(blueStartFloat)
                        )
                        
                        let rgbEndColor = Color(
                            red: Double(redEndFloat),
                            green: Double(greenEndFloat),
                            blue: Double(blueEndFloat)
                        )
                        
                        let rgbScale = ColorScale(colors: [rgbStartColor, rgbEndColor], mode: .rgb)
                        finalColor = rgbScale.color(
                            at: Double(colorTime),
                            saturation: Double(saturationFloat),
                            brightness: Double(brightnessFloat)
                        ).toSIMD4()
                    } else {
                        finalColor = colorScale.color(
                            at: Double(colorTime),
                            saturation: Double(saturationFloat),
                            brightness: Double(brightnessFloat)
                        ).toSIMD4()
                    }
                    
                    cube[i] = cube[i].setBasicEndPointColors(
                        startColor: finalColor,
                        endColor: finalColor
                    )
                }
                
                lines += cube
            }
        }
        
        let totalSceneRotationX = sceneRotationX + sceneStatefulRotationX
        let totalSceneRotationY = sceneRotationY + sceneStatefulRotationY
        let totalSceneRotationZ = sceneRotationZ + sceneStatefulRotationZ
        
        let sceneRotationMatrixX = matrix_rotation(angle: totalSceneRotationX, axis: SIMD3<Float>(1.0, 0.0, 0.0))
        let sceneRotationMatrixY = matrix_rotation(angle: totalSceneRotationY, axis: SIMD3<Float>(0.0, 1.0, 0.0))
        let sceneRotationMatrixZ = matrix_rotation(angle: totalSceneRotationZ, axis: SIMD3<Float>(0.0, 0.0, 1.0))
        
        let combinedSceneRotationMatrix = sceneRotationMatrixX * sceneRotationMatrixY * sceneRotationMatrixZ
        
        for i in 0..<lines.count {
            lines[i] = lines[i].applyMatrix(combinedSceneRotationMatrix)
        }
        
        return lines
    }
}


func makeCube(size: Float = 1.0, offset: Float = 0.0) -> [Line] {
    var cubeLines: [Line] = []
    
    
    if offset == 0.0 {
        // Standard cube: draw front/back perimeters and vertical connecting edges
        // Front (z = -size)
        cubeLines.append(Line(startPoint: SIMD3<Float>(x: -size, y: -size, z: -size), endPoint: SIMD3<Float>(x:  size, y: -size, z: -size)))
        cubeLines.append(Line(startPoint: SIMD3<Float>(x:  size, y: -size, z: -size), endPoint: SIMD3<Float>(x:  size, y:  size, z: -size)))
        cubeLines.append(Line(startPoint: SIMD3<Float>(x:  size, y:  size, z: -size), endPoint: SIMD3<Float>(x: -size, y:  size, z: -size)))
        cubeLines.append(Line(startPoint: SIMD3<Float>(x: -size, y:  size, z: -size), endPoint: SIMD3<Float>(x: -size, y: -size, z: -size)))

        // Back (z = size)
        cubeLines.append(Line(startPoint: SIMD3<Float>(x: -size, y: -size, z:  size), endPoint: SIMD3<Float>(x:  size, y: -size, z:  size)))
        cubeLines.append(Line(startPoint: SIMD3<Float>(x:  size, y: -size, z:  size), endPoint: SIMD3<Float>(x:  size, y:  size, z:  size)))
        cubeLines.append(Line(startPoint: SIMD3<Float>(x:  size, y:  size, z:  size), endPoint: SIMD3<Float>(x: -size, y:  size, z:  size)))
        cubeLines.append(Line(startPoint: SIMD3<Float>(x: -size, y:  size, z:  size), endPoint: SIMD3<Float>(x: -size, y: -size, z:  size)))

        // Connecting vertical edges
        cubeLines.append(Line(startPoint: SIMD3<Float>(x: -size, y: -size, z: -size), endPoint: SIMD3<Float>(x: -size, y: -size, z:  size)))
        cubeLines.append(Line(startPoint: SIMD3<Float>(x:  size, y: -size, z: -size), endPoint: SIMD3<Float>(x:  size, y: -size, z:  size)))
        cubeLines.append(Line(startPoint: SIMD3<Float>(x:  size, y:  size, z: -size), endPoint: SIMD3<Float>(x:  size, y:  size, z:  size)))
        cubeLines.append(Line(startPoint: SIMD3<Float>(x: -size, y:  size, z: -size), endPoint: SIMD3<Float>(x: -size, y:  size, z:  size)))
    } else {
        // Offset each face along its normal by `offset`
        let zFront = -size - offset   // front moves toward viewer when offset > 0
        let zBack  =  size + offset   // back moves away when offset > 0
        let xLeft  = -size - offset   // left moves further left when offset > 0
        let xRight =  size + offset   // right moves further right when offset > 0
        let yBottom = -size - offset  // bottom moves further down when offset > 0
        let yTop    =  size + offset  // top moves further up when offset > 0

        // Front face perimeter (z = zFront)
        cubeLines.append(Line(startPoint: SIMD3<Float>(x: -size, y: -size, z: zFront), endPoint: SIMD3<Float>(x:  size, y: -size, z: zFront)))
        cubeLines.append(Line(startPoint: SIMD3<Float>(x:  size, y: -size, z: zFront), endPoint: SIMD3<Float>(x:  size, y:  size, z: zFront)))
        cubeLines.append(Line(startPoint: SIMD3<Float>(x:  size, y:  size, z: zFront), endPoint: SIMD3<Float>(x: -size, y:  size, z: zFront)))
        cubeLines.append(Line(startPoint: SIMD3<Float>(x: -size, y:  size, z: zFront), endPoint: SIMD3<Float>(x: -size, y: -size, z: zFront)))

        // Back face perimeter (z = zBack)
        cubeLines.append(Line(startPoint: SIMD3<Float>(x: -size, y: -size, z: zBack), endPoint: SIMD3<Float>(x:  size, y: -size, z: zBack)))
        cubeLines.append(Line(startPoint: SIMD3<Float>(x:  size, y: -size, z: zBack), endPoint: SIMD3<Float>(x:  size, y:  size, z: zBack)))
        cubeLines.append(Line(startPoint: SIMD3<Float>(x:  size, y:  size, z: zBack), endPoint: SIMD3<Float>(x: -size, y:  size, z: zBack)))
        cubeLines.append(Line(startPoint: SIMD3<Float>(x: -size, y:  size, z: zBack), endPoint: SIMD3<Float>(x: -size, y: -size, z: zBack)))

        // Left face perimeter (x = xLeft)
        cubeLines.append(Line(startPoint: SIMD3<Float>(x: xLeft, y: -size, z: -size), endPoint: SIMD3<Float>(x: xLeft, y:  size, z: -size)))
        cubeLines.append(Line(startPoint: SIMD3<Float>(x: xLeft, y:  size, z: -size), endPoint: SIMD3<Float>(x: xLeft, y:  size, z:  size)))
        cubeLines.append(Line(startPoint: SIMD3<Float>(x: xLeft, y:  size, z:  size), endPoint: SIMD3<Float>(x: xLeft, y: -size, z:  size)))
        cubeLines.append(Line(startPoint: SIMD3<Float>(x: xLeft, y: -size, z:  size), endPoint: SIMD3<Float>(x: xLeft, y: -size, z: -size)))

        // Right face perimeter (x = xRight)
        cubeLines.append(Line(startPoint: SIMD3<Float>(x: xRight, y: -size, z: -size), endPoint: SIMD3<Float>(x: xRight, y:  size, z: -size)))
        cubeLines.append(Line(startPoint: SIMD3<Float>(x: xRight, y:  size, z: -size), endPoint: SIMD3<Float>(x: xRight, y:  size, z:  size)))
        cubeLines.append(Line(startPoint: SIMD3<Float>(x: xRight, y:  size, z:  size), endPoint: SIMD3<Float>(x: xRight, y: -size, z:  size)))
        cubeLines.append(Line(startPoint: SIMD3<Float>(x: xRight, y: -size, z:  size), endPoint: SIMD3<Float>(x: xRight, y: -size, z: -size)))

        // Bottom face perimeter (y = yBottom)
        cubeLines.append(Line(startPoint: SIMD3<Float>(x: -size, y: yBottom, z: -size), endPoint: SIMD3<Float>(x:  size, y: yBottom, z: -size)))
        cubeLines.append(Line(startPoint: SIMD3<Float>(x:  size, y: yBottom, z: -size), endPoint: SIMD3<Float>(x:  size, y: yBottom, z:  size)))
        cubeLines.append(Line(startPoint: SIMD3<Float>(x:  size, y: yBottom, z:  size), endPoint: SIMD3<Float>(x: -size, y: yBottom, z:  size)))
        cubeLines.append(Line(startPoint: SIMD3<Float>(x: -size, y: yBottom, z:  size), endPoint: SIMD3<Float>(x: -size, y: yBottom, z: -size)))

        // Top face perimeter (y = yTop)
        cubeLines.append(Line(startPoint: SIMD3<Float>(x: -size, y: yTop, z: -size), endPoint: SIMD3<Float>(x:  size, y: yTop, z: -size)))
        cubeLines.append(Line(startPoint: SIMD3<Float>(x:  size, y: yTop, z: -size), endPoint: SIMD3<Float>(x:  size, y: yTop, z:  size)))
        cubeLines.append(Line(startPoint: SIMD3<Float>(x:  size, y: yTop, z:  size), endPoint: SIMD3<Float>(x: -size, y: yTop, z:  size)))
        cubeLines.append(Line(startPoint: SIMD3<Float>(x: -size, y: yTop, z:  size), endPoint: SIMD3<Float>(x: -size, y: yTop, z: -size)))
    }

    return cubeLines
}
