//
//  Day01_Cube.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 18/01/2026.
//

struct Day01_Cube: GenuaryDayGenerator {
    let dayNumber = "1"

    func generateLines(
        inputs: [String: Any],
        scene: GeometriesSceneBase,
        time: Double,
        lineWidthBase: Float,
        state: Genuary2026State
    ) -> (lines: [Line], replacementProbability: Float) {
        var outputLines = makeCube(size: 0.52, offset: 0)
        
        // tLine = tLine.applyMatrix(scaleMatrix)
        // tLine = tLine.applyMatrix(rotationMatrixXYZ)
        
        return (outputLines, 0.0) // default replacement probability
    }
}
