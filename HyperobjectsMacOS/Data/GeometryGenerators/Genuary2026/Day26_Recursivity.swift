//
//  Day26_Recursivity.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 25/01/2026.
//

struct Day26_Recursivity: GenuaryDayGenerator {
    let dayNumber = "26"

    func generateLines(
        inputs: [String: Any],
        scene: GeometriesSceneBase,
        time: Double,
        lineWidthBase: Float,
        state: Genuary2026State
    ) -> (lines: [Line], replacementProbability: Float) {
        var outputLines: [Line] = []
        
        var startingCube = Cube(center: .zero, size: 1.1)
        
        var brightness = scene.getInputWithName(name: "Brightness")
        
        
        var outlineLines: [Line] = []
        
        
        var rotationMatX = matrix_rotation(angle: sin(Float(time * 0.015)), axis: SIMD3<Float>(1.0, 0.0, 0.0))
        var rotationMatY = matrix_rotation(angle: sin(Float(time * 0.025)), axis: SIMD3<Float>(0.0, 1.0, 0.0))
        var rotationMatZ = matrix_rotation(angle: sin(Float(time * 0.055)), axis: SIMD3<Float>(0.0, 0.0, 1.0))
        
        var subDivisionCubes = recursiveSubdivide(cube: startingCube, input: brightness, depth: 0, maxDepth: 5)
        
        // Define two floating light points
        let lightPos1 = SIMD3<Float>(
            sin(Float(time) * 0.7) * 2.0,
            cos(Float(time) * 0.5) * 2.0,
            sin(Float(time) * 0.3) * 2.0
        )
        let lightColor1 = OKLCH(L: 0.65, C: 0.25, H: 25) // Deep Orange
        
        let lightPos2 = SIMD3<Float>(
            cos(Float(time) * 0.6) * 2.0,
            sin(Float(time) * 0.4) * 2.0,
            cos(Float(time) * 0.8) * 2.0
        )
        let lightColor2 = OKLCH(L: 0.9, C: 0.2, H: 85) // Bright Yellow
        
        for (index, item) in subDivisionCubes.enumerated() {
            let (originalCube, depth) = item
            var c = originalCube
            c.size *= 0.9
            
            var cOutlineLines = c.wallOutlines()
            
            // Calculate base material color based on index
            // Desert Sun Theme: Oscillate between Red (0) and Yellow (90)
            // Use time and index to create flowing waves of heat
            let wave = sin(Float(time) * 2.0 + Float(index) * 0.1)
            let baseHue = 45.0 + wave * 45.0 // Range 0...90
            let materialColor = OKLCH(L: 0.5, C: 0.2, H: baseHue)
            
            // Calculate delayed brightness for this cube
            // This creates a "sequenced" reaction to audio
            let audioDelay = Double(index) * 200.0
            let audioBrightness = Float(ensureValueIsFloat(brightness.getHistoryValue(millisecondsAgo: audioDelay))) - 0.5
            
            // Helper to calc color for a point
            func getColor(for point: SIMD3<Float>, depthRatio: Float) -> SIMD4<Float> {
                // Calculate influence of light 1
                let dist1 = distance(point, lightPos1)
                let influence1 = max(0, 1.0 - dist1 / 2.5) // Range 0-2.5
                
                // Calculate influence of light 2
                let dist2 = distance(point, lightPos2)
                let influence2 = max(0, 1.0 - dist2 / 2.5)
                
                // Blend colors
                var finalColor = materialColor
                
                // Absorb light 1
                if influence1 > 0 {
                    finalColor = finalColor.lerp(to: lightColor1, t: influence1 * 0.8)
                }
                // Absorb light 2
                if influence2 > 0 {
                    finalColor = finalColor.lerp(to: lightColor2, t: influence2 * 0.8)
                }
                
                // Modulate lightness with audio brightness
                // We add the brightness value to the L component
                finalColor.L += audioBrightness * 1.0
                
                // Slight depth modification for chroma/lightness
                finalColor.L += 0.1 * depthRatio
                finalColor.C += 0.05 * depthRatio
                
                // Clamp lightness
                finalColor.L = min(finalColor.L, 0.99)
                
                return finalColor.simd
            }
            
            let depthRatio = Float(depth) / 5.0
            
            for i in cOutlineLines.indices {
                // Calculate color individually for start and end point
                let startColor = getColor(for: cOutlineLines[i].startPoint, depthRatio: depthRatio)
                let endColor = getColor(for: cOutlineLines[i].endPoint, depthRatio: depthRatio)
                
                cOutlineLines[i] = cOutlineLines[i].setBasicEndPointColors(startColor: startColor, endColor: endColor)
                cOutlineLines[i].lineWidthStart = lineWidthBase * 0.8
                cOutlineLines[i].lineWidthEnd = lineWidthBase * 0.8
            }
            
            outlineLines.append(contentsOf: cOutlineLines)
        }
        
        
        
        var finalMat = rotationMatZ * rotationMatY * rotationMatX
        outputLines.append(contentsOf: outlineLines)
        for i in outputLines.indices {
            outputLines[i] = outputLines[i].applyMatrix(finalMat)
        }
        
        return (outputLines, ensureValueIsFloat(brightness.getHistoryValue(millisecondsAgo: 0.0)) * 0.2) // default replacement probability
    }
    
    
}
