//
//  Day24_Perfectionist.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 24/01/2026.
//

struct Day24_Perfectionist: GenuaryDayGenerator {
    let dayNumber = "24"
    
    

    func generateLines(
        inputs: [String: Any],
        scene: GeometriesSceneBase,
        time: Double,
        lineWidthBase: Float,
        state: Genuary2026State
    ) -> (lines: [Line], replacementProbability: Float) {
        var outputLines: [Line] = []
        
        var colorPalette: [SIMD4<Float>] = [
            SIMD4<Float>(0.647, 0.165, 0.165, 1.0), // Deep Terracotta
            SIMD4<Float>(0.850, 0.500, 0.150, 1.0), // Vibrant Pumpkin
            SIMD4<Float>(0.910, 0.720, 0.250, 1.0), // Golden Maize
            SIMD4<Float>(0.333, 0.420, 0.184, 1.0), // Olive Green
            SIMD4<Float>(0.250, 0.150, 0.100, 1.0)  // Rich Brown
        ]
        
        let edges = perspectiveTrickCubeEdges(
            cubeSize: 0.3,
            cameraPosition: SIMD3<Float>(0, 0, 1.7320508),
            amplitude: 0.2 + sin(Float(time * 0.023)) * 0.1,
            gradientDirection: SIMD3<Float>(1, 1, 0),  // diagonal oscillation
            frequency: 4.0 + sin(Float(time * 0.223)) * 2
        )
        
        var rotationMatrix = matrix_rotation(angle: Float(time * 0.1), axis: SIMD3<Float>(0.0, 1.0, 0.0))
        
        
        for edge in edges {
            var l = Line(
                startPoint: edge.0,
                endPoint: edge.1
            )
            l.setBasicEndPointColors(
                startColor: colorPalette[1],
                endColor: colorPalette[1]
            )
            
            l.lineWidthStart = lineWidthBase * 2
            l.lineWidthEnd = lineWidthBase * 2
            
            l = l.applyMatrix(rotationMatrix)
            
            outputLines.append(l)
        }
        
        let edges2 = perspectiveTrickCubeEdges(
            cubeSize: 0.5,
            cameraPosition: SIMD3<Float>(0, 0, 1.7320508),
            amplitude: 0.2,
            gradientDirection: SIMD3<Float>(1, 0, 1),  // diagonal oscillation
            frequency: 6.0 + sin(Float(time * 0.123)) * 0.3
        )
        
        var rotationMatrix2 = matrix_rotation(angle: Float(-time * 0.1), axis: SIMD3<Float>(0.0, 1.0, 0.0))
        
        
        for edge in edges2 {
            var l = Line(
                startPoint: edge.0,
                endPoint: edge.1
            )
            
            l.setBasicEndPointColors(
                startColor: colorPalette[2],
                endColor: colorPalette[2]
            )
            
            l.lineWidthStart = lineWidthBase * 2
            l.lineWidthEnd = lineWidthBase * 2
            
            l = l.applyMatrix(rotationMatrix2)
            
            outputLines.append(l)
        }
        
        let edges3 = perspectiveTrickCubeEdges(
            cubeSize: 0.7,
            cameraPosition: SIMD3<Float>(0, 0, 1.7320508),
            amplitude: 0.3 + sin(Float(time * 0.733)) * 0.15,
            gradientDirection: SIMD3<Float>(1, 0, 1),  // diagonal oscillation
            frequency: 6.0 + cos(Float(time * 0.523)) * 0.2
        )
        
        var rotationMatrix3 = matrix_rotation(angle: Float(time * 0.05), axis: SIMD3<Float>(0.0, 1.0, 0.0))
        
        
        for edge in edges3 {
            var l = Line(
                startPoint: edge.0,
                endPoint: edge.1
            )
            
            l.setBasicEndPointColors(
                startColor: colorPalette[3],
                endColor: colorPalette[3]
            )
            
            l.lineWidthStart = lineWidthBase * 2
            l.lineWidthEnd = lineWidthBase * 2
            
            l = l.applyMatrix(rotationMatrix3)
            
            outputLines.append(l)
        }
        
        let edges4 = perspectiveTrickCubeEdges(
            cubeSize: 0.9,
            cameraPosition: SIMD3<Float>(0, 0, 1.7320508),
            amplitude: 0.3 + sin(Float(time * 0.333)) * 0.2,
            gradientDirection: SIMD3<Float>(0, 1, 1),  // diagonal oscillation
            frequency: 5.0 + cos(Float(time * 0.223)) * 0.2
        )
        
        var rotationMatrix4 = matrix_rotation(angle: Float(-time * 0.05), axis: SIMD3<Float>(0.0, 1.0, 0.0))
        
        
        for edge in edges4 {
            var l = Line(
                startPoint: edge.0,
                endPoint: edge.1
            )
            
            l.setBasicEndPointColors(
                startColor: colorPalette[4],
                endColor: colorPalette[4]
            )
            
            l.lineWidthStart = lineWidthBase * 2
            l.lineWidthEnd = lineWidthBase * 2
            
            l = l.applyMatrix(rotationMatrix4)
            
            outputLines.append(l)
        }
        
        
        
        return (outputLines, 0.005) // default replacement probability
    }
}
