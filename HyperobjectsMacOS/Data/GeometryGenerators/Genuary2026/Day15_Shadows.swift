//
//  Day15_Shadows.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 18/01/2026.
//

struct Day15_Shadows: GenuaryDayGenerator {
    let dayNumber = "15"

    func generateLines(
        inputs: [String: Any],
        scene: GeometriesSceneBase,
        time: Double,
        lineWidthBase: Float,
        state: Genuary2026State
    ) -> (lines: [Line], replacementProbability: Float) {        
        
        let innerCubeRotation = SIMD3<Float>(
            Float(time * 0.05),
            Float(time * 0.15),
            Float(time * 0.06)
        )
        
        var outerCubeRotation = SIMD3<Float>(
            Float(time * 0.125),
            Float(time * 0.135),
            Float(time * 0.055)
        )
        outerCubeRotation = SIMD3<Float>(repeating: 0.0)
        
        let innerCubeSize:Float = 0.6
        let outerCubeSize:Float = 1.2
        
        let projectedLinesPoints = projectedCubeLines(
            innerRotation: innerCubeRotation,
            outerRotation: outerCubeRotation,
            innerSize: innerCubeSize,
            outerSize: outerCubeSize)
        
        var totalProjectedLines: [Line] = []
        for outputLine in projectedLinesPoints {
            totalProjectedLines.append(Line(
                startPoint: outputLine.0,
                endPoint: outputLine.1
            ))
        }
        
        var rotationX = matrix_rotation(angle: Float(time * 0.025), axis: SIMD3<Float>(1.0, 0.0, 0.0))
        var rotationY = matrix_rotation(angle: Float(time * 0.015), axis: SIMD3<Float>(0.0, 1.0, 0.0))
        var rotationZ = matrix_rotation(angle: Float(time * 0.02), axis: SIMD3<Float>(0.0, 0.0, 1.0))
        var totalRotation = rotationZ * rotationY * rotationX
        
        for i in totalProjectedLines.indices {
            totalProjectedLines[i] = totalProjectedLines[i].applyMatrix(totalRotation)
            totalProjectedLines[i].lineWidthStart = lineWidthBase
            totalProjectedLines[i].lineWidthEnd = lineWidthBase
        }
        
        
        return (totalProjectedLines, 0.0) // default replacement probability
    }
}
