//
//  ThreeBodyGenerator.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 23/09/2025.
//

import Foundation
import simd
import SwiftUI

func simd3DoubleToFloat(_ input: SIMD3<Double>) -> SIMD3<Float> {
    return SIMD3<Float>(Float(input.x), Float(input.y), Float(input.z))
}

class ThreeBodyGenerator: CachedGeometryGenerator {
    var initialised: Bool = false
    var system: (engine: PhysicsEngine, gravity: NewtonianGravity) = ThreeBodyFactory.randomThreeBodySystem(
        speedRange: 0...1000.0
    )
    let dt: Double = 6.0
    
    var rotation: Float = 0.0
    
    var particleTraces: [UUID: [SIMD3<Float>]] = [:]
    
    init() {
        super.init(name: "Three Body Generator",
        inputDependencies: ["Trail length", "Fading"])
    }
    
    override func generateGeometriesFromInputs(inputs: [String : Any]) -> [any Geometry] {
        var lines: [Line] = [
            Line(
                startPoint: .zero,
                endPoint: SIMD3<Float>(0.0, 0.1, 0.0)
            )
        ]
        
        
        var scaling = 1.0 / 1000000000.0
        
        let currentParticles = system.engine.particles
        let trailLength = 1000000 // max(0, Int(floatFromInputs(inputs, name: "Trail length")))
        let fading = 0.0 // max(0.0, min(Double(floatFromInputs(inputs, name: "Fading")), 1.0))
        
        let maxLines = 2000

        print("---- Position / Scaled Position ----")
        for particle in currentParticles {
            let scaledPosition = simd3DoubleToFloat(particle.position * scaling)
            // Add particle positions to particle traces (scaled)
            var trace = particleTraces[particle.id] ?? []
            trace.append(scaledPosition)
            if trailLength > 0 && trace.count > trailLength {
                trace.removeFirst(trace.count - trailLength)
            }
            particleTraces[particle.id] = trace
            
            let line = Line(
                startPoint: scaledPosition,
                endPoint: scaledPosition + SIMD3<Float>(0.0, 0.001, 0.0),
                lineWidthStart: 10.0,
                lineWidthEnd: 10.0
            )
            lines.append(line)
            
            // Curvature-adaptive sampling of the trace with fading, capped at maxLines
            if let trace = particleTraces[particle.id], trace.count >= 2 {
                let n = trace.count
                let nEdges = n - 1
                let k = min(nEdges, maxLines)
                if k >= 1 {
                    // Compute per-edge directions and simple curvature proxy (1 - cos turn angle)
                    var dirs: [SIMD3<Float>] = Array(repeating: .zero, count: nEdges)
                    var lens: [Float] = Array(repeating: 0, count: nEdges)
                    for i in 0..<nEdges {
                        let v = trace[i + 1] - trace[i]
                        let l = simd_length(v)
                        lens[i] = l
                        dirs[i] = l > 0 ? (v / l) : SIMD3<Float>(repeating: 0)
                    }
                    let tCount = max(n - 2, 0)
                    var turns: [Float] = Array(repeating: 0, count: tCount)
                    if tCount > 0 {
                        for i in 0..<(n - 2) {
                            let l0 = lens[i]
                            let l1 = lens[i + 1]
                            if l0 > 0 && l1 > 0 {
                                let c = simd_dot(dirs[i], dirs[i + 1])
                                let clamped = max(-1.0, min(1.0, Double(c)))
                                turns[i] = Float(1.0 - clamped)
                            }
                        }
                    }
                    let curvatureEmphasis: Double = 2.0
                    func edgeWeight(_ e: Int) -> Double {
                        var tAvg: Double = 0.0
                        if n >= 3 {
                            if e == 0 {
                                tAvg = Double(turns[0])
                            } else if e == nEdges - 1 {
                                tAvg = Double(turns[n - 3])
                            } else {
                                tAvg = 0.5 * Double(turns[e - 1] + turns[e])
                            }
                        }
                        return 1.0 + curvatureEmphasis * tAvg
                    }
                    var totalW: Double = 0.0
                    if nEdges > 0 {
                        for e in 0..<nEdges { totalW += edgeWeight(e) }
                    }
                    let denom = Float(max(nEdges, 1))
                    var prevIdx = 0
                    var prevPoint = trace[0]
                    var cum: Double = 0.0
                    var e = 0
                    for s in 1...k {
                        let target = (totalW * Double(s)) / Double(k)
                        while e < nEdges && cum < target {
                            cum += edgeWeight(e)
                            e += 1
                        }
                        let idx = min(e, nEdges)
                        let p = trace[idx]
                        let t0 = Float(prevIdx) / denom
                        let t1 = Float(idx) / denom
                        let a0 = Float((1.0 - fading) + fading * Double(t0))
                        let a1 = Float((1.0 - fading) + fading * Double(t1))
                        var seg = Line(
                            startPoint: prevPoint,
                            endPoint: p,
                            lineWidthStart: 0.7,
                            lineWidthEnd: 0.7
                        )
                        seg = seg.setBasicEndPointColors(
                            startColor: SIMD4<Float>(1.0, 1.0, 1.0, a0),
                            endColor: SIMD4<Float>(1.0, 1.0, 1.0, a1)
                        )
                        lines.append(seg)
                        prevIdx = idx
                        prevPoint = p
                    }
                }
            }
        }
        
        for i in 0...100 {
            self.system.engine.step(dt: dt)
        }
        
        rotation += 0.001
        
        let rotationMatrixY = matrix_rotation(angle: rotation, axis: SIMD3<Float>(x: 0, y: 1, z: 0))
        for i in 0..<lines.count {
            lines[i] = lines[i].applyMatrix(rotationMatrixY)
        }
        
        return lines
    }
    
}

