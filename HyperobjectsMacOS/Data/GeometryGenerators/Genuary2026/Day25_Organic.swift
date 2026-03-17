//
//  Day25_Organic.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 25/01/2026.
//




//
//  Day25_Organic.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 25/01/2026.
//

import simd
import AppKit

struct Day25_Organic: GenuaryDayGenerator {
    let dayNumber = "25"

    func generateLines(
        inputs: [String: Any],
        scene: GeometriesSceneBase,
        time: Double,
        lineWidthBase: Float
    ) -> (lines: [Line], replacementProbability: Float) {
        var outputLines: [Line] = []
        
        // 1. Initialize logic
        let sim = FishSchoolSimulation.shared
        if !sim.isInitialized {
            sim.initialize(count: 100)
        }
        
        var brightnessInput = scene.getInputWithName(name: "Brightness")
        
        // 2. Physics Step
        // Use a semi-fixed timestep assumption or just run once per generate call
        // sim.update(dt: 0.05, time: time, speedInput: brightnessInput) // dt=0.05 makes it lively
        
        // 3. Geometry Generation
        // Create a base cube to clone logic from
        // Center 0, 0, 0, size 1.0 (we will scale it)
        let baseCube = Cube(center: SIMD3<Float>(0, 0, 0), size: 1.0)
        let baseLines = baseCube.wallOutlines()
        
        // Pre-calculate up vector for look-at
        let up = SIMD3<Float>(0, 1, 0)
        
        let outputScale = matrix_scale(scale: SIMD3<Float>(repeating: 0.15))
        
        for agent in sim.agents {
            let speed = length(agent.velocity)
            let direction = speed > 0.001 ? normalize(agent.velocity) : SIMD3<Float>(0, 0, 1)
            
            // Build Rotation Matrix (LookAt)
            // Z-axis points in direction of velocity
            let zAxis = direction
            var xAxis = normalize(cross(up, zAxis))
            if length(xAxis) < 0.001 {
                // handle parallel case
                xAxis = SIMD3<Float>(1, 0, 0)
            }
            let yAxis = cross(zAxis, xAxis)
            
            let rotationMatrix = matrix_float4x4(
                columns: (
                    SIMD4<Float>(xAxis, 0),
                    SIMD4<Float>(yAxis, 0),
                    SIMD4<Float>(zAxis, 0),
                    SIMD4<Float>(0, 0, 0, 1)
                )
            )
            
            // Muscle / Deformation Logic
            // Strech based on speed ("Muscle Exertion")
            // Breathing / Pulse effect
            let pulse = 1.0 + sin(Float(time) * 4.0 + Float(agent.id)) * 0.1
            let lengthScale = (0.5 + speed * 0.2) * pulse
            let widthScale = (0.5 - speed * 0.05) * pulse // Conservation of volume-ish
            
            let scaleMatrix = matrix_float4x4(diagonal: SIMD4<Float>(widthScale, widthScale, lengthScale, 1.0))
            
            // Translation
            let translationMatrix = matrix_float4x4(
                columns: (
                    SIMD4<Float>(1, 0, 0, 0),
                    SIMD4<Float>(0, 1, 0, 0),
                    SIMD4<Float>(0, 0, 1, 0),
                    SIMD4<Float>(agent.position, 1)
                )
            )
            
            // Combine: T * R * S
            let finalMatrix = outputScale * translationMatrix * rotationMatrix * scaleMatrix
            
            // Color Logic: Slow Cycle + Chromatic Audio Brightness
            
            // 1. Base Gradient Cycle (Blue -> Purple -> Pink -> Yellow)
            // Cycle depends on time and agent ID for individuality
            let cycleT = (time * 0.2 + Double(agent.id) * 0.05).truncatingRemainder(dividingBy: 4.0)
            
            let blue = SIMD4<Float>(0.1, 0.2, 0.9, 1)
            let purple = SIMD4<Float>(0.5, 0.1, 0.9, 1)
            let pink = SIMD4<Float>(1.0, 0.2, 0.6, 1)
            let yellow = SIMD4<Float>(1.0, 0.9, 0.2, 1)
            
            var baseColor = blue
            let phase = Int(cycleT)
            let tMix = Float(cycleT.truncatingRemainder(dividingBy: 1.0))
            
            switch phase {
            case 0: baseColor = mix(blue, purple, t: tMix)
            case 1: baseColor = mix(purple, pink, t: tMix)
            case 2: baseColor = mix(pink, yellow, t: tMix)
            case 3: baseColor = mix(yellow, blue, t: tMix)
            default: baseColor = blue
            }
            
            // 2. Chromatic Audio Brightness
            // Different delays for R, G, B components to create chromatic aberration on transients
            // Normalized ID 0..1 assuming ~100 agents
            let normID = Double(agent.id) / 100.0
            
            func getFloat(_ val: Any?) -> Float {
                if let v = val as? Float { return v }
                if let v = val as? Double { return Float(v) }
                if let v = val as? Int { return Float(v) }
                return 0.0
            }
            
            let rDelay = normID * 50.0
            let gDelay = 35.0 + normID * 35.0
            let bDelay = 70.0 + normID * 50.0
            
            let rVal = getFloat(brightnessInput.getHistoryValue(millisecondsAgo: rDelay))
            let gVal = getFloat(brightnessInput.getHistoryValue(millisecondsAgo: gDelay))
            let bVal = getFloat(brightnessInput.getHistoryValue(millisecondsAgo: bDelay))
            
            let minLight: Float = 0.3
            let chromaticBrightness = SIMD4<Float>(
                rVal * 2.0 + minLight,
                gVal * 2.0 + minLight,
                bVal * 2.0 + minLight,
                1.0
            )
            
            var finalColor = baseColor * chromaticBrightness
            
            // Desaturate into dark gray on the darker side
            let luminance = dot(SIMD3<Float>(finalColor.x, finalColor.y, finalColor.z), SIMD3<Float>(0.299, 0.587, 0.114))
            let grayScale = SIMD4<Float>(luminance, luminance, luminance, 1.0)
            
            // Smoothly blend to gray when luminance is low
            // < 0.25 luminance -> fully gray, > 0.55 luminance -> fully colored
            let tSat = max(0.0, min(1.0, (luminance - 0.25) / 0.3))
            finalColor = mix(grayScale, finalColor, t: tSat)
            
            finalColor.w = 1.0

            // Apply to lines
            for line in baseLines {
                var transformedLine = line
                transformedLine = transformedLine.applyMatrix(finalMatrix)
                
                transformedLine.lineWidthStart = lineWidthBase
                transformedLine.lineWidthEnd = lineWidthBase
                
                // Apply color
                transformedLine.colorStart = finalColor
                transformedLine.colorEnd = finalColor
                transformedLine.colorStartOuterLeft = finalColor
                transformedLine.colorStartOuterRight = finalColor
                transformedLine.colorEndOuterLeft = finalColor
                transformedLine.colorEndOuterRight = finalColor
                
                outputLines.append(transformedLine)
            }
        }
        
        return (outputLines, ensureValueIsFloat(brightnessInput.getHistoryValue(millisecondsAgo: 0.0))) // default replacement probability
    }
}

