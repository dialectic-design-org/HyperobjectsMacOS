//
//  Day27_Lifeform.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 26/01/2026.
//

import Foundation
import simd

// MARK: - Simulation Models

fileprivate struct LifeformCell: Identifiable {
    let id = UUID()
    var position: SIMD3<Float>
    var velocity: SIMD3<Float>
    var rotation: simd_quatf           // Orientation as quaternion
    var angularVelocity: SIMD3<Float>  // Rotation drift (axis-angle per second)
    var size: Float
    var age: Double
    var lifespan: Double
    var generation: Int

    // Color properties
    var inheritedColor: SIMD4<Float>   // Color inherited from parent at birth
    var targetColor: SIMD4<Float>      // Color this cell is shifting towards

    // Death animation
    var isDying: Bool = false
    var deathProgress: Float = 0       // 0 = just started dying, 1 = fully dead
}

// MARK: - Growth & Collision Helpers

/// Compute elongation factor using a tunable sigmoid curve
/// - Parameters:
///   - lifeProgress: Current age / lifespan (0 to 1)
///   - growthStart: When growth begins (0 to 1, e.g., 0.8 means last 20% of life)
///   - steepness: How sharp the sigmoid transition is (higher = sharper)
///   - maxElongation: Maximum elongation factor (e.g., 2.0 means double length)
/// - Returns: Elongation factor (1.0 = no elongation, maxElongation = fully grown)
fileprivate func computeElongation(
    lifeProgress: Float,
    growthStart: Float,
    steepness: Float,
    maxElongation: Float
) -> Float {
    guard lifeProgress > growthStart else { return 1.0 }

    // Normalize progress within growth phase (0 to 1)
    let t = (lifeProgress - growthStart) / (1.0 - growthStart)

    // Sigmoid function centered at 0.5
    let sigmoid = { (x: Float) -> Float in
        1.0 / (1.0 + exp(-steepness * (x - 0.5)))
    }

    // Normalize sigmoid output to go from 0 to 1 as t goes from 0 to 1
    let sigmoidAt0 = sigmoid(0)
    let sigmoidAt1 = sigmoid(1)
    let normalizedSigmoid = (sigmoid(t) - sigmoidAt0) / (sigmoidAt1 - sigmoidAt0)

    // Map to elongation range
    return 1.0 + normalizedSigmoid * (maxElongation - 1.0)
}

/// Find the closest points between two line segments
/// Returns (pointOnSegmentA, pointOnSegmentB)
fileprivate func closestPointsBetweenSegments(
    a1: SIMD3<Float>, a2: SIMD3<Float>,
    b1: SIMD3<Float>, b2: SIMD3<Float>
) -> (SIMD3<Float>, SIMD3<Float>) {
    let d1 = a2 - a1  // Direction of segment A
    let d2 = b2 - b1  // Direction of segment B
    let r = a1 - b1

    let a = simd_dot(d1, d1)  // Squared length of A
    let e = simd_dot(d2, d2)  // Squared length of B
    let f = simd_dot(d2, r)

    let epsilon: Float = 1e-6

    var s: Float = 0
    var t: Float = 0

    if a <= epsilon && e <= epsilon {
        // Both segments are points
        return (a1, b1)
    }

    if a <= epsilon {
        // Segment A is a point
        s = 0
        t = simd_clamp(f / e, 0, 1)
    } else {
        let c = simd_dot(d1, r)
        if e <= epsilon {
            // Segment B is a point
            t = 0
            s = simd_clamp(-c / a, 0, 1)
        } else {
            // General case
            let b = simd_dot(d1, d2)
            let denom = a * e - b * b

            if denom != 0 {
                s = simd_clamp((b * f - c * e) / denom, 0, 1)
            } else {
                s = 0
            }

            t = (b * s + f) / e

            if t < 0 {
                t = 0
                s = simd_clamp(-c / a, 0, 1)
            } else if t > 1 {
                t = 1
                s = simd_clamp((b - c) / a, 0, 1)
            }
        }
    }

    let closestOnA = a1 + s * d1
    let closestOnB = b1 + t * d2
    return (closestOnA, closestOnB)
}

