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
        
        
        let lineWidth = floatFromInputs(inputs, name: "LineWidth")
        
        let startColor = colorFromInputs(inputs, name: "Color start")
        let endColor = colorFromInputs(inputs, name: "Color end")
        let colorScale = ColorScale(colors: [startColor, endColor], mode: .hsl)

        
        
        let size = floatFromInputs(inputs, name: "Size")
        let width = floatFromInputs(inputs, name: "Width")
        let height = floatFromInputs(inputs, name: "Height")
        let depth = floatFromInputs(inputs, name: "Depth")
        let facesOffset = floatFromInputs(inputs, name: "Face offset")
        let facesOffsetInput = scene.getInputWithName(name: "Face offset")
        let facesOffsetInputDelay = scene.getInputWithName(name: "Face offset delay")
        
        let innerCubesCount: Int = intFromInputs(inputs, name: "Inner cubes count")// 1 to 100
        let innerInnerCubesCount: Int = intFromInputs(inputs, name: "Inner inner cubes count")
        
        
        let innerCubesScaling = floatFromInputs(inputs, name: "InnerCubesScaling")
        let innerCubesScalingInput = scene.getInputWithName(name: "InnerCubesScaling")
        let innerCubesScalingDelay = scene.getInputWithName(name: "InnerCubesScaling delay")
        
        
        
        
        let rotationX = floatFromInputs(inputs, name: "Rotation X")
        let rotationY = floatFromInputs(inputs, name: "Rotation Y")
        let rotationZ = floatFromInputs(inputs, name: "Rotation Z")
        
        let rotationXInput = scene.getInputWithName(name: "Rotation X")
        let rotationYInput = scene.getInputWithName(name: "Rotation Y")
        let lineWidthInput = scene.getInputWithName(name: "LineWidth")
        let lineWidthInputDelay = scene.getInputWithName(name: "LineWidth delay")
        
        let widthInput = scene.getInputWithName(name: "Width")
        let widthInputDelay = scene.getInputWithName(name: "Width delay")
        
        let heightInput = scene.getInputWithName(name: "Height")
        let heightInputDelay = scene.getInputWithName(name: "Height delay")
        
        let depthInput = scene.getInputWithName(name: "Depth")
        let depthInputDelay = scene.getInputWithName(name: "Depth delay")
        
        
        let innerCubesSpreadXInput = scene.getInputWithName(name: "Inner cubes spread x")
        let innerCubesSpreadXDelayInput = scene.getInputWithName(name: "Inner cubes spread x delay")
        
        let innerInnerCubesSpreadYInput = scene.getInputWithName(name: "Inner inner cubes spread y")
        let innerInnerCubesSpreadYDelayInput = scene.getInputWithName(name: "Inner inner cubes spread y delay")
        
        
        let brightnessInput = scene.getInputWithName(name: "Brightness")
        let brightnessInputDelay = scene.getInputWithName(name: "Brightness delay")
        
        
        let statefulRotationX = floatFromInputs(inputs, name: "Stateful Rotation X")
        let statefulRotationY = floatFromInputs(inputs, name: "Stateful Rotation Y")
        let statefulRotationZ = floatFromInputs(inputs, name: "Stateful Rotation Z")
        
        let sceneStatefulRotationX = floatFromInputs(inputs, name: "Scene Stateful Rotation X")
        let sceneStatefulRotationY = floatFromInputs(inputs, name: "Scene Stateful Rotation Y")
        let sceneStatefulRotationZ = floatFromInputs(inputs, name: "Scene Stateful Rotation Z")
        
        let statefulColorShift = floatFromInputs(inputs, name: "Stateful Color Shift")
        
        
        
        lines = []
        
        let cubeCounts: Int = innerCubesCount
        let innerCubeCounts: Int = innerInnerCubesCount
        let totalCubesCount: Int = cubeCounts * innerCubeCounts
        
        for cubeCounter in 1...cubeCounts {
            let cubeOuterTime = Float(cubeCounter - 1) / Float(cubeCounts - 1)
            for innerCubeCounter in 1...innerCubeCounts {
                let cubeInnerTime = Float(innerCubeCounter - 1) / Float(innerCubeCounts - 1)
                
                let cubeTime = Float((cubeCounter + innerCubeCounter) - 1) / Float(totalCubesCount)
                
                let facesOffsetDelayed = facesOffsetInput.getHistoryValue(millisecondsAgo:
                                                                            Double(ensureValueIsFloat(facesOffsetInputDelay.getHistoryValue(millisecondsAgo: 0))
                                                                                   * cubeTime) * 1000)
                
                var innerCubesScalingValue = innerCubesScalingInput.getHistoryValue(millisecondsAgo:
                                                                                        Double(ensureValueIsFloat(innerCubesScalingDelay.getHistoryValue(millisecondsAgo: 0)) * cubeTime * 1000)
                )
                
                var secondCube = makeCube(size:  1.0 + cubeTime * ensureValueIsFloat(innerCubesScalingValue), offset: facesOffsetDelayed as! Float)
                
                let delayedRotation = rotationXInput.getHistoryValue(millisecondsAgo: 500 * Double(cubeTime))
                let delayedRotationY = rotationYInput.getHistoryValue(millisecondsAgo: 500 * Double(1.0 - cubeTime))
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
                let delayedRotationFloat: Float = ensureValueIsFloat(delayedRotation)
                let delayedRotationYFloat: Float = ensureValueIsFloat(delayedRotationY)
                let delayedLineWidthFloat: Float = ensureValueIsFloat(delayedLineWidth)
                
                
                
                for i in 0..<secondCube.count {
                    secondCube[i].lineWidthStart = delayedLineWidthFloat
                    secondCube[i].lineWidthEnd = delayedLineWidthFloat
                }
                
                // Apply width, height, depth transforms
                for i in 0..<secondCube.count {
                    secondCube[i].startPoint.y *= ensureValueIsFloat(delayedHeight)
                    secondCube[i].endPoint.y *= ensureValueIsFloat(delayedHeight)
                    
                    secondCube[i].startPoint.x *= ensureValueIsFloat(delayedWidth)
                    secondCube[i].endPoint.x *= ensureValueIsFloat(delayedWidth)
                    
                    secondCube[i].startPoint.z *= ensureValueIsFloat(delayedDepth)
                    secondCube[i].endPoint.z *= ensureValueIsFloat(delayedDepth)
                }
                
                // Apply size and rotation
                for i in 0..<secondCube.count {
                    secondCube[i].startPoint *= size
                    secondCube[i].endPoint *= size
                }
                
                let rotationMatrixX = matrix_rotation(angle: rotationX * 0.0 + statefulRotationX, axis: SIMD3<Float>(x: 1, y: 0, z: 0))
                for i in 0..<secondCube.count {
                    secondCube[i] = secondCube[i].applyMatrix(rotationMatrixX)
                }
                
                let rotationMatrixY = matrix_rotation(angle: rotationY * 0.0 + statefulRotationY, axis: SIMD3<Float>(x: 0, y: 1, z: 0))
                for i in 0..<secondCube.count {
                    secondCube[i] = secondCube[i].applyMatrix(rotationMatrixY)
                }
                
                let rotationMatrixZ = matrix_rotation(angle: rotationZ * 0.0 + statefulRotationZ, axis: SIMD3<Float>(x: 0, y: 0, z: 1))
                for i in 0..<secondCube.count {
                    secondCube[i] = secondCube[i].applyMatrix(rotationMatrixZ)
                }
                
                let secondCubeRotation = matrix_rotation(angle: .pi * Float(delayedRotationFloat) * 0.1, axis: SIMD3<Float>(x: 1, y: 0, z: 0))
                let secondCubeRotationY = matrix_rotation(angle: .pi * Float(delayedRotationYFloat) * 0.1, axis: SIMD3<Float>(x: 0, y: 1, z: 0))
                let scalingMatrix = matrix_scale(scale: SIMD3<Float>(repeating: 1.0))
                
                var xTranslate: Float = 0.0
                if cubeCounts > 1 {
                    xTranslate = (cubeOuterTime - 0.5)
                }
                
                var yTranslate: Float = 0.0
                if innerCubeCounts > 1 {
                    yTranslate = (cubeInnerTime - 0.5)
                }
                
                let translateDelay = depthInputDelay.getHistoryValue(millisecondsAgo: 0)
                
                let delayedXTranslate = innerCubesSpreadXInput.getHistoryValue(
                    millisecondsAgo: Double(ensureValueIsFloat(
                        innerCubesSpreadXDelayInput.getHistoryValue(millisecondsAgo: 0))
                                            * cubeOuterTime * 1000
                                           )
                )
                
                let delayedInnerYTranslate = innerInnerCubesSpreadYInput.getHistoryValue(
                    millisecondsAgo: Double(ensureValueIsFloat(
                        innerInnerCubesSpreadYDelayInput.getHistoryValue(millisecondsAgo: 0))
                                            * cubeInnerTime * 1000
                                           )
                )
                
                var matrixTranslate = matrix_translation(translation: SIMD3<Float>(
                    xTranslate * ensureValueIsFloat(delayedXTranslate),
                    yTranslate * ensureValueIsFloat(delayedInnerYTranslate),
                    0.0
                ))
                
                
                let combinedMatrix = matrixTranslate * scalingMatrix * secondCubeRotation * secondCubeRotationY
                
                let colorTime = (Double(cubeTime) + Double(statefulColorShift)).truncatingRemainder(dividingBy: 1.0)
                
                for i in 0..<secondCube.count {
                    secondCube[i] = secondCube[i].applyMatrix(combinedMatrix)
                    secondCube[i].lineWidthStart = delayedLineWidthFloat
                    secondCube[i].lineWidthEnd = delayedLineWidthFloat
                    
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
                    let color = colorScale.color(at: Double(colorTime), brightness: Double(ensureValueIsFloat(brightnessValue))).toSIMD4()
                    secondCube[i] = secondCube[i].setBasicEndPointColors(
                        startColor: color,
                        endColor: color
                    )
                }
                
                lines += secondCube
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

