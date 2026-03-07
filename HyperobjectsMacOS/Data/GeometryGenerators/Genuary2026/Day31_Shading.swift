//
//  Day31_Shading.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 27/01/2026.
//

struct Day31_Shading: GenuaryDayGenerator {
    let dayNumber = "31"
    



    func generateLines(
        inputs: [String: Any],
        scene: GeometriesSceneBase,
        time: Double,
        lineWidthBase: Float
    ) -> (lines: [Line], replacementProbability: Float) {
        var outputLines: [Line] = []
        
        var cubeLines: [Line] = Cube(center: .zero, size: 0.9).wallOutlines()
        
        var r_m = matrix_rotation(angle: Float(time), axis: SIMD3<Float>(0.0, 1.0, 0.0))
        
        var scalingVec = SIMD3<Float>(repeating: 1.0)
        
        if Float.random(in: 0.0...1.0) < 0.5 {
            let axisToScale: Int = Int.random(in: 0..<3)
            scalingVec[axisToScale] = Float.random(in: 0.0...1.0)
        }
        
        var s_m = matrix_scale(scale: scalingVec)
        
        
        var full_mat = r_m * s_m
        
        for i in cubeLines.indices {
            cubeLines[i] = cubeLines[i].applyMatrix(full_mat)
            cubeLines[i].lineWidthStart = lineWidthBase
            cubeLines[i].lineWidthEnd = lineWidthBase
        }
        
        outputLines.append(contentsOf: cubeLines)
        
        return (outputLines, 0.1) // default replacement probability
    }
}
