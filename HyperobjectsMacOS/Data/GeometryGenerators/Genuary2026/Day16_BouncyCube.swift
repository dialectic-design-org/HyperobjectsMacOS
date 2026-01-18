//
//  Day16_BouncyCube.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 18/01/2026.
//

struct Day16_BouncyCube: GenuaryDayGenerator {
    let dayNumber = "16"

    func generateLines(
        inputs: [String: Any],
        scene: GeometriesSceneBase,
        time: Double,
        lineWidthBase: Float,
        state: Genuary2026State
    ) -> (lines: [Line], replacementProbability: Float) {
        var outputLines: [Line] = []
        
        let deltaTime: Float = 1.0 / 100.0
        bouncyCubeSimulator.setOuterCubeRotation(SIMD3<Float>(
                sin(Float(time) * 0.05) * 4.0,
             Float(time) * 0.4,
             cos(Float(time) * 0.2) * 6.2
         ), deltaTime: deltaTime)
         
         // Advance physics
        bouncyCubeSimulator.tick(deltaTime: deltaTime)
         
         // Get state for rendering
         let innerState = bouncyCubeSimulator.getInnerCubeState()
         let outerOrientation = bouncyCubeSimulator.getOuterCubeOrientation()
         let innerOrientation = bouncyCubeSimulator.getInnerCubeOrientation()
        
        var outerCubeLines = Cube(center: .zero, size: bouncyOuterCubeSize).wallOutlines()
        var innerCubeLines = Cube(center: .zero, size: bouncyInnerCubeSize).wallOutlines()
        
        var totalScaling = matrix_scale(scale: SIMD3<Float>(repeating: bouncyCubeRenderScale))
        let innerTranslation = matrix_translation(translation: innerState.center)
        
        // Calculate neon color based on physics
        let linearSpeed = simd_length(innerState.velocity)
        let angularSpeed = simd_length(innerState.angularVelocity)
        
        // Factors to tune sensitivity
        let linearFactor = min(1.0, linearSpeed * 0.08)
        let angularFactor = min(1.0, angularSpeed * 0.15)
        
        // Base dark, add Green (Angular) and Blue (Linear)
        // Green: (0.1, 1.0, 0.1) | Blue: (0.1, 0.4, 1.0)
        let r: Float = 0.1
        let g: Float = 0.1 + angularFactor * 0.9
        let b: Float = 0.1 + linearFactor * 0.9
        
        let innerColor = SIMD4<Float>(r, g, b, 1.0)
        
        
        let outerCubeLinesColor: SIMD4<Float> = SIMD4<Float>(0.2, 0.2, 0.2, 1.0)
        
        for i in outerCubeLines.indices {
            outerCubeLines[i] = outerCubeLines[i].applyMatrix(matrix_float4x4(outerOrientation))
            outerCubeLines[i] = outerCubeLines[i].applyMatrix(totalScaling)
            outerCubeLines[i].lineWidthStart = lineWidthBase
            outerCubeLines[i].lineWidthEnd = lineWidthBase
            outerCubeLines[i] = outerCubeLines[i].setBasicEndPointColors(startColor: outerCubeLinesColor, endColor: outerCubeLinesColor)
        }
        
        for i in innerCubeLines.indices {
            innerCubeLines[i] = innerCubeLines[i].setBasicEndPointColors(startColor: innerColor, endColor: innerColor)
            innerCubeLines[i] = innerCubeLines[i].applyMatrix(matrix_float4x4(innerOrientation))
            innerCubeLines[i] = innerCubeLines[i].applyMatrix(innerTranslation)
            innerCubeLines[i] = innerCubeLines[i].applyMatrix(totalScaling)
            innerCubeLines[i].lineWidthStart = lineWidthBase + lineWidthBase * linearSpeed * 0.5
            innerCubeLines[i].lineWidthEnd = lineWidthBase + lineWidthBase * linearSpeed * 0.5
        }
        
        outputLines.append(contentsOf: outerCubeLines)
        outputLines.append(contentsOf: innerCubeLines)
        
        return (outputLines, 0.0) // default replacement probability
    }
}
