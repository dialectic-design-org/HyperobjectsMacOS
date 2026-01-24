//
//  Day23_Transparency.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 23/01/2026.
//

import AppKit

struct Day23_Transparency: GenuaryDayGenerator {
    let dayNumber = "23"

    func generateLines(
        inputs: [String: Any],
        scene: GeometriesSceneBase,
        time: Double,
        lineWidthBase: Float,
        state: Genuary2026State
    ) -> (lines: [Line], replacementProbability: Float) {
        var outputLines:[Line] = []
        
        var centralCube = Cube(center: SIMD3<Float>(0.0, 0.0, 0.0), size: 0.7)
        var cubeLines = centralCube.wallOutlines()
        var cubeColor = SIMD4<Float>(1.0, 1.0, 1.0, 0.5)
        for i in cubeLines.indices {
            cubeLines[i].lineWidthStart = lineWidthBase * 0.6
            cubeLines[i].lineWidthEnd = lineWidthBase * 0.6
            cubeLines[i] = cubeLines[i].setBasicEndPointColors(startColor: cubeColor, endColor: cubeColor)
        }
        
        

        outputLines.append(contentsOf: cubeLines)

        var traceLines: [Line] = []

        // Single bundle of parallel beams
        let numRays = 40
        
        // Continuous rotation on all axes, orbiting around the center
        // Using primes for speeds to avoid repeating patterns quickly
        let rotationX = matrix_rotation(angle: Float(time * 0.057), axis: SIMD3<Float>(1, 0, 0))
        let rotationY = matrix_rotation(angle: Float(time * 0.083), axis: SIMD3<Float>(0, 1, 0))
        let rotationZ = matrix_rotation(angle: Float(time * 0.041), axis: SIMD3<Float>(0, 0, 1))
        
        let combinedRotation = rotationZ * rotationY * rotationX
        
        let orbitDistance: Float = 2.0
        // Calculate source position on the sphere surface
        // Starting at -X axis and rotating it
        let baseSourcePos = SIMD3<Float>(-orbitDistance, 0, 0)
        let sourceCenter4 = combinedRotation * SIMD4<Float>(baseSourcePos, 1.0)
        let sourceCenter = SIMD3<Float>(sourceCenter4.x, sourceCenter4.y, sourceCenter4.z)
        
        // Direction is always towards the center (0,0,0)
        let rotatedDirection = normalize(-sourceCenter)
        
        // Define a "right" and "up" vector relative to the beam for the grid
        // Handle singularity when looking straight up/down
        var beamTmpUp = SIMD3<Float>(0, 1, 0)
        if abs(dot(rotatedDirection, beamTmpUp)) > 0.99 {
            beamTmpUp = SIMD3<Float>(1, 0, 0)
        }
        
        let beamRight = normalize(cross(rotatedDirection, beamTmpUp))
        // Re-calculate true up to ensure orthogonality
        let beamTrueUp = normalize(cross(beamRight, rotatedDirection))
        
        let bundleRadius: Float = 0.0025

        for i in 0..<numRays {
            // Map i to a normalized value 0..1
            let t = Float(i) / Float(max(1, numRays - 1))
            
            // Generate a grid/line of points. Let's do a linear spread for the spectrum effect
            // Spreading them horizontally across the beam width
            let spreadOffset = (t - 0.5) * bundleRadius * 2.0
            let origin = sourceCenter + beamRight * spreadOffset
            
            // Spectrum Mapping
            // t=0 -> Red (Low Frequency, Low Index of Refraction)
            // t=1 -> Violet (High Frequency, High Index of Refraction)
            // Hue: Red is 0.0 (or 1.0). Violet is ~0.75
            let hue = CGFloat(0.75 * t) // Red to Violet
            
            // Physics: Diffraction/Refractive Index
            // Red refracts less, Violet refracts more.
            // Base diffraction 0.2, range 0.2
            let diffraction = -0.4 + 0.8 * t
            
            var tracedLines = centralCube.traceRay(origin: origin, direction: rotatedDirection, diffraction: diffraction, postCubeLength: 10.0)
            
            let color = NSColor(hue: hue, saturation: 1.0, brightness: 1.0, alpha: 1.0)
            let colorDesat = NSColor(hue: hue, saturation: 0.9, brightness: 1.0, alpha: 0.99) // Desaturated for inside
            
            let simdColor = SIMD4<Float>(Float(color.redComponent), Float(color.greenComponent), Float(color.blueComponent), Float(color.alphaComponent))
            let simdColorDesat = SIMD4<Float>(Float(colorDesat.redComponent), Float(colorDesat.greenComponent), Float(colorDesat.blueComponent), Float(colorDesat.alphaComponent))
            
            // Process segments
            // Index 0: Incoming (Outside)
            // Index 1: Inside (Cube) - IF it hit the cube
            // Index 2: Outgoing (Outside)
            
            for j in tracedLines.indices {
                // Default settings
                tracedLines[j].lineWidthStart = lineWidthBase * 1.0
                tracedLines[j].lineWidthEnd = lineWidthBase * 1.0
                var segmentColor = simdColor
                
                // Identify "Inside" segment.
                // traceRay returns [In -> Hit, Hit -> Exit, Exit -> Far]
                // So index 1 is usually inside.
                if tracedLines.count >= 3 && j == 1 {
                     segmentColor = simdColorDesat
                     tracedLines[j].lineWidthStart = lineWidthBase * 1.0
                     tracedLines[j].lineWidthEnd = lineWidthBase * 1.0
                }
                
                tracedLines[j].colorStart = segmentColor
                tracedLines[j].colorEnd = segmentColor
                tracedLines[j].colorStartOuterLeft = segmentColor
                tracedLines[j].colorStartOuterRight = segmentColor
                tracedLines[j].colorEndOuterLeft = segmentColor
                tracedLines[j].colorEndOuterRight = segmentColor
            }
            
            // Draw Hexagon at entry point
            // Entry point is the end of the first line (if there was a hit)
//            if tracedLines.count >= 2 {
//                let entryPoint = tracedLines[0].endPoint
//                // Determine normal based on hit position relative to cube size
//                // Cube size 0.7 -> half size 0.35
//                let halfSize: Float = 0.35
//                var normal = SIMD3<Float>(0, 1, 0)
//                
//                if abs(abs(entryPoint.x) - halfSize) < 0.01 { normal = SIMD3<Float>(sign(entryPoint.x), 0, 0) }
//                else if abs(abs(entryPoint.y) - halfSize) < 0.01 { normal = SIMD3<Float>(0, sign(entryPoint.y), 0) }
//                else if abs(abs(entryPoint.z) - halfSize) < 0.01 { normal = SIMD3<Float>(0, 0, sign(entryPoint.z)) }
//                
//                // Construct Hexagon lines
//                let hexRadius: Float = 0.01
//                let hexColor = simdColor
//                
//                // Basis vectors for the hexagon plane
//                let up = (abs(normal.y) > 0.9) ? SIMD3<Float>(1, 0, 0) : SIMD3<Float>(0, 1, 0)
//                let tangent = normalize(cross(normal, up))
//                let bitangent = normalize(cross(normal, tangent))
//                
//                for k in 0..<6 {
//                    let angle1 = Float(k) * (Float.pi * 2.0 / 6.0)
//                    let angle2 = Float(k + 1) * (Float.pi * 2.0 / 6.0)
//                    
//                    let p1 = entryPoint + (tangent * cos(angle1) + bitangent * sin(angle1)) * hexRadius
//                    let p2 = entryPoint + (tangent * cos(angle2) + bitangent * sin(angle2)) * hexRadius
//                    
//                    var hexLine = Line(startPoint: p1, endPoint: p2)
//                    hexLine.lineWidthStart = lineWidthBase * 0.2
//                    hexLine.lineWidthEnd = lineWidthBase * 0.2
//                    hexLine.colorStart = hexColor
//                    hexLine.colorEnd = hexColor
//                    hexLine.colorStartOuterLeft = hexColor
//                    hexLine.colorStartOuterRight = hexColor
//                    hexLine.colorEndOuterLeft = hexColor
//                    hexLine.colorEndOuterRight = hexColor
//                    
//                    traceLines.append(hexLine)
//                }
//            }
            
            traceLines.append(contentsOf: tracedLines)
        }
        outputLines.append(contentsOf: traceLines)

        // Apply a final rotation to the whole scene
        // Rotate in roughly the opposite direction to the light source, but with slightly different speeds
        // Source speeds were approx: X: 0.057, Y: 0.083, Z: 0.041
        let finalRotX = matrix_rotation(angle: Float(time * 0.045), axis: SIMD3<Float>(1, 0, 0))
        let finalRotY = matrix_rotation(angle: Float(time * 0.070), axis: SIMD3<Float>(0, 1, 0))
        let finalRotZ = matrix_rotation(angle: Float(time * 0.035), axis: SIMD3<Float>(0, 0, 1))
        
        let totalFinalRotation = finalRotZ * finalRotY * finalRotX
        
        for i in outputLines.indices {
            outputLines[i] = outputLines[i].applyMatrix(totalFinalRotation)
        }
        
        return (outputLines, 0.0)
    }
}
