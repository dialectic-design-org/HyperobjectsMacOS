//
//  Day19_16x16.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 19/01/2026.
//

struct Day19_16x16: GenuaryDayGenerator {
    let dayNumber = "19"

    func generateLines(
        inputs: [String: Any],
        scene: GeometriesSceneBase,
        time: Double,
        lineWidthBase: Float,
        state: Genuary2026State
    ) -> (lines: [Line], replacementProbability: Float) {
        var outputLines: [Line] = []
        
        let black = SIMD4<Float>(0.0, 0.0, 0.0, 1.0)
        
        let tFloat = Float(time) * 0.25
        
        let brightnessInput = scene.getInputWithName(name: "Brightness")
        
        for i in 1...16 {
            for j in 1...16 {
                let i_t = Float(i) / 16.0
                let j_t = Float(j) / 16.0
                let i_t2pi = i_t * Float.pi * 2
                let j_t2pi = j_t * Float.pi * 2
                
                var cubeLines = Cube(center: .zero, size: 0.1).wallOutlines()
                
                // Dynamic Spin: The whole ring rotates over time
                let spinAngle = tFloat * 0.2
                // Twist: Different indices (j) rotate at different speeds/directions (vortex effect)
                let twistAngle = sin(Float(j) * 0.3 + tFloat * 0.5) * 0.8
                
                let rotMatZ = matrix_rotation(angle: Float(i) * Float.pi * 0.125 + spinAngle + twistAngle, axis: SIMD3<Float>(0.0, 0.0, 1.0))
                
                var tFloatSin0_35: Double = Double((sin(tFloat * 0.35) + 1.0) * 0.5)
                var tFloatSin0_12: Double = Double((sin(tFloat * 0.12) + 1.0) * 0.5)
                
                var i_t_j_t = Double(i_t + j_t)
                var WidthMilAgo = i_t_j_t * (100.0 + tFloatSin0_35 * 600.0)
                var HeightMilAgo = i_t_j_t * (100.0 + tFloatSin0_12 * 1200.0)
                let widthInputHistoryValue = ensureValueIsFloat(
                    brightnessInput.getHistoryValue(millisecondsAgo: WidthMilAgo))
                let heightInputHistoryValue = ensureValueIsFloat(brightnessInput.getHistoryValue(millisecondsAgo: HeightMilAgo))
                
                // Scale pulses faster and more significantly
                var sMat = matrix_scale(scale: SIMD3<Float>(
                    (sin(j_t2pi * 2.0 + tFloat * 1.5) + 1.2) * 0.5,
                    (cos(j_t2pi * 3.0 + tFloat * 0.7) + 1.2) * 0.5 * 1.7,
                    sin(i_t2pi * 8.0 + tFloat * 1.0) * 0.15 + widthInputHistoryValue * 2.0
                ))
                
                // Radial pulse and positioning
                let radiusC = 0.35 * sin(j_t2pi + tFloat * 0.8) // Faster radial breathing
                let angleC = i_t2pi + spinAngle
                
                let tMatI = matrix_translation(translation: SIMD3<Float>(
                    sin(angleC) * radiusC,
                    cos(angleC) * radiusC,
                    -0.8)
                )
                
                let tMatJ = matrix_translation(translation: SIMD3<Float>(
                    0.0,
                    0.0,
                    sin(j_t * Float.pi * 4 + tFloat * 0.8 + cos(i_t2pi)) * 0.5 // Deeper Z waves
                ))
                
                let rotMatAfterY = matrix_rotation(angle: sin(tFloat * 0.1) * 0.2, axis: SIMD3<Float>(0.0, 1.0, 0.0))
                let rotMatAfterX = matrix_rotation(angle: cos(tFloat * 0.15) * 0.2, axis: SIMD3<Float>(1.0, 0.0, 0.0))
                let rotMatAfterAll = rotMatAfterX * rotMatAfterY
                
                let finalScale = matrix_scale(scale: SIMD3<Float>(repeating: 5.0))
                
                // Added rotMatAfterAll to the chain for global tumbling
                let totalMat = finalScale * rotMatAfterAll * tMatI * tMatJ * rotMatZ * sMat
                
                // Palette: Red -> Pink -> Dark Blue -> Light Blue
                // Oscillates through these colors based on position and time
                let tOsc = (sin(i_t2pi + j_t2pi * 0.5 + tFloat * 0.6) + 1.0) * 1.5 // Range 0.0 ... 3.0
                
                let cRed    = SIMD4<Float>(1.0, 0.2, 0.3, 1.0)
                let cPink   = SIMD4<Float>(1.0, 0.4, 0.8, 1.0)
                let cDkBlue = SIMD4<Float>(0.1, 0.2, 0.7, 1.0)
                let cLtBlue = SIMD4<Float>(0.3, 0.9, 1.0, 1.0)
                
                var lColor: SIMD4<Float>
                if tOsc < 1.0 {
                    let t = tOsc
                    lColor = cRed + (cPink - cRed) * t
                } else if tOsc < 2.0 {
                    let t = tOsc - 1.0
                    lColor = cPink + (cDkBlue - cPink) * t
                } else {
                    let t = min(tOsc - 2.0, 1.0)
                    lColor = cDkBlue + (cLtBlue - cDkBlue) * t
                }
                
                // Depth-based saturation adjustment
                // Calculate approximate Z depth from the transformation matrix
                let zPos = totalMat.columns.3.z
                
                // Map Z to saturation (Closer/Higher Z -> More Saturated, Further/Lower Z -> Less Saturated)
                // Assuming roughly -2.0 (close) to -8.0 (far) range
                let satNorm = (zPos + 8.0) / 6.0
                let saturation = max(0.0, min(1.2, satNorm)) // Allow slight oversaturation for closest
                
                // Desaturate distant objects
                let luminance = lColor.x * 0.299 + lColor.y * 0.587 + lColor.z * 0.114
                let cGray = SIMD4<Float>(luminance, luminance, luminance, lColor.w)
                
                lColor = cGray + (lColor - cGray) * saturation
                
                // Sharp brightness pulse based on Width input history
                // We reuse i_t and j_t to create a wave of brightness that travels through the grid
                let pulseDelay = Double(i_t + j_t) * 300.0 + Double(cos(tFloat)) * 200.0 // 300ms spread across the grid
                let rawPulse = ensureValueIsFloat(brightnessInput.getHistoryValue(millisecondsAgo: pulseDelay))
                
                let rawPulseTwo = ensureValueIsFloat(brightnessInput.getHistoryValue(millisecondsAgo: pulseDelay * cos(Double(tFloat) * 0.5)))
                // Raise to power for sharpness, maximize to clamp negative values (though history is usually 0-1)
                let pulseAmt = pow(max(0.0, rawPulse), 5.0) * 2.0
                let pulseAmtTwo = pow(max(0.0, rawPulseTwo), 5.0) * 2.0
                
                lColor += SIMD4<Float>(pulseAmtTwo, pulseAmt, pulseAmt, 0.0)
                
                for l_i in cubeLines.indices {
                    cubeLines[l_i] = cubeLines[l_i].applyMatrix(totalMat)
                    cubeLines[l_i] = cubeLines[l_i].setBasicEndPointColors(startColor: lColor, endColor: lColor)
                    cubeLines[l_i].lineWidthStart = lineWidthBase * 0.5 + pulseAmt
                    cubeLines[l_i].lineWidthEnd = lineWidthBase * 0.5 + pulseAmt
                }
                
                outputLines.append(contentsOf: cubeLines)
            }
        }
        
        let prop = ensureValueIsFloat(brightnessInput.getHistoryValue(millisecondsAgo: 0.0))
        
        return (outputLines, prop) // default replacement probability
    }
}
