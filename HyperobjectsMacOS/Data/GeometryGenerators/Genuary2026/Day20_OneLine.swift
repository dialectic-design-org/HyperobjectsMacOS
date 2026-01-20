//
//  Day20_OneLine.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 20/01/2026.
//

struct Day20_OneLine: GenuaryDayGenerator {
    let dayNumber = "20"

    func generateLines(
        inputs: [String: Any],
        scene: GeometriesSceneBase,
        time: Double,
        lineWidthBase: Float,
        state: Genuary2026State
    ) -> (lines: [Line], replacementProbability: Float) {
        var outputLines:[Line] = []
        
        var lineLength:Float = 0.5
        
        let tf = Float(time) * 0.1
        
        
        var outLine = Line(
            startPoint: SIMD3<Float>(-lineLength, 0.0, 0.0),
            endPoint: SIMD3<Float>(lineLength, 0.0, 0.0),
        )
        
        var preTranslateVec = SIMD3<Float>(
            0.0,
            0.0,
            0.0
        )
        
        var postTranslateVec = SIMD3<Float>(
            0.0,
            0.0,
            0.0
        )
        
        var rxAngle: Float = 0.0
        var ryAngle: Float = 0.0
        var rzAngle: Float = 0.0
        
        rxAngle += sin(tf * 0.1) * 2
        rxAngle += sin(tf * 0.25) * 3
        rxAngle += sin(tf * 0.5) * 4
        
        ryAngle += sin(tf * 0.15) * 4
        ryAngle += sin(tf * 0.35) * 3
        ryAngle += sin(tf * 0.2111) * 2
        
        rzAngle += sin(tf * 0.05) * 4
        rzAngle += sin(tf * 0.2) * 2
        rzAngle += sin(tf * 0.4) * 3
        
        var preTAmp:Float = 1.8
        var postTAmp:Float = 1.6
        
        // Apply complex wave functions to the pre-translation vector (internal offset)
        // Layer 1: Slow, large movements
        preTranslateVec.x += sin(tf * 0.15) * 0.10 * preTAmp
        preTranslateVec.y += cos(tf * 0.12) * 0.10 * preTAmp
        preTranslateVec.z += sin(tf * 0.18 + 1.0) * 0.10 * preTAmp

        // Layer 2: Medium frequency, medium amplitude
        preTranslateVec.x += sin(tf * 0.43) * 0.05 * preTAmp
        preTranslateVec.y += sin(tf * 0.37 + 2.0) * 0.05 * preTAmp
        preTranslateVec.z += cos(tf * 0.49) * 0.05 * preTAmp
        
        // Layer 3: High frequency "jitter"
        preTranslateVec.x += sin(tf * 1.5) * 0.01 * preTAmp
        preTranslateVec.y += cos(tf * 1.7) * 0.01 * preTAmp
        preTranslateVec.z += sin(tf * 1.3 + 3.0) * 0.01 * preTAmp

        // Apply distinct wave functions to the post-translation vector (global position)
        // Using harmonically unrelated frequencies to avoid synchronization
        postTranslateVec.x += sin(tf * 0.22) * 0.15 * postTAmp
        postTranslateVec.x += cos(tf * 0.55) * 0.08 * postTAmp
        
        postTranslateVec.y += sin(tf * 0.27 + 1.0) * 0.15 * postTAmp
        postTranslateVec.y += cos(tf * 0.63) * 0.08 * postTAmp
        
        postTranslateVec.z += sin(tf * 0.31 + 2.0) * 0.15 * postTAmp
        postTranslateVec.z += cos(tf * 0.71) * 0.08 * postTAmp
        
        
        
        
        
        
        
        var rxMat = matrix_rotation(angle: rxAngle, axis: SIMD3<Float>(1.0, 0.0, 0.0))
        var ryMat = matrix_rotation(angle: ryAngle, axis: SIMD3<Float>(0.0, 1.0, 0.0))
        var rzMat = matrix_rotation(angle: rzAngle, axis: SIMD3<Float>(0.0, 0.0, 1.0))
        
        var preTranslate = matrix_translation(translation: preTranslateVec)
        var postTranslate = matrix_translation(translation: postTranslateVec)
        
        
        
        var fullMat = postTranslate * rzMat * ryMat * rxMat * preTranslate
        outLine = outLine.applyMatrix(fullMat)
        outLine.lineWidthStart = lineWidthBase * 200
        outLine.lineWidthEnd = lineWidthBase * 200
        
        
        // Vibrant Jade & Complementary Pink Palette
        // Consistent artistic colors with slight animation
        let cJade = SIMD3<Float>(0.0, 0.85, 0.6)   // Bright Jade/Teal
        let cPink = SIMD3<Float>(0.9, 0.1, 0.45)   // Magenta/Deep Pink
        
        // Slight hue animation
        var currentJade = cJade
        currentJade.z += sin(tf * 0.7) * 0.15      // Pulse Blue in Jade
        currentJade.y += cos(tf * 0.5) * 0.10      // Pulse Green
        
        var currentPink = cPink
        currentPink.x += sin(tf * 0.6) * 0.10      // Pulse Red in Pink
        currentPink.y += cos(tf * 0.8) * 0.05      // Slight green shift for richness
        
        // Gradient shift along the line
        let balance = sin(tf * 0.25) * 0.5 + 0.5
        
        // Line Start: Mostly Jade
        let sMix = 0.05 + balance * 0.15 
        let startRGB = currentJade + (currentPink - currentJade) * sMix
        
        // Line End: Mostly Pink
        let eMix = 0.80 + balance * 0.15
        let endRGB = currentJade + (currentPink - currentJade) * eMix
        
        let initialStartColor = SIMD4<Float>(startRGB, 1.0)
        let initialEndColor   = SIMD4<Float>(endRGB, 1.0)
        
        // Z-Depth saturation helper
        func adjustSaturation(_ color: SIMD4<Float>, z: Float) -> SIMD4<Float> {
             // Z range roughly -0.4 to +0.4.
             // Map Z to saturation: Front (+Z) saturated, Back (-Z) desaturated
             let normalizedZ = (z + 0.4) / 0.8 // 0...1
             let saturation = max(0.0, min(1.5, normalizedZ * 1.5))
             
             let lum = color.x * 0.299 + color.y * 0.587 + color.z * 0.114
             let gray = SIMD4<Float>(lum, lum, lum, color.w)
             return gray + (color - gray) * saturation
        }
        
        let sColor = adjustSaturation(initialStartColor, z: outLine.startPoint.z * 0.5 + 0.1)
        let eColor = adjustSaturation(initialEndColor, z: outLine.endPoint.z * 0.5 + 0.1)
        
        outLine = outLine.setBasicEndPointColors(startColor: sColor, endColor: eColor)
        
        // Add the main animated line
        outputLines = [outLine]

        // --- 3D Reference Grid ---
        // A full 3D cubic grid with white lines
        let gridColor = SIMD4<Float>(1.0, 1.0, 1.0, 0.5)
        let gridHighlight = SIMD4<Float>(1.0, 1.0, 1.0, 0.9)
        let gSize = 4 // -3 to 3
        let spacing: Float = 0.25
        let extent = Float(gSize) * spacing
        
        for i in -gSize...gSize {
            for j in -gSize...gSize {
                let u = Float(i) * spacing
                let v = Float(j) * spacing
                
                // Determine style (major lines on edges and center)
                let isMajor = (i % 3 == 0 || j % 3 == 0)
                let color = isMajor ? gridHighlight : gridColor
                let width = isMajor ? lineWidthBase * 1.0 : lineWidthBase * 0.2
                
                // Lines parallel to X-axis: fixed Y=u, Z=v
                var lineX = Line(
                    startPoint: SIMD3<Float>(-extent, u, v),
                    endPoint: SIMD3<Float>(extent, u, v)
                )
                lineX = lineX.setBasicEndPointColors(startColor: color, endColor: color)
                lineX.lineWidthStart = width; lineX.lineWidthEnd = width
                outputLines.append(lineX)
                
                // Lines parallel to Y-axis: fixed X=u, Z=v
                var lineY = Line(
                    startPoint: SIMD3<Float>(u, -extent, v),
                    endPoint: SIMD3<Float>(u, extent, v)
                )
                lineY = lineY.setBasicEndPointColors(startColor: color, endColor: color)
                lineY.lineWidthStart = width; lineY.lineWidthEnd = width
                outputLines.append(lineY)
                
                // Lines parallel to Z-axis: fixed X=u, Y=v
                var lineZ = Line(
                    startPoint: SIMD3<Float>(u, v, -extent),
                    endPoint: SIMD3<Float>(u, v, extent)
                )
                lineZ = lineZ.setBasicEndPointColors(startColor: color, endColor: color)
                lineZ.lineWidthStart = width; lineZ.lineWidthEnd = width
                outputLines.append(lineZ)
            }
        }
        return (outputLines, 0.0) // default replacement probability
    }
}
