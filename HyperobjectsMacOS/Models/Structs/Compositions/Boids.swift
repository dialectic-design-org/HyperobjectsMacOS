//
//  Boids.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 15/03/2026.
//


// MARK: - Supporting Classes for Simulation

class FishAgent {
    var id: Int
    var position: SIMD3<Float>
    private(set) var positionHistory: [SIMD3<Float>] = []
    var velocity: SIMD3<Float>
    var acceleration: SIMD3<Float>
    var currentMaxSpeed: Float = 3.0
    
    let maxHistoryCount: Int
    
    init(id: Int, position: SIMD3<Float>, velocity: SIMD3<Float>, maxHistoryCount: Int = 500) {
        self.id = id
        self.position = position
        self.velocity = velocity
        self.acceleration = SIMD3<Float>(0, 0, 0)
        self.maxHistoryCount = maxHistoryCount
        self.positionHistory = [position]
    }
    
    func recordCurrentPosition() {
        positionHistory.append(position)
        if positionHistory.count > maxHistoryCount {
            positionHistory.removeFirst(positionHistory.count - maxHistoryCount)
        }
    }
}

class FishSchoolSimulation {
    static let shared = FishSchoolSimulation()
    
    var agents: [FishAgent] = []
    var perceptions: [(a: Int, b: Int)] = []
    var isInitialized = false
    
    // Bounds
    var boundarySize: Float = 8.0
    
    
    func initialize(count: Int) {
        boundarySize = 30.0
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
    
    func update(dt: Float, time: Double, speedInput: SceneInput?, delayInput: SceneInput?) {
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
        
        self.perceptions = []
        
        
        for agent in agents {
            // Brightness Delay Logic
            var addedSpeed: Float = 0.0
            let delayVal = ensureValueIsFloat(delayInput!.getHistoryValue(millisecondsAgo: 0.0))
            if let input = speedInput {
                let delay = Double(agent.id) * 30.0 * Double(delayVal) // 30ms delay per index
                let val = ensureValueIsFloat(input.getHistoryValue(millisecondsAgo: delay))
                addedSpeed = val
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
                    
                    self.perceptions.append((a: agent.id, b: other.id))
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
            agent.recordCurrentPosition()
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
    
    func perceptionsAgents() -> [(a: FishAgent, b: FishAgent)] {
        return self.perceptions.map {
            return (
                a: self.agents[$0.a],
                b: self.agents[$0.b]
            )
        }
    }
}
