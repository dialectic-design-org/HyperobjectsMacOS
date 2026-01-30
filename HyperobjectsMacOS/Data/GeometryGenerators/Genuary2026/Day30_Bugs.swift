//
//  Day30_Bugs.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 27/01/2026.
//

import simd

struct BugCubeState {
    var rotation: simd_quatf
    var driftAxis: SIMD3<Float>
    var driftSpeed: Float
}

class Day30_Bugs: GenuaryDayGenerator {
    let dayNumber = "30"
    
    private var lastTime: Double?
    private var cubeStates: [Int: BugCubeState] = [:]

    func generateLines(
        inputs: [String: Any],
        scene: GeometriesSceneBase,
        time: Double,
        lineWidthBase: Float,
        state: Genuary2026State
    ) -> (lines: [Line], replacementProbability: Float) {
        var outputLines: [Line] = []
        
        var cubesNr: Int = 4
        
        var brightness = scene.getInputWithName(name: "Brightness")
        
        var tf = Float(time)
        
        let currentStateLastTime = lastTime ?? time
        let dt = Float(max(0.0, time - currentStateLastTime))
        self.lastTime = time
        
        for i in 0..<cubesNr {
            var t = Double(i) / Double(cubesNr)
            var t_inv = 1.0 - t
            
            // --- State Update Logic ---
            var bugState = cubeStates[i] ?? BugCubeState(
                rotation: simd_quatf(angle: 0.0, axis: SIMD3<Float>(0, 1, 0)),
                driftAxis: normalize(SIMD3<Float>(Float.random(in: -1...1), Float.random(in: -1...1), Float.random(in: -1...1))),
                driftSpeed: Float.random(in: 0.1...0.5)
            )
            
            let currentBrightness = ensureValueIsFloat(brightness.getHistoryValue(millisecondsAgo: 0))
            
            // Randomly change direction based on brightness
            if Float.random(in: 0...1) < currentBrightness * 0.5 * dt {
                bugState.driftAxis = normalize(SIMD3<Float>(Float.random(in: -1...1), Float.random(in: -1...1), Float.random(in: -1...1)))
            }
            
            // Randomly change orientation based on brightness (less likely)
            if Float.random(in: 0...1) < currentBrightness * 0.1 * dt {
                 bugState.rotation = simd_quatf(angle: Float.random(in: 0...Float.pi*2), axis: normalize(SIMD3<Float>(Float.random(in: -1...1), Float.random(in: -1...1), Float.random(in: -1...1))))
            }
            
            // Apply drift
            let deltaRot = simd_quatf(angle: bugState.driftSpeed * dt, axis: bugState.driftAxis)
            bugState.rotation = bugState.rotation * deltaRot
            
            cubeStates[i] = bugState
            // --------------------------
            
            var cubeLines = Cube(center: .zero, size: 1.0).wallOutlines()
            
            let valX = ensureValueIsFloat(brightness.getHistoryValue(millisecondsAgo: t * 250))
            let valY = ensureValueIsFloat(brightness.getHistoryValue(millisecondsAgo: 100 + t * 82))
            let valZ = ensureValueIsFloat(brightness.getHistoryValue(millisecondsAgo: t_inv * 300))

            // -- Crazy Geometry Logic --
            
            // 1. Warping Scale
            // High modulation depth + base scale increase + explosive multiplier on hits
            // Slowly breathes over time
            // Break down complex expression for compiler
            let breathingBaseFreq = tf * 0.25
            
            // Retrieve deep history value for modulation
            let historyTime = Double(tf) * 500.0
            let deepHistoryMod = ensureValueIsFloat(brightness.getHistoryValue(millisecondsAgo: historyTime))
            
            // Calculate phase shift combining unit position 't' and audio mod
            let breathingPhase = (Float(t) + deepHistoryMod) * 3.0
            
            let slowBreath = sin(breathingBaseFreq + breathingPhase) * 0.3
            let explosiveMult = (1.0 + valX * 2.0) * (1.0 + slowBreath)
            
            let scaleX = computeComponentScale(intensity: valX, time: tf, frequency: 0.5, phase: Float(t), baseScale: 0.2, modulationDepth: 2.5) * explosiveMult
            let scaleY = computeComponentScale(intensity: valY, time: tf, frequency: 1.1, phase: Float(t) * 1.5, baseScale: 0.2, modulationDepth: 2.5) * explosiveMult
            let scaleZ = computeComponentScale(intensity: valZ, time: tf, frequency: 0.321, phase: Float(t) * 2.0, baseScale: 0.2, modulationDepth: 2.5) * explosiveMult
            
            let s_m = matrix_scale(scale: SIMD3<Float>(scaleX, scaleY, scaleZ))
            
            // 2. Structured Orbital Flow
            // They form a coherent structure that expands and contracts
            let formationRadius = 0.4 + valY * 2.2

            // Arrange in a spiral cylinder
            let angle = tf * 0.4 + (Float(i) / Float(cubesNr)) * Float.pi * 2.0
            
            let posX = cos(angle) * formationRadius
            let posY = sin(angle) * formationRadius
            
            // Z spreads them out, but they oscillate together
            let baseZ = 1.0 - Float(t) * 3.0
            let beatZ = sin(tf + Float(i) * 0.5) * valX * 1.5 // Wave-like reaction
            let posZ = baseZ + beatZ
            
            let t_m = matrix_translation(translation: SIMD3<Float>(posX, posY, posZ))
            
            // 3. Structural Rotation
            let r_state = matrix_float4x4(bugState.rotation)
            
            // Axis that points from center to cube
            let radialAxis = normalize(SIMD3<Float>(posX, posY, 0))
            // Rotate around the radial axis (tumbling outwards)
            let r_added = matrix_rotation(angle: valX * Float.pi * 4.0 + tf, axis: radialAxis)
            
            let r_m = r_added * r_state
            
            let t2_m = matrix_translation(translation: SIMD3<Float>(0.0, 0.0, -2.5))
            
            let total_m = t2_m * t_m * r_m * s_m
            
            // --- Color & Style Logic ---
            let hueBase = Float(time * 20.0).truncatingRemainder(dividingBy: 360.0) + Float(i) * 90.0
            
            for j in cubeLines.indices {
                let lineT = Float(j) / Float(cubeLines.count)
                
                // Drift colors excessively based on brightness inputs (valX, valY, valZ)
                let hueStart = hueBase + lineT * 60.0 + valX * 150.0
                let hueEnd = hueStart + 30.0 + valY * 50.0
                
                // Chroma "pops" with audio
                let chromaStart = 0.15 + valY * 0.35 + abs(sin(Float(time) + lineT)) * 0.1
                let chromaEnd = 0.15 + valZ * 0.35
                
                // Lightness pulses
                let lightnessStart = 0.4 + valZ * 0.5 + sin(Float(time) * 3.0 + lineT * 2.0) * 0.2
                let lightnessEnd = 0.4 + valX * 0.5 + cos(Float(time) * 2.5 + lineT * 3.0) * 0.2
                
                let colorStart = OKLCH(L: min(0.99, max(0.01, lightnessStart)), C: chromaStart, H: hueStart).simd
                let colorEnd = OKLCH(L: min(0.99, max(0.01, lightnessEnd)), C: chromaEnd, H: hueEnd).simd
                
                cubeLines[j] = cubeLines[j].setBasicEndPointColors(startColor: colorStart, endColor: colorEnd)
                
                // Dynamic line width
                cubeLines[j].lineWidthStart = lineWidthBase * (0.8 + valX * 6.0)
                cubeLines[j].lineWidthEnd = lineWidthBase * (0.8 + valY * 6.0)
                
                cubeLines[j] = cubeLines[j].applyMatrix(total_m)
            }
            
            outputLines.append(contentsOf: cubeLines)
        }
    
        return (outputLines, ensureValueIsFloat(brightness.getHistoryValue(millisecondsAgo: 0))) // default replacement probability
    }

    func computeComponentScale(
        intensity: Float,
        time: Float,
        frequency: Float,
        phase: Float,
        baseScale: Float = 0.1,
        modulationDepth: Float = 0.5
    ) -> Float {
        return baseScale + intensity * (1.0 + sin(time * frequency + phase)) * modulationDepth
    }
}
