//
//  Day21_Bauhaus.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 21/01/2026.
//

import simd

struct Day21_Bauhaus: GenuaryDayGenerator {
    let dayNumber = "21"

    func generateLines(
        inputs: [String: Any],
        scene: GeometriesSceneBase,
        time: Double,
        lineWidthBase: Float,
        state: Genuary2026State
    ) -> (lines: [Line], replacementProbability: Float) {
        var outputLines: [Line] = []
        
        // Bauhaus Palette
        let colors: [SIMD4<Float>] = [
            SIMD4<Float>(0.8, 0.2, 0.2, 1.0), // Red
            SIMD4<Float>(0.2, 0.4, 0.8, 1.0), // Blue
            SIMD4<Float>(0.9, 0.8, 0.2, 1.0), // Yellow
            SIMD4<Float>(0.1, 0.1, 0.1, 1.0), // Black
            SIMD4<Float>(0.95, 0.95, 0.9, 1.0) // Off-White
        ]
        
        // Parameters for the Bauhaus Composition
        // These can be tuned to adjust the emergent visual style
        
        // Layout Bounds (Half-extents)
        // Limits the generation to a box of [-x, x], [-y, y], [-z, z]
        let bounds = SIMD3<Float>(0.5, 0.5, 0.2)
        
        // Grid Configuration
        // Retuned for medium density
        let cellSize: Float = 0.2
        let cubeBaseSize: Float = 0.14
        
        // Calculate grid ranges based on bounds and cell size
        let rangeX = Int(bounds.x / cellSize)
        let rangeY = Int(bounds.y / cellSize)
        let rangeZ = Int(bounds.z / cellSize)
        
        // Probabilities for various Bauhaus "events"
        let voidProbability: Float = 0.5      
        let beamProbability: Float = 0.2      
        let rotationProbability: Float = 0.15 
        let densityThreshhold: Float = 0.85   // Increased to allow more elements
        
        // Helper to colorize lines and set different line widths
        func colorizeLines(_ lines: [Line], color: SIMD4<Float>, widthMultiplier: Float) -> [Line] {
            var coloredLines = lines
            for i in 0..<coloredLines.count {
                coloredLines[i].colorStart = color
                coloredLines[i].colorStartOuterLeft = color
                coloredLines[i].colorStartOuterRight = color
                coloredLines[i].colorEnd = color
                coloredLines[i].colorEndOuterLeft = color
                coloredLines[i].colorEndOuterRight = color
                
                let width = lineWidthBase * widthMultiplier
                coloredLines[i].lineWidthStart = width
                coloredLines[i].lineWidthEnd = width
            }
            return coloredLines
        }
        
        // Animated Floating Point
        // Moves in a Lissajous-like figure-8 pattern through the composition
        let animPoint = SIMD3<Float>(
            sin(Float(time) * 0.2) * bounds.x * 1.4,
            cos(Float(time) * 0.5) * bounds.y * 1.2,
            sin(Float(time) * 0.9) * bounds.z * 0.8
        )
        // Increased radius to ensure influence is felt across the composition
        let effectRadius: Float = 1.2
        
        for x in -rangeX...rangeX {
            for y in -rangeY...rangeY {
                for z in -rangeZ...rangeZ {
                    
                    // Create a deterministic pseudo-random seed for this location
                    // sin(dot(n, vec3(12.9898, 78.233, 54.53))) * 43758.5453
                    let noiseVal = abs(sin(Float(x) * 12.9898 + Float(y) * 78.233 + Float(z) * 54.53))
                    
                    // Bauhaus structure: Keep some emptiness
                    // 1. Alternating checkerboard condition
                    let checker = (abs(x) + abs(y) + abs(z)) % 2 == 0
                    if !checker { continue }
                    
                    // 2. Probabilistic emptiness (Reduce Density)
                    if noiseVal > densityThreshhold { continue }
                    
                    let xPos = Float(x) * cellSize
                    let yPos = Float(y) * cellSize
                    let zPos = Float(z) * cellSize
                    let rawPos = SIMD3<Float>(xPos, yPos, zPos)
                    
                    // Global Scene Rotation (Very Slow Spin)
                    let globalSpeed = 0.05
                    let globalAngle = Float(time) * Float(globalSpeed)
                    let cosG = cos(globalAngle)
                    let sinG = sin(globalAngle)
                    let rx = rawPos.x * cosG - rawPos.z * sinG
                    let rz = rawPos.x * sinG + rawPos.z * cosG
                    let currentPos = SIMD3<Float>(rx, rawPos.y, rz)
                    
                    // Calculate distance to animated point
                    let dist = simd_distance(currentPos, animPoint)
                    let rawInfluence = max(0.0, (effectRadius - dist) / effectRadius)
                    // Use power curve to make the effect felt at larger distances (slower falloff)
                    let influence = pow(rawInfluence, 0.7)
                    
                    // Select Color and define Role
                    let colorIndex = (abs(x * 3 + y * 7 + z * 11)) % colors.count
                    let color = colors[colorIndex]
                    
                    // Start Line Width Multiplier logic
                    var widthMultiplier: Float = 1.0
                    
                    // Base Cube
                    var mainCube = Cube(center: currentPos, size: cubeBaseSize)
                    
                    // 0. Base Dynamic Rotation
                    // Only apply rotation to a handful of special cubes (high noise value)
                    // and restrict rotation to the Y-axis for a more stable architectural feel.
                    if noiseVal > 0.82 {
                        let rotSpeed: Float = 0.2
                        
                        // Alternate rotation direction based on grid position (Checkerboard)
                        let direction: Float = ((x + y + z) % 2 == 0) ? 1.0 : -1.0
                        
                        let rotPhase = Float(x) * 0.1 + Float(y) * 0.2 + Float(z) * 0.3
                        let rotAngle = (Float(time) * rotSpeed * direction) + rotPhase
                        
                        mainCube.orientation = SIMD3<Float>(0, rotAngle, 0)
                    }
                    
                    // 1. Asymmetrical Scaling
                    // Vary scale based on color/role to create weight and hierarchy
                    if noiseVal < beamProbability {
                        // Structural Beam (Long and thin)
                        // Beams scale along their length based on influence
                        // We scale from 1.0 (normal) to -2.0 (inverted/flipped)
                        let beamStretch = 1.0 + ((-2.0 - 1.0) * influence)

                        if noiseVal < beamProbability * 0.33 {
                             mainCube.axisScale = SIMD3<Float>(3.0 * beamStretch, 0.2, 0.2) // X-Beam
                        } else if noiseVal < beamProbability * 0.66 {
                             mainCube.axisScale = SIMD3<Float>(0.2, 3.0 * beamStretch, 0.2) // Y-Beam
                        } else {
                             mainCube.axisScale = SIMD3<Float>(0.2, 0.2, 3.0 * beamStretch) // Z-Beam
                        }
                        // Beams imply slightly with thickness
                        widthMultiplier = 1.2 + influence * 0.5
                    } else {
                        // Mass Block
                        if colorIndex == 0 || colorIndex == 3 { // Red or Black (Heavy)
                            mainCube.axisScale = SIMD3<Float>(1.2, 1.2, 1.2)
                            // Heavy blocks get thickest lines
                            widthMultiplier = 2.0
                        } else if colorIndex == 4 { // White (Background/Filler)
                            mainCube.axisScale = SIMD3<Float>(0.8, 0.8, 0.8)
                            // Background elements get thinnest lines
                            widthMultiplier = 0.3
                        } else {
                            mainCube.axisScale = SIMD3<Float>(0.6, 0.6, 0.6)
                            // Standard geometric elements
                            widthMultiplier = 1.0
                        }
                        
                        // Apply Animated Influence to Mass Blocks
                        // Predictable but random-looking pattern determines interaction
                        if influence > 0.0 {
                            // Split behavior: Some grow (swell), some shrink (compress)
                            // We map the scale from a negative value to a positive value (or vice versa)
                            // to ensure 'flipping' occurs as the point moves closer or further.
                            
                            // Interpolation helper
                            func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float {
                                return a + (b - a) * t
                            }
                            
                            if noiseVal > 0.6 {
                                // Group A: "The Emergers"
                                // Far (Inf 0): Scale -3.0 (Large Inverted) -> Starts very "negative"
                                // Near (Inf 1): Scale 2.5 (Large Normal)   -> Flips to positive
                                // Zero crossing is somewhere in between
                                let targetScale = lerp(-3.0, 2.5, influence)
                                let growth = targetScale
                                
                                let mode = Int(noiseVal * 100) % 4
                                switch mode {
                                case 0: mainCube.axisScale *= growth
                                case 1: mainCube.axisScale.y *= growth
                                case 2: mainCube.axisScale.x *= growth
                                case 3: mainCube.axisScale.z *= growth
                                default: break
                                }
                            } else {
                                // Group B: "The Imploders"
                                // Far (Inf 0): Scale 1.2 (Normal)
                                // Near (Inf 1): Scale -5.0 (Huge Inverted) -> Implodes past zero to huge negative
                                let targetScale = lerp(1.2, -5.0, influence)
                                let shrink = targetScale
                                
                                let mode = Int(noiseVal * 100) % 3
                                switch mode {
                                case 0: mainCube.axisScale *= shrink      // Uniform shrink/invert
                                case 1: mainCube.axisScale.y *= shrink    // Flatten/Invert Y
                                case 2: mainCube.axisScale *= SIMD3<Float>(shrink, 1.0, shrink) // Thin Pillar/Invert
                                default: break
                                }
                            }
                        }
                    }
                    
                    // 2. Functional Orientation (Diagonals)
                    // ... (rest of logic remains same) ...
                    // Apply rotation to create tension, mostly on beams or small elements
                    if noiseVal > (1.0 - rotationProbability) {
                        // 45 degree rotation around Z or Y
                        if noiseVal > (1.0 - rotationProbability * 0.5) {
                            mainCube.orientation += SIMD3<Float>(0, 0, Float.pi / 4)
                        } else {
                            mainCube.orientation += SIMD3<Float>(0, Float.pi / 4, 0)
                        }
                    }
                    
                    // 3. Boolean Construction / Complex Geometry
                    var finalLines: [Line] = []
                    var performedBoolean = false
                    
                    // Boolean thresholds refined to be rarer but impactful
                    
                    // A. Symmetric Difference: Jagged "Artifacts" (Blue/Yellow cubes with high noise)
                    // Creates complex, star-like geometries by overlapping rotated copies
                    // Threshold raised to > 0.85 (was 0.75) for rarity
                    if (colorIndex == 1 || colorIndex == 2) && noiseVal > 0.88 {
                        let offset = SIMD3<Float>(0.02, 0.02, 0.02)
                        var otherCube = Cube(center: mainCube.center + offset, size: mainCube.size)
                        otherCube.axisScale = mainCube.axisScale
                        otherCube.orientation = mainCube.orientation + SIMD3<Float>(Float.pi / 4, Float.pi / 4, 0)
                        
                        let result = mainCube.symmetricDifference(with: otherCube)
                        for solid in result.solids {
                            finalLines.append(contentsOf: solid.edgeLines())
                        }
                        widthMultiplier *= 0.8 // Slightly thinner lines for complex geometry
                        performedBoolean = true
                    }
                    
                    // B. Union: Structural Joints for Beams
                    // Adds a connector block to the long thin beams
                    // Range narrowed (0.1 to 0.15)
                    else if noiseVal < 0.15 && noiseVal > 0.1 {
                        var joint = Cube(center: mainCube.center, size: cubeBaseSize * 1.2)
                        // Make joint a uniform small cube (resetting the beam scaling)
                        joint.axisScale = SIMD3<Float>(0.4, 0.4, 0.4)
                        joint.orientation = SIMD3<Float>(0, Float.pi/4, 0)
                        
                        let result = mainCube.union(with: joint)
                        for solid in result.solids {
                            finalLines.append(contentsOf: solid.edgeLines())
                        }
                        performedBoolean = true
                    }
                    
                    // C. Difference: Architectural Windows (Red/Black mass blocks)
                    // Carves out diamond-shaped voids
                    // Range narrowed (0.45 to 0.55) so only specific blocks get windows
                    else if (colorIndex == 0 || colorIndex == 3) && noiseVal > 0.45 && noiseVal < 0.55 {
                        let voidSize = mainCube.size * 0.7
                        // Offset the void: push it slightly out of center
                        let dirX: Float = (noiseVal > 0.5) ? 1.0 : -1.0
                        let offset = SIMD3<Float>(dirX * 0.1, 0.1, 0.1) * mainCube.size
                        
                        var voidCube = Cube(center: mainCube.center + offset, size: voidSize)
                        voidCube.axisScale = mainCube.axisScale
                        // Rotate void for diamond-shaped cutouts
                        voidCube.orientation = mainCube.orientation + SIMD3<Float>(0, 0, Float.pi / 4)
                        
                        let result = mainCube.subtract(voidCube)
                        for solid in result.solids {
                            finalLines.append(contentsOf: solid.edgeLines())
                        }
                        widthMultiplier = 1.0
                        performedBoolean = true
                    }
                    
                    // D. Intersection: "The Core"
                    // Keeps only the central overlap of the cube and a rotated copy
                    // Creates intricate faceted gems, increasing visual complexity
                    else if noiseVal > 0.72 && noiseVal < 0.78 {
                         var rotatedCopy = Cube(center: mainCube.center, size: mainCube.size * 1.1)
                         
                         // Vary the relationship between the two intersection components
                         // Far: They match closely (divergence 1.0)
                         // Near: They invert relative to each other (divergence -1.5)
                         let divergence = 1.0 + (-1.5 - 1.0) * influence
                         rotatedCopy.axisScale = mainCube.axisScale * divergence
                         
                         rotatedCopy.orientation = SIMD3<Float>(Float.pi/4, Float.pi/3, 0)
                         
                         let result = mainCube.intersect(with: rotatedCopy)
                         for solid in result.solids {
                            finalLines.append(contentsOf: solid.edgeLines())
                         }
                         // Highlight these rare gems with thicker lines
                         widthMultiplier = 2.0 
                         performedBoolean = true
                    }
                    
                    if !performedBoolean {
                        finalLines = mainCube.wallOutlines()
                    }
                    
                    outputLines.append(contentsOf: colorizeLines(finalLines, color: color, widthMultiplier: widthMultiplier))
                }
            }
        }
        
        // Visualize the Animated Point
        // 1. Tiny center marker (Cross-hairs)
        let centerColor = colors[2] // Yellow
//        outputLines.append(contentsOf: colorizeLines(createCircleLines(center: animPoint, radius: 0.03, axis: 0), color: centerColor, widthMultiplier: 2.0))
//        outputLines.append(contentsOf: colorizeLines(createCircleLines(center: animPoint, radius: 0.03, axis: 1), color: centerColor, widthMultiplier: 2.0))
        outputLines.append(contentsOf: colorizeLines(createCircleLines(center: animPoint, radius: 0.03, axis: 2, segments: 16), color: centerColor, widthMultiplier: 2.0))
        
        // 2. Large influence radius (Ring)
        let ringColor = colors[4] // Off-white
        outputLines.append(contentsOf: colorizeLines(createCircleLines(center: animPoint, radius: effectRadius, axis: 1, segments: 42), color: ringColor, widthMultiplier: 0.5))
        
        // Apply a final scaling on all output lines with a scaling matrix
        let finalScaleMatrix = matrix_scale(scale: SIMD3<Float>(1.2, 1.2, 1.2))
        for i in outputLines.indices {
            outputLines[i] = outputLines[i].applyMatrix(finalScaleMatrix)
        }
        return (outputLines, 0.0)
    }
    
    // Helper to generate circle lines
    // Axis: 0=X, 1=Y, 2=Z plane
    func createCircleLines(center: SIMD3<Float>, radius: Float, axis: Int, segments: Int = 32) -> [Line] {
        var lines: [Line] = []
        var points: [SIMD3<Float>] = []
        
        for i in 0...segments {
            let theta = (Float(i) / Float(segments)) * Float.pi * 2
            let c = cos(theta) * radius
            let s = sin(theta) * radius
            
            var p = SIMD3<Float>(0, 0, 0)
            switch axis {
            case 0: p = SIMD3<Float>(0, c, s) // YZ Plane
            case 1: p = SIMD3<Float>(c, 0, s) // XZ Plane
            case 2: p = SIMD3<Float>(c, s, 0) // XY Plane
            default: p = SIMD3<Float>(c, 0, s)
            }
            points.append(p + center)
        }
        
        for i in 0..<segments {
            lines.append(Line(startPoint: points[i], endPoint: points[i+1]))
        }
        return lines
    }
}