/// Get the endpoints of a cell's elongated capsule in world space
fileprivate func getCapsuleEndpoints(
    cell: LifeformCell,
    elongation: Float
) -> (SIMD3<Float>, SIMD3<Float>) {
    // The cell extends along its local X axis
    let localXAxis = SIMD3<Float>(1, 0, 0)
    let worldAxis = cell.rotation.act(localXAxis)

    // Half-length along the elongation axis (subtract the radius to get line segment)
    // The capsule has radius = cell.size * 0.5, and total length = cell.size * elongation
    // So the line segment half-length = (total_length - diameter) / 2 = (elongation - 1) * size / 2
    let segmentHalfLength = max(0, (elongation - 1.0) * cell.size * 0.5)

    let endpoint1 = cell.position - worldAxis * segmentHalfLength
    let endpoint2 = cell.position + worldAxis * segmentHalfLength

    return (endpoint1, endpoint2)
}

fileprivate class LifeformSimulation {
    static let shared = LifeformSimulation()

    var cells: [LifeformCell] = []
    private var lastUpdateTime: Double = 0
    private var isInitialized = false

    // MARK: - Tunable Parameters

    // Population
    let targetPopulation = 100
    let bounds: Float = 6.0

    // Growth curve (sigmoid)
    let growthStart: Float = 0.7        // When growth begins (0-1 of lifespan)
    let growthSteepness: Float = 8.0    // Sigmoid steepness (higher = sharper transition)
    let maxElongation: Float = 2.0      // Maximum elongation factor

    // Physics
    let separationStrength: Float = 120.0   // How strongly cells push apart
    let separationPadding: Float = 0.3    // Extra padding around cells
    let dampening: Float = 0.98           // Velocity dampening (0-1)
    let gravityStrength: Float = 0.1      // Center attraction strength

    // Rotation drift
    let angularDriftStrength: Float = 0.6  // Max angular velocity magnitude (radians/sec)
    let angularDampening: Float = 0.999     // Angular velocity dampening (0-1)

    // Torque from collisions
    let torqueStrength: Float = 1.5        // How much off-center collisions cause rotation
    let maxAngularSpeed: Float = 2.0       // Cap on angular velocity to prevent spinning too fast

    // Death animation
    let deathDuration: Float = 1.5         // How long the death animation takes (seconds)
    let deathShrinkFactor: Float = 0.0     // Final size multiplier when fully dead (0 = disappear)

    // Color transition
    let colorTransitionSpeed: Float = 0.5  // How fast cells shift to their target color (0-1 per lifespan)

    // OKLCH-based warm palette: oranges, yellows, and reds
    // Using perceptually uniform color space for harmonious transitions
    let colorPalette: [OKLCH.WeightedColor] = {
        // Oranges
        let brightOrange = OKLCH(L: 0.72, C: 0.18, H: 45)      // Core bright orange
        let deepOrange = OKLCH(L: 0.58, C: 0.20, H: 38)        // Rich deep orange

        // Yellows
        let sunflower = OKLCH(L: 0.88, C: 0.18, H: 95)         // Bright sunflower yellow
        let goldenYellow = OKLCH(L: 0.80, C: 0.16, H: 85)      // Warm golden yellow

        // Reds
        let fireRed = OKLCH(L: 0.58, C: 0.22, H: 25)           // Vibrant fire red
        let crimson = OKLCH(L: 0.50, C: 0.20, H: 15)           // Deep crimson

        // Accents
        let cream = OKLCH(L: 0.92, C: 0.04, H: 55)             // Soft cream highlight

        return OKLCH.probabilisticPalette([
            (brightOrange, 0.22),    // 22% - bright orange
            (deepOrange, 0.18),      // 18% - deep orange
            (sunflower, 0.15),       // 15% - bright yellow
            (goldenYellow, 0.12),    // 12% - golden yellow
            (fireRed, 0.15),         // 15% - fire red
            (crimson, 0.10),         // 10% - deep red
            (cream, 0.08)            // 8%  - light highlight
        ])
    }()

    func randomTargetColor() -> SIMD4<Float> {
        OKLCH.weightedRandom(from: colorPalette).simd
    }

    // MARK: - Simulation Update

    func update(time: Double) {
        if !isInitialized || cells.isEmpty {
            initialize(time: time)
        }

        // Calculate Delta Time
        let dt = Float(max(0.001, min(0.1, time - lastUpdateTime)))
        lastUpdateTime = time

        var nextGeneration: [LifeformCell] = []
        let currentCells = cells // Snapshot

        // Pre-compute elongations for all cells
        var elongations: [Float] = []
        for cell in currentCells {
            let lifeProgress = Float(cell.age / cell.lifespan)
            let elongation = computeElongation(
                lifeProgress: lifeProgress,
                growthStart: growthStart,
                steepness: growthSteepness,
                maxElongation: maxElongation
            )
            elongations.append(elongation)
        }

        for i in 0..<currentCells.count {
            var cell = currentCells[i]
            let cellElongation = elongations[i]

            // 1. Physics Integration
            var force = SIMD3<Float>(0, 0, 0)
            var torque = SIMD3<Float>(0, 0, 0)  // Accumulated torque from collisions

            // Gravity (Center Attraction) - weak pull toward origin
            let distToCenter = length(cell.position)
            if distToCenter > 0.001 {
                let dirIn = -normalize(cell.position)
                force += dirIn * gravityStrength * (distToCenter / bounds)
            }

            // Capsule-based separation (handles elongated cells)
            let (cellA1, cellA2) = getCapsuleEndpoints(cell: cell, elongation: cellElongation)
            let cellRadius = cell.size * 0.5  // Capsule radius

            for j in 0..<currentCells.count {
                if i == j { continue }

                let other = currentCells[j]
                let otherElongation = elongations[j]
                let (otherA1, otherA2) = getCapsuleEndpoints(cell: other, elongation: otherElongation)
                let otherRadius = other.size * 0.5

                // Find closest points between the two capsule center-lines
                let (closestOnCell, closestOnOther) = closestPointsBetweenSegments(
                    a1: cellA1, a2: cellA2,
                    b1: otherA1, b2: otherA2
                )

                // Distance between closest points
                let delta = closestOnCell - closestOnOther
                let dist = length(delta)

                // Combined radii plus padding
                let minDist = cellRadius + otherRadius + separationPadding

                if dist < minDist && dist > 0.001 {
                    // Push apart based on overlap
                    let overlap = minDist - dist
                    let pushDir = normalize(delta)
                    let pushForce = pushDir * overlap * separationStrength
                    force += pushForce

                    // Compute torque from off-center collision
                    // For "gear-like" counter-rotation, we use the lever arm from
                    // THIS cell's center to its contact point, crossed with the push direction.
                    // To break the mathematical symmetry (opposite levers × opposite forces = same torque),
                    // we use the cell indices: the cell with lower index gets positive torque,
                    // the cell with higher index gets negative torque.

                    let leverArm = closestOnCell - cell.position
                    let leverLength = length(leverArm)

                    if leverLength > 0.001 {
                        // Torque axis: perpendicular to both lever arm and push direction
                        let torqueAxis = cross(leverArm, pushDir)
                        let torqueAxisLength = length(torqueAxis)

                        if torqueAxisLength > 0.001 {
                            let torqueMagnitude = overlap * torqueStrength
                            // Use index comparison to break symmetry: lower index gets positive torque
                            let torqueSign: Float = (i < j) ? 1.0 : -1.0
                            let collisionTorque = normalize(torqueAxis) * torqueMagnitude * torqueSign
                            torque += collisionTorque
                        }
                    }
                }
            }

            // Linear integration
            cell.velocity += force * dt
            cell.velocity *= dampening
            cell.position += cell.velocity * dt

            // Angular integration
            // Apply torque to angular velocity
            cell.angularVelocity += torque * dt

            // Cap angular speed to prevent crazy spinning
            let angularSpeed = length(cell.angularVelocity)
            if angularSpeed > maxAngularSpeed {
                cell.angularVelocity = normalize(cell.angularVelocity) * maxAngularSpeed
            }

            // Apply rotation from angular velocity
            if angularSpeed > 0.0001 {
                let axis = normalize(cell.angularVelocity)
                let angle = angularSpeed * dt
                let deltaRotation = simd_quatf(angle: angle, axis: axis)
                cell.rotation = deltaRotation * cell.rotation
                cell.rotation = cell.rotation.normalized  // Prevent drift accumulation
            }

            // Dampen angular velocity
            cell.angularVelocity *= angularDampening

            // 2. Lifecycle
            if cell.isDying {
                // Update death animation
                cell.deathProgress += dt / deathDuration
                if cell.deathProgress >= 1.0 {
                    // Fully dead, don't add to next generation
                    continue
                }
                nextGeneration.append(cell)
            } else {
                // Normal lifecycle
                cell.age += Double(dt)

                // Division Logic - when age reaches lifespan
                if cell.age >= cell.lifespan {

                    // Population Control
                    let shouldDivide = currentCells.count < targetPopulation || Float.random(in: 0...1) > 0.6

                    if shouldDivide {
                        // Divide into two side-by-side cells
                        let localXAxis = SIMD3<Float>(1, 0, 0)
                        let splitAxis = cell.rotation.act(localXAxis)
                        let offset = splitAxis * (cell.size * 0.5)

                        let child1Lifespan = Double.random(in: 2...16)
                        let child2Lifespan = Double.random(in: 2...16)

                        // Compute parent's current blended color for inheritance
                        let lifeProgress = Float(cell.age / cell.lifespan)
                        let colorBlend = min(1.0, lifeProgress * colorTransitionSpeed)
                        let parentCurrentColor = mix(cell.inheritedColor, cell.targetColor, t: colorBlend)

                        // Helper for random angular velocity
                        func randomAngularVelocity() -> SIMD3<Float> {
                            let axis = normalize(SIMD3<Float>(
                                Float.random(in: -1...1),
                                Float.random(in: -1...1),
                                Float.random(in: -1...1)
                            ))
                            let speed = Float.random(in: 0...angularDriftStrength)
                            return axis * speed
                        }

                        var child1 = LifeformCell(
                            position: cell.position - offset,
                            velocity: SIMD3<Float>(0, 0, 0),
                            rotation: cell.rotation,
                            angularVelocity: randomAngularVelocity(),
                            size: cell.size,
                            age: 0,
                            lifespan: child1Lifespan,
                            generation: cell.generation + 1,
                            inheritedColor: parentCurrentColor,
                            targetColor: randomTargetColor()
                        )

                        var child2 = LifeformCell(
                            position: cell.position + offset,
                            velocity: SIMD3<Float>(0, 0, 0),
                            rotation: cell.rotation,
                            angularVelocity: randomAngularVelocity(),
                            size: cell.size,
                            age: 0,
                            lifespan: child2Lifespan,
                            generation: cell.generation + 1,
                            inheritedColor: parentCurrentColor,
                            targetColor: randomTargetColor()
                        )

                        nextGeneration.append(child1)
                        nextGeneration.append(child2)
                    } else {
                        // Cell dies - start death animation
                        cell.isDying = true
                        cell.deathProgress = 0
                        nextGeneration.append(cell)
                    }

                } else {
                    nextGeneration.append(cell)
                }
            }
        }
        
        cells = nextGeneration
    }
    
    func initialize(time: Double) {
        cells.removeAll()
        lastUpdateTime = time

        // Start with a single cell
        let pos = SIMD3<Float>(0, 0, 0)

        // Give initial cell a slight random rotation and drift
        let initialRotation = simd_quatf(
            angle: Float.random(in: 0...(.pi * 2)),
            axis: normalize(SIMD3<Float>(
                Float.random(in: -1...1),
                Float.random(in: -1...1),
                Float.random(in: -1...1)
            ))
        )
        let initialAngularVelocity = normalize(SIMD3<Float>(
            Float.random(in: -1...1),
            Float.random(in: -1...1),
            Float.random(in: -1...1)
        )) * Float.random(in: 0...angularDriftStrength)

        // Initial color
        let startColor = randomTargetColor()

        cells.append(LifeformCell(
            position: pos,
            velocity: .zero,
            rotation: initialRotation,
            angularVelocity: initialAngularVelocity,
            size: 1.0,
            age: 0,
            lifespan: 4.0,
            generation: 0,
            inheritedColor: startColor,
            targetColor: randomTargetColor()
        ))
        isInitialized = true
    }
}

