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

// MARK: - Supporting Classes for Simulation

class FishAgent {
    var id: Int
    var position: SIMD3<Float>
    var velocity: SIMD3<Float>
    var acceleration: SIMD3<Float>
    var currentMaxSpeed: Float = 3.0
    
    init(id: Int, position: SIMD3<Float>, velocity: SIMD3<Float>) {
        self.id = id
        self.position = position
        self.velocity = velocity
        self.acceleration = SIMD3<Float>(0, 0, 0)
    }
}

class FishSchoolSimulation {
    static let shared = FishSchoolSimulation()
    
    var agents: [FishAgent] = []
    var isInitialized = false
    
    // Bounds
    let boundarySize: Float = 8.0
    
    func initialize(count: Int) {
        agents.removeAll()
        for i in 0..<count {
            let pos = SIMD3<Float>(
                Float.random(in: -boundarySize/3...boundarySize/3),
                Float.random(in: -boundarySize/3...boundarySize/3),
                Float.random(in: -boundarySize/3...boundarySize/3)
            )
            let vel = normalize(SIMD3<Float>(
                Float.random(in: -1...1),
                Float.random(in: -1...1),
                Float.random(in: -1...1)
            )) * 2.0
            
            agents.append(FishAgent(id: i, position: pos, velocity: vel))
        }
        isInitialized = true
    }
    
    func update(dt: Float, time: Double, brightnessInput: SceneInput?) {
        // Dynamic Parameters based on time
        let perceptionRadius: Float = 2.5 + sin(Float(time) * 0.3) * 0.5
        let separationWeight: Float = 1.8
        let alignmentWeight: Float = 1.2
        let cohesionWeight: Float = 1.0 + cos(Float(time) * 0.4) * 0.5
        
        // Tuned for lower base speed and distinct gaps in automatic pulses
        // sin(time * 0.5) > 0.5 happens for 1/3 of the cycle, creating a long gap.
        let autoPulse = max(0.0, sin(Float(time) * 0.5) - 0.5)
        let baseMaxSpeed: Float = 0.5 + autoPulse * 3.0 
        let maxForce: Float = 0.2 // Increased steer force for better reaction to audio spikes
        
        // Snapshot current state for updates
        let currentAgents = agents
        
        for agent in agents {
            // Brightness Delay Logic
            var addedSpeed: Float = 0.0
            if let input = brightnessInput {
                let delay = Double(agent.id) * 30.0 // 30ms delay per index
                let val = input.getHistoryValue(millisecondsAgo: delay)
                if let v = val as? Float { addedSpeed = v }
                else if let v = val as? Double { addedSpeed = Float(v) }
                else if let v = val as? Int { addedSpeed = Float(v) }
            }
            
            agent.currentMaxSpeed = baseMaxSpeed + addedSpeed * 8.0
            let maxSpeed = agent.currentMaxSpeed

            var separation = SIMD3<Float>(0, 0, 0)
            var alignment = SIMD3<Float>(0, 0, 0)
            var cohesion = SIMD3<Float>(0, 0, 0)
            var neighborCount = 0
            
            for other in currentAgents {
                if agent.id == other.id { continue }
                
                let d = distance(agent.position, other.position)
                if d > 0 && d < perceptionRadius {
                    // Separation
                    let diff = invert(other.position - agent.position)
                    separation += normalize(diff) / d
                    
                    // Alignment
                    alignment += other.velocity
                    
                    // Cohesion
                    cohesion += other.position
                    
                    neighborCount += 1
                }
            }
            
            agent.acceleration = SIMD3<Float>(0, 0, 0)
            
            if neighborCount > 0 {
                // Average out
                separation /= Float(neighborCount)
                alignment /= Float(neighborCount)
                cohesion /= Float(neighborCount)
                
                // Steering for Separation
                if length(separation) > 0 {
                    separation = normalize(separation) * maxSpeed - agent.velocity
                    separation = limit(separation, max: maxForce)
                }
                
                // Steering for Alignment
                if length(alignment) > 0 {
                    alignment = normalize(alignment) * maxSpeed - agent.velocity
                    alignment = limit(alignment, max: maxForce)
                }
                
                // Steering for Cohesion
                // Determine direction to target
                let targetDir = cohesion - agent.position
                if length(targetDir) > 0 {
                    let desired = normalize(targetDir) * maxSpeed
                    cohesion = limit(desired - agent.velocity, max: maxForce)
                } else {
                    cohesion = SIMD3<Float>(0, 0, 0)
                }
            }
            
            // Boundary Force (Soft encapsulation)
            var boundaryForce = SIMD3<Float>(0, 0, 0)
            let distFromCenter = length(agent.position)
            if distFromCenter > boundarySize {
                let toCenter = -normalize(agent.position)
                boundaryForce = toCenter * maxForce * 2.0 // Strong urge to return center
            }
            
            // Apply Forces
            agent.acceleration += separation * separationWeight
            agent.acceleration += alignment * alignmentWeight
            agent.acceleration += cohesion * cohesionWeight
            agent.acceleration += boundaryForce
        }
        
        // Integration
        for agent in agents {
            agent.velocity += agent.acceleration
            agent.velocity = limit(agent.velocity, max: agent.currentMaxSpeed)
            agent.position += agent.velocity * dt
        }
    }
    
    private func limit(_ vec: SIMD3<Float>, max limitMag: Float) -> SIMD3<Float> {
        let len = length(vec)
        if len > limitMag && len > 0 {
            return (vec / len) * limitMag
        }
        return vec
    }
    
    private func invert(_ vec: SIMD3<Float>) -> SIMD3<Float> {
        return -vec
    }
}

// MARK: - Generator

struct Day25_Organic: GenuaryDayGenerator {
    let dayNumber = "25"

    func generateLines(
        inputs: [String: Any],
        scene: GeometriesSceneBase,
        time: Double,
        lineWidthBase: Float,
        state: Genuary2026State
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
        sim.update(dt: 0.05, time: time, brightnessInput: brightnessInput) // dt=0.05 makes it lively
        
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

