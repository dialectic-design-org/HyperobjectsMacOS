//
//  Day14_RubiksCube.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 18/01/2026.
//

struct Day14_RubiksCube: GenuaryDayGenerator {
    let dayNumber = "14"

    func generateLines(
        inputs: [String: Any],
        scene: GeometriesSceneBase,
        time: Double,
        lineWidthBase: Float,
        state: Genuary2026State
    ) -> (lines: [Line], replacementProbability: Float) {
        var outputLines: [Line] = []
        
        
        genuary2026r_cube.easingSteepness = 12
        genuary2026r_cube.holdRatio = 0.15
        
        genuary2026r_cube.updateAnimation(time: max(Float((time * 0.06).truncatingRemainder(dividingBy: 2.0)) - 0.4, 0.0) )

        let faceInsetFactor: Float = 0.94
        
        // "Weird red pink and yellow" palette
        // Easily swappable color scheme
        let cubePalette: [CubeColor: SIMD4<Float>] = [
            .white:  SIMD4<Float>(0.95, 0.90, 0.95, 1.0), // Pale Pinkish White
            .yellow: SIMD4<Float>(0.95, 1.00, 0.00, 1.0), // Acid Yellow
            .red:    SIMD4<Float>(1.00, 0.20, 0.35, 1.0), // Hot Pink/Red
            .orange: SIMD4<Float>(1.00, 0.40, 0.10, 1.0), // Vibrant Orange
            .blue:   SIMD4<Float>(0.20, 0.05, 0.60, 1.0), // Deep Purple (Contrast to Yellow)
            .green:  SIMD4<Float>(0.75, 0.95, 0.20, 1.0), // Toxic Green
            .none:   SIMD4<Float>(1.00, 0.50, 0.95, 1.0)  //
        ]
        
        var allCubeLines: [Line] = []
        
        for cubelet in genuary2026r_cube.cubelets {
            let matrix = cubelet.transformMatrix(cubeSize: 3.0)
             // Use matrix for rendering...
             
             // Get colors for each face
             for face in CubeFace.allCases {
                 let color = cubelet.colorOnWorldFace(face)
                 
                 // Create visual separation by insetting the face outlines
                 let spread: Float = 0.5 * faceInsetFactor
                 
                 var p1: SIMD3<Float> = .zero
                 var p2: SIMD3<Float> = .zero
                 var p3: SIMD3<Float> = .zero
                 var p4: SIMD3<Float> = .zero
                 
                 switch face {
                 case .front: // +Z
                     p1 = SIMD3<Float>(-spread, -spread, 0.5)
                     p2 = SIMD3<Float>( spread, -spread, 0.5)
                     p3 = SIMD3<Float>( spread,  spread, 0.5)
                     p4 = SIMD3<Float>(-spread,  spread, 0.5)
                 case .back: // -Z
                     p1 = SIMD3<Float>( spread, -spread, -0.5)
                     p2 = SIMD3<Float>(-spread, -spread, -0.5)
                     p3 = SIMD3<Float>(-spread,  spread, -0.5)
                     p4 = SIMD3<Float>( spread,  spread, -0.5)
                 case .right: // +X
                     p1 = SIMD3<Float>(0.5, -spread,  spread)
                     p2 = SIMD3<Float>(0.5, -spread, -spread)
                     p3 = SIMD3<Float>(0.5,  spread, -spread)
                     p4 = SIMD3<Float>(0.5,  spread,  spread)
                 case .left: // -X
                     p1 = SIMD3<Float>(-0.5, -spread, -spread)
                     p2 = SIMD3<Float>(-0.5, -spread,  spread)
                     p3 = SIMD3<Float>(-0.5,  spread,  spread)
                     p4 = SIMD3<Float>(-0.5,  spread, -spread)
                 case .up: // +Y
                     p1 = SIMD3<Float>(-spread, 0.5,  spread)
                     p2 = SIMD3<Float>( spread, 0.5,  spread)
                     p3 = SIMD3<Float>( spread, 0.5, -spread)
                     p4 = SIMD3<Float>(-spread, 0.5, -spread)
                 case .down: // -Y
                     p1 = SIMD3<Float>(-spread, -0.5, -spread)
                     p2 = SIMD3<Float>( spread, -0.5, -spread)
                     p3 = SIMD3<Float>( spread, -0.5,  spread)
                     p4 = SIMD3<Float>(-spread, -0.5,  spread)
                 }
                 
                 var faceLines: [Line] = [
                     Line(startPoint: p1, endPoint: p2),
                     Line(startPoint: p2, endPoint: p3),
                     Line(startPoint: p3, endPoint: p4),
                     Line(startPoint: p4, endPoint: p1)
                 ]
                 
                 let faceColorAsFloats = cubePalette[color] ?? SIMD4<Float>(1.0, 0.0, 1.0, 1.0)
                 
                 for i in faceLines.indices {
                     faceLines[i] = faceLines[i].setBasicEndPointColors(startColor: faceColorAsFloats, endColor: faceColorAsFloats)
                     faceLines[i].lineWidthStart = lineWidthBase * 4
                     faceLines[i].lineWidthEnd = lineWidthBase * 4
                     faceLines[i] = faceLines[i].applyMatrix(matrix)
                 }
                 
                 allCubeLines.append(contentsOf: faceLines)
             }
        }
        
        
        var totalCubeScaling = matrix_scale(scale: SIMD3<Float>(repeating: 0.3))
        
        
        var totalCubeXRotation = matrix_rotation(angle: Float(time * 0.111), axis: SIMD3<Float>(1.0, 0.0, 0.0))
        var totalCubeYRotation = matrix_rotation(angle: Float(time * 0.0518), axis: SIMD3<Float>(0.0, 1.0, 0.0))
        var totalCubeZRotation = matrix_rotation(angle: Float(time * 0.07), axis: SIMD3<Float>(0.0, 0.0, 1.0))
        
        var totalTransformation = totalCubeScaling * totalCubeZRotation * totalCubeYRotation * totalCubeXRotation
        
        
        for i in allCubeLines.indices { allCubeLines[i] = allCubeLines[i].applyMatrix(totalTransformation)}
        
        outputLines.append(contentsOf: allCubeLines)
        
        return (outputLines, 0.01) // default replacement probability
    }
}