struct Day27_Lifeform: GenuaryDayGenerator {
    let dayNumber = "27"

    func generateLines(
        inputs: [String: Any],
        scene: GeometriesSceneBase,
        time: Double,
        lineWidthBase: Float,
        state: Genuary2026State
    ) -> (lines: [Line], replacementProbability: Float) {
        var outputLines: [Line] = []
        
        // 1. Update Simulation
        LifeformSimulation.shared.update(time: time)
        let population = LifeformSimulation.shared.cells
        
        // Get simulation parameters for consistent rendering
        let sim = LifeformSimulation.shared

        // 2. Render each cell
        for cell in population {
            // Create fresh base geometry for each cell (centered at origin)
            let baseCube = Cube(center: .zero, size: 1.0)
            let baseLines = baseCube.wallOutlines()

            // Compute life progress (clamped for dying cells)
            let lifeProgress = min(1.0, Float(cell.age / cell.lifespan))

            // Compute elongation
            var elongation: Float
            var sizeMultiplier: Float = 1.0
            var alphaMultiplier: Float = 1.0

            if cell.isDying {
                // Death animation: shrink and fade
                let deathEase = cell.deathProgress * cell.deathProgress  // Ease-in (accelerate)
                sizeMultiplier = 1.0 * (1.0 - deathEase) + sim.deathShrinkFactor * deathEase
                alphaMultiplier = 1.0 - deathEase  // Fade out

                // Keep elongation at max during death (cell was fully grown)
                elongation = sim.maxElongation
            } else {
                // Normal growth elongation
                elongation = computeElongation(
                    lifeProgress: lifeProgress,
                    growthStart: sim.growthStart,
                    steepness: sim.growthSteepness,
                    maxElongation: sim.maxElongation
                )
            }

            // Scale Matrix: elongation along local X, with death shrink
            let scaleM = matrix_scale(scale: SIMD3<Float>(
                cell.size * elongation * sizeMultiplier,
                cell.size * sizeMultiplier,
                cell.size * sizeMultiplier
            ))

            // Rotation from cell's quaternion
            let rotationM = matrix_float4x4(cell.rotation)

            // Translation
            let translationM = matrix_translation(translation: cell.position)

            // Standard TRS order: translate * rotate * scale
            let modelMatrix = translationM * rotationM * scaleM

            // Color: blend from inherited color to target color over lifetime
            let colorBlend = min(1.0, lifeProgress * sim.colorTransitionSpeed)
            var color = mix(cell.inheritedColor, cell.targetColor, t: colorBlend)

            // Apply alpha fade for dying cells
            color.w *= alphaMultiplier
            
            // Apply transformation and color to each line
            for baseLine in baseLines {
                // Transform points directly using the model matrix
                let start4 = modelMatrix * SIMD4<Float>(baseLine.startPoint, 1)
                let end4 = modelMatrix * SIMD4<Float>(baseLine.endPoint, 1)

                var l = Line(
                    startPoint: SIMD3<Float>(start4.x, start4.y, start4.z),
                    endPoint: SIMD3<Float>(end4.x, end4.y, end4.z)
                )
                l.colorStart = color
                l.colorEnd = color
                l.colorStartOuterLeft = color
                l.colorStartOuterRight = color
                l.colorEndOuterLeft = color
                l.colorEndOuterRight = color
                l.lineWidthStart = lineWidthBase
                l.lineWidthEnd = lineWidthBase

                outputLines.append(l)
            }
        }

        var finalScaleMatrix = matrix_scale(scale: SIMD3<Float>(repeating: 0.1))
        var finalRotationMatrix = matrix_rotation(angle: Float(time * 0.025), axis: SIMD3<Float>(0.0, 1.0, 0.0))
        for i in outputLines.indices {
            outputLines[i] = outputLines[i].applyMatrix(finalScaleMatrix * finalRotationMatrix)
        }

        return (outputLines, 0.0)
    }
}
