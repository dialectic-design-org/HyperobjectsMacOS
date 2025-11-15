//
//  CubeGenerator.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 06/11/2024.
//

import Foundation
import simd

class CubeGenerator: CachedGeometryGenerator {
    init() {
        super.init(name: "Cube Generator", inputDependencies: ["Size", "Rotation"])
    }
    
    override func generateGeometriesFromInputs(inputs: [String : Any], withScene scene: GeometriesSceneBase) -> [any Geometry] {
        var lines: [Line] = []
        
        
        let startColor = colorFromInputs(inputs, name: "Color start")
        let endColor = colorFromInputs(inputs, name: "Color end")
        let colorScale = ColorScale(colors: [startColor, endColor], mode: .hsl)

        
        
        let size = floatFromInputs(inputs, name: "Size")
        let facesOffsetInput = scene.getInputWithName(name: "Face offset")
        let facesOffsetInputDelay = scene.getInputWithName(name: "Face offset delay")
        
        let outerLoopCubesCount: Int = intFromInputs(inputs, name: "Outer Loop Cubes Count")// 1 to 100
        let innerLoopCubesCount: Int = intFromInputs(inputs, name: "Inner Loop Cubes Count")
        
        
        let innerCubesScalingInput = scene.getInputWithName(name: "InnerCubesScaling")
        let innerCubesScalingDelay = scene.getInputWithName(name: "InnerCubesScaling delay")
        
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
        
        let widthInput = scene.getInputWithName(name: "Width")
        let widthInputDelay = scene.getInputWithName(name: "Width delay")
        
        let heightInput = scene.getInputWithName(name: "Height")
        let heightInputDelay = scene.getInputWithName(name: "Height delay")
        
        let depthInput = scene.getInputWithName(name: "Depth")
        let depthInputDelay = scene.getInputWithName(name: "Depth delay")
        
        
        
        // Outer loop cubes
        let outerLoopCubesSpreadXInput = scene.getInputWithName(name: "Outer Loop Cubes spread x")
        let outerLoopCubesSpreadXInputDelay = scene.getInputWithName(name: "Outer Loop Cubes spread x delay")
        
        let outerLoopCubesSpreadYInput = scene.getInputWithName(name: "Outer Loop Cubes spread y")
        let outerLoopCubesSpreadYInputDelay = scene.getInputWithName(name: "Outer Loop Cubes spread y delay")
        
        let outerLoopCubesSpreadZInput = scene.getInputWithName(name: "Outer Loop Cubes spread z")
        let outerLoopCubesSpreadZInputDelay = scene.getInputWithName(name: "Outer Loop Cubes spread z delay")
        
        
        // Inner loop cubes
        let innerLoopCubesSpreadXInput = scene.getInputWithName(name: "Inner Loop Cubes spread x")
        let innerLoopCubesSpreadXInputDelay = scene.getInputWithName(name: "Inner Loop Cubes spread x delay")
        
        let innerLoopCubesSpreadYInput = scene.getInputWithName(name: "Inner Loop Cubes spread y")
        let innerLoopCubesSpreadYInputDelay = scene.getInputWithName(name: "Inner Loop Cubes spread y delay")
        
        let innerLoopCubesSpreadZInput = scene.getInputWithName(name: "Inner Loop Cubes spread z")
        let innerLoopCubesSpreadZInputDelay = scene.getInputWithName(name: "Inner Loop Cubes spread z delay")
        
        
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
                for i in 0..<cube.count {
                    cube[i].startPoint.y *= ensureValueIsFloat(delayedHeight)
                    cube[i].endPoint.y *= ensureValueIsFloat(delayedHeight)
                    
                    cube[i].startPoint.x *= ensureValueIsFloat(delayedWidth)
                    cube[i].endPoint.x *= ensureValueIsFloat(delayedWidth)
                    
                    cube[i].startPoint.z *= ensureValueIsFloat(delayedDepth)
                    cube[i].endPoint.z *= ensureValueIsFloat(delayedDepth)
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
                if innerCubeCounts > 1 {
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
                
                var matrixTranslate = matrix_translation(translation: SIMD3<Float>(
                    (xTranslateOuterLoop * ensureValueIsFloat(outerLoopXTranslate)) + (xTranslateInnerLoop * ensureValueIsFloat(innerLoopXTranslate)),
                    (yTranslateOuterLoop * ensureValueIsFloat(outerLoopYTranslate)) + (yTranslateInnerLoop * ensureValueIsFloat(innerLoopYTranslate)),
                    (zTranslateOuterLoop * ensureValueIsFloat(outerLoopZTranslate)) + (zTranslateInnerLoop * ensureValueIsFloat(innerLoopZTranslate))
                ))
                
                
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
                    
                    let brightnessValue = brightnessInput.getHistoryValue(
                        millisecondsAgo: Double(ensureValueIsFloat(
                            brightnessInputDelay.getHistoryValue(millisecondsAgo: 0))
                                                * cubeTime * 1000
                                               )
                    )
                    
                    let saturationValue = saturationInput.getHistoryValue(
                        millisecondsAgo: Double(ensureValueIsFloat(
                            saturationInputDelay.getHistoryValue(millisecondsAgo: 0))
                                                * cubeTime * 1000
                        )
                    )
                    
                    
                    let color = colorScale.color(at: Double(colorTime),
                                                 saturation: Double(ensureValueIsFloat(saturationValue)),
                                                 brightness: Double(ensureValueIsFloat(brightnessValue))).toSIMD4()
                    cube[i] = cube[i].setBasicEndPointColors(
                        startColor: color,
                        endColor: color
                    )
                }
                
                lines += cube
            }
        }
        
        let sceneRotationMatrixX = matrix_rotation(angle: sceneStatefulRotationX, axis: SIMD3<Float>(1.0, 0.0, 0.0))
        let sceneRotationMatrixY = matrix_rotation(angle: sceneStatefulRotationY, axis: SIMD3<Float>(0.0, 1.0, 0.0))
        let sceneRotationMatrixZ = matrix_rotation(angle: sceneStatefulRotationZ, axis: SIMD3<Float>(0.0, 0.0, 1.0))
        
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

