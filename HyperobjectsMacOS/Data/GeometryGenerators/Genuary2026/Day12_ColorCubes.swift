//
//  Day12_ColorCubes.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 18/01/2026.
//

struct Day12_ColorCubes: GenuaryDayGenerator {
    let dayNumber = "12"

    func generateLines(
        inputs: [String: Any],
        scene: GeometriesSceneBase,
        time: Double,
        lineWidthBase: Float,
        state: Genuary2026State
    ) -> (lines: [Line], replacementProbability: Float) {
        var cubesOutputLines: [Line] = []
        
        var rotationXMatrix = matrix_rotation(angle: Float(sin(time * 0.05)) * 0.25, axis: SIMD3<Float>(1.0, 0.0, 0.0))
        var rotationZMatrix = matrix_rotation(angle: Float(cos(time * 0.05 + Double.pi * 0.0)) * 0.25, axis: SIMD3<Float>(0.0, 1.0, 0.0))
        
        var redInput = scene.getInputWithName(name: "Red")
        let greenInput = scene.getInputWithName(name: "Green")
        let blueInput = scene.getInputWithName(name: "Blue")
        
        var totalCubesCount = 20
        var gDelay: Double = 35
        for i in 0...totalCubesCount {
            var t:Double = Double(Float(i) / Float(totalCubesCount))
            let r = ensureValueIsFloat(redInput.getHistoryValue(millisecondsAgo: t * 50))
            let g:Float = ensureValueIsFloat(greenInput.getHistoryValue(millisecondsAgo: gDelay - t * gDelay))
            let b = ensureValueIsFloat(blueInput.getHistoryValue(millisecondsAgo: t * 126))
            let brightness: Float = 1.0 // 0.8 + ensureValueIsFloat(brightnessInput.getHistoryValue(millisecondsAgo: t * 12)) * 0.2
            let strokeWidth: Float = 0.7 // ensureValueIsFloat(brightnessInput.getHistoryValue(millisecondsAgo: t * 11)) * 5.0
            
            var cubeColor =  SIMD4<Float>(
                r * brightness,
                g * brightness,
                b * brightness,
                r + g + b
            )
            
            var scalingMatrix = matrix_scale(scale: SIMD3<Float>(
                (sin(Float(t * Double.pi * 0.9 + time * 0.05) * 3.333) * 0.5 + 0.5) * 2,
                (cos(Float(t * Double.pi * 0.8 + time * 0.08) * 5.333) * 0.5 + 0.5) * 2,
                0.1
            ))
            
            var cubeSize:Float = Float(t) * 0.05 + 0.6
            cubeSize += r * 0.01
            cubeSize -= g * 0.05
            cubeSize += b * 0.01
            let cubePosition:SIMD3<Float> = SIMD3<Float>(
                0.0,
                0.0,
                (Float(t) - 0.5) * 1.0
            )
            let cube = Cube(center: cubePosition, size: cubeSize)
            var cubeLines = cube.wallOutlines()
            for j in cubeLines.indices {
                cubeLines[j] = cubeLines[j].applyMatrix(scalingMatrix)
                cubeLines[j] = cubeLines[j].setBasicEndPointColors(startColor: cubeColor, endColor: cubeColor)
                cubeLines[j].lineWidthStart = strokeWidth * lineWidthBase
                cubeLines[j].lineWidthEnd = strokeWidth * lineWidthBase
            }
            
            cubesOutputLines.append(contentsOf: cubeLines)
        }
        
        for i in cubesOutputLines.indices {
            cubesOutputLines[i] = cubesOutputLines[i].applyMatrix(rotationZMatrix)
            cubesOutputLines[i] = cubesOutputLines[i].applyMatrix(rotationXMatrix)
        }
        
        return (cubesOutputLines, 0.0) // default replacement probability
    }
}
