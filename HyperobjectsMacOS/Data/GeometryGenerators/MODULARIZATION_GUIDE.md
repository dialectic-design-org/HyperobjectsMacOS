# Modularization Guide for Genuary2026Generator.swift

## Current State Analysis

The file is approximately **2,722 lines** containing a monolithic geometry generator for Genuary 2026 creative coding challenges. It has significant structural issues that impact readability and maintainability.

### Current Structure

```
Lines 1-26:     Global text state variables
Lines 30-44:    City layout configuration
Lines 45-233:   Standalone utility functions (4 functions)
Lines 236-259:  Global simulator/object instances
Lines 261-2721: Genuary2026Generator class
  └── generateGeometriesFromInputs (one ~2400 line method)
      └── if-else chain: Day 1, 2, 3... 17
      └── Text rendering logic (~400 lines)
```

---

## Modularization Opportunities

### 1. Extract Day Implementations into Separate Files

**Problem**: The main method contains a massive `if dayNumber == "1" ... else if dayNumber == "17"` chain with 17 independent visual experiments in a single method.

**Solution**: Create a `Genuary2026Days/` folder with individual files per day.

**Proposed structure**:
```
GeometryGenerators/
├── Genuary2026Generator.swift (orchestrator, ~200 lines)
└── Genuary2026Days/
    ├── Day01_Cube.swift
    ├── Day02_AnimatedCube.swift
    ├── Day03_FibonacciCubes.swift
    ├── Day04_SpiralVoxels.swift
    ├── Day05_CubeText.swift
    ├── Day06_StrobeCubes.swift
    ├── Day07_CubeIntersection.swift
    ├── Day08_Metropolis.swift
    ├── Day09_CellularAutomata.swift
    ├── Day10_SphericalArcs.swift
    ├── Day11_QuineCellularAutomata.swift
    ├── Day12_ColorCubes.swift
    ├── Day13_SelfPortrait.swift
    ├── Day14_RubiksCube.swift
    ├── Day15_Shadows.swift
    ├── Day16_BouncyCube.swift
    └── Day17_Wallpaper.swift
```

**Instructions**:

1. Create a protocol `GenuaryDayGenerator`:
   ```swift
   protocol GenuaryDayGenerator {
       var dayNumber: String { get }
       func generateLines(
           inputs: [String: Any],
           scene: GeometriesSceneBase,
           time: Double,
           lineWidthBase: Float,
           state: Genuary2026State
       ) -> (lines: [Line], replacementProbability: Float)
   }
   ```

2. Each day becomes a struct conforming to this protocol. Example for Day 1:
   ```swift
   // Day01_Cube.swift
   struct Day01_Cube: GenuaryDayGenerator {
       let dayNumber = "1"

       func generateLines(
           inputs: [String: Any],
           scene: GeometriesSceneBase,
           time: Double,
           lineWidthBase: Float,
           state: Genuary2026State
       ) -> (lines: [Line], replacementProbability: Float) {
           var outputLines = makeCube(size: 0.52, offset: 0)
           return (outputLines, 0.0) // default replacement probability
       }
   }
   ```

3. The main generator maintains a dictionary for dispatch:
   ```swift
   class Genuary2026Generator: CachedGeometryGenerator {
       private let dayGenerators: [String: GenuaryDayGenerator] = [
           "1": Day01_Cube(),
           "2": Day02_AnimatedCube(),
           "3": Day03_FibonacciCubes(),
           // ... etc
       ]

       override func generateGeometriesFromInputs(...) -> [any Geometry] {
           let dayNumber = stringFromInputs(inputs, name: "Day")

           if let generator = dayGenerators[dayNumber] {
               let result = generator.generateLines(...)
               // Apply common transformations, add text, etc.
           }
       }
   }
   ```

4. Move each `if dayNumber == "X" { ... }` block into its own file

---

### 2. Extract Utility Functions into a Utilities File

**Problem**: Lines 45-233 contain utility functions at file scope that are mixed with the generator class.

**Create file** `Genuary2026Utilities.swift`:

```swift
// Genuary2026Utilities.swift

import Foundation
import simd

/// Converts an array of 3D points to lines, trimming by distance along the path
/// - Parameters:
///   - points: Array of SIMD3<Float> points
///   - start: Start position as fraction (0-1) of total path length
///   - end: End position as fraction (0-1) of total path length
/// - Returns: Array of Line segments
func simd3ArrayToLinesWithOffset(_ points: [SIMD3<Float>], start: Float, end: Float) -> [Line] {
    // ... move lines 45-96 here
}

/// Trims lines to a moving window that wraps around
/// - Parameters:
///   - pathLines: Input lines
///   - windowCenter: Center of window along path
///   - windowSize: Size of window
/// - Returns: Trimmed line segments
func trimLinesToMovingWindow(pathLines: [Line], windowCenter: Float, windowSize: Float) -> [Line] {
    // ... move lines 98-166 here
}

/// Mutates a string by randomly replacing/restoring characters
/// - Parameters:
///   - original: The original string to compare against
///   - current: The current (possibly mutated) string
///   - pReplace: Probability of replacing a character
///   - pRestore: Probability of restoring a replaced character
///   - replacementMap: Map tracking which indices have been replaced
///   - replacementCharacters: Pool of replacement characters
/// - Returns: The mutated string
func mutateString(
    original: String,
    current: String,
    pReplace: Double,
    pRestore: Double,
    replacementMap: inout [Int: Character],
    replacementCharacters: String
) -> String {
    // ... move lines 169-213 here
}

/// Returns a random character different from the excluded one
func randomCharacter(excluding excluded: Character, sampleSet: String = "$#%@*!+") -> Character {
    // ... move lines 216-233 here
}
```

---

### 3. Encapsulate Global State into a State Manager

**Problem**: Multiple global variables scattered at file scope (lines 12-26, 236-259) make the code hard to reason about.

**Current global state to encapsulate**:
- Text mutation state: `currentTextMainTitle`, `mapMainTitle`, `currentTextDay`, `mapDay`, etc.
- Simulator instances: `automaton`, `genuary2026r_cube`, `bouncyCubeSimulator`
- Configuration: `cityLayoutParams`, `cityLayout`, `wallpaperLattice`, `wallpaperBricks`, `wallpaperBricksRotations`

**Create file** `Genuary2026State.swift`:

```swift
// Genuary2026State.swift

import Foundation
import simd

class Genuary2026State {

    // MARK: - Text Mutation State

    struct TextState {
        var currentText: String
        var replacementMap: [Int: Character] = [:]

        mutating func mutate(
            original: String,
            pReplace: Double,
            pRestore: Double,
            replacementCharacters: String
        ) -> String {
            currentText = mutateString(
                original: original,
                current: currentText,
                pReplace: pReplace,
                pRestore: pRestore,
                replacementMap: &replacementMap,
                replacementCharacters: replacementCharacters
            )
            return currentText
        }
    }

    var mainTitle = TextState(currentText: "Genuary")
    var day = TextState(currentText: "Day 17")
    var year = TextState(currentText: "2026")
    var prompt = TextState(currentText: "Wallpaper.")
    var credit = TextState(currentText: "socratism.io")

    let replacementCharacters = "genuaryGENUARY2026"

    // MARK: - Day-Specific State (Lazy Initialization)

    // Day 9: Cellular Automata
    lazy var automaton: CellularAutomata3D = {
        var ca = CellularAutomata3D.cube(size: 8, preset: .dense)
        ca.wrapsAtEdges = true
        return ca
    }()

    // Day 14: Rubik's Cube
    lazy var rubiksCube: RubiksCube = {
        var cube = RubiksCube()
        cube.scramble(moveCount: 50)
        return cube
    }()

    // Day 16: Bouncy Cube Physics
    lazy var bouncyCubeSimulator: CubePhysicsSimulator = {
        let outerSize: Float = 2.0
        let innerSize: Float = 0.65
        let simulator = CubePhysicsSimulator(
            outerCubeCenter: SIMD3<Float>(0, 0, 0),
            outerCubeRotation: SIMD3<Float>(0, 0, 0),
            outerCubeSize: SIMD3<Float>(repeating: outerSize),
            innerCubeCenter: SIMD3<Float>(0, 0.5, 0),
            innerCubeRotation: SIMD3<Float>(0.1, 0.2, 0.3),
            innerCubeSize: SIMD3<Float>(repeating: innerSize),
            innerCubeMass: 1.0
        )
        simulator.restitution = 0.95
        simulator.friction = 0.3
        simulator.gravity = SIMD3<Float>(0, -5.81, 0)
        return simulator
    }()

    let bouncyOuterCubeSize: Float = 2.0
    let bouncyInnerCubeSize: Float = 0.65
    let bouncyCubeRenderScale: Float = 0.8

    // Day 8: City Layout
    var cityLayoutParams: [String: Any] = [
        "name": "New City",
        "population": 500,
        "area": 500.0,
        "gdp": 300.0,
        "gridRows": 4,
        "gridColumns": 20,
        "blockSize": SIMD2<Double>(1.0, 1.0)
    ]

    lazy var cityLayout: Metropolis = {
        Metropolis(
            name: "New City",
            gridRows: cityLayoutParams["gridRows"] as! Int,
            gridColumns: cityLayoutParams["gridColumns"] as! Int,
            blockSize: cityLayoutParams["blockSize"] as! SIMD2<Double>
        )
    }()

    func regenerateCityLayout() {
        cityLayout = Metropolis(
            name: "New City",
            gridRows: cityLayoutParams["gridRows"] as! Int,
            gridColumns: cityLayoutParams["gridColumns"] as! Int,
            blockSize: cityLayoutParams["blockSize"] as! SIMD2<Double>
        )
    }

    // Day 17: Wallpaper
    lazy var wallpaperLattice = HerringboneLattice(shortSide: 0.12)
    lazy var wallpaperBounds = CGRect(x: -1.0, y: -0.25, width: 2.0, height: 0.5)
    lazy var wallpaperBricks: [HerringboneBrick] = {
        wallpaperLattice.generateBricks(in: wallpaperBounds)
    }()
    lazy var wallpaperBricksRotations: [Float] = {
        Array(repeating: 0.0, count: wallpaperBricks.count)
    }()
}
```

**Usage in main generator**:
```swift
class Genuary2026Generator: CachedGeometryGenerator {
    private let state = Genuary2026State()

    // Now pass state to day generators
    let result = dayGenerator.generateLines(inputs: inputs, scene: scene, time: time, lineWidthBase: lineWidthBase, state: state)
}
```

---

### 4. Extract Text Rendering into a Dedicated Component

**Problem**: Text rendering logic (lines 2298-2715) is ~400 lines embedded in the main method, including day-specific color variations.

**Create file** `Genuary2026TextRenderer.swift`:

```swift
// Genuary2026TextRenderer.swift

import Foundation
import simd
import SwiftUI

struct Genuary2026TextRenderer {

    // MARK: - Text Style

    struct TextStyle {
        var mainTitleColor: SIMD4<Float>
        var offWhiteColor: SIMD4<Float>
        var lineWidthBase: Float
        var mainFont: String
        var secondaryFont: String
        var mainFontSize: CGFloat = 0.075
    }

    // MARK: - Day-Specific Styling

    static func styleForDay(
        _ dayNumber: String,
        time: Double,
        bouncyCubeSimulator: CubePhysicsSimulator? = nil
    ) -> TextStyle {
        var textColor = SIMD4<Float>(1.0, 1.0, 1.0, 1.0)
        var offWhite = SIMD4<Float>(0.9, 0.9, 0.9, 1.0)

        switch dayNumber {
        case "6":
            let pulse = pulsedWave(t: Float(time), frequency: 10.0, steepness: 100.0)
            offWhite = SIMD4<Float>(0.2 + pulse * 0.5, 0.2 + pulse * 0.5, 0.2 + pulse * 0.5, 1.0)
            textColor = SIMD4<Float>(0.3 + pulse * 0.5, 0.3 + pulse * 0.5, 0.3 + pulse * 0.5, 1.0)

        case "7":
            textColor = SIMD4<Float>(0.7, 0.7, 0.7, 1.0)
            offWhite = SIMD4<Float>(0.8, 0.8, 0.8, 1.0)

        case "8":
            textColor = SIMD4<Float>(0.3, 0.3, 0.3, 1.0)
            offWhite = SIMD4<Float>(0.2, 0.2, 0.2, 1.0)

        case "9":
            textColor = SIMD4<Float>(0.5, 0.5, 0.5, 1.0)
            offWhite = SIMD4<Float>(0.2, 0.2, 0.2, 1.0)

        case "11":
            textColor = SIMD4<Float>(0.3, 0.3, 0.3, 1.0)
            offWhite = SIMD4<Float>(0.2, 0.2, 0.2, 1.0)

        case "13":
            textColor = SIMD4<Float>(0.05, 0.0, 0.3, 1.0)
            offWhite = SIMD4<Float>(0.05, 0.0, 0.35, 1.0)

        case "15":
            textColor = SIMD4<Float>(0.3, 0.0, 0.1, 1.0)
            offWhite = SIMD4<Float>(0.2, 0.0, 0.1, 1.0)

        case "16":
            if let simulator = bouncyCubeSimulator {
                let innerState = simulator.getInnerCubeState()
                let linearSpeed = simd_length(innerState.velocity)
                let angularSpeed = simd_length(innerState.angularVelocity)
                let linearFactor = min(1.0, linearSpeed * 0.08)
                let angularFactor = min(1.0, angularSpeed * 0.15)

                textColor = SIMD4<Float>(linearFactor * 0.9, linearFactor * 0.9, linearFactor * 0.9, 1.0)
                offWhite = SIMD4<Float>(0.2 * angularFactor, 0.2 * angularFactor, 0.2 * angularFactor, 1.0)
            }

        case "17":
            offWhite = SIMD4<Float>(1.0, 0.5, 0.2, 1.0)
            textColor = SIMD4<Float>(1.0, 0.3, 0.5, 1.0)

        default:
            break
        }

        return TextStyle(
            mainTitleColor: textColor,
            offWhiteColor: offWhite,
            lineWidthBase: 1.0, // Will be set by caller
            mainFont: "",       // Will be set by caller
            secondaryFont: ""   // Will be set by caller
        )
    }

    // MARK: - Text Rendering

    func renderAllText(
        mainTitle: String,
        day: String,
        year: String,
        prompt: String,
        credit: String,
        style: TextStyle,
        lightingFunction: ((Line, SIMD4<Float>) -> Line)? = nil
    ) -> [Line] {
        var lines: [Line] = []
        let leftAlignValue: Float = -0.8

        let applyLighting: (Line, SIMD4<Float>) -> Line = lightingFunction ?? { line, color in
            var mutableLine = line
            return mutableLine.setBasicEndPointColors(startColor: color, endColor: color)
        }

        // Main title
        let mainTitleLines = textToBezierPaths(
            mainTitle,
            font: .custom(style.mainFont, size: 48),
            fontName: style.mainFont,
            size: style.mainFontSize * 0.5,
            maxLineWidth: 10.0
        )
        let mainTitleTransform = matrix_translation(translation: SIMD3<Float>(
            leftAlignValue * 0.5, 0.043, 1.0
        ))
        lines.append(contentsOf: renderTextLines(
            mainTitleLines,
            transform: mainTitleTransform,
            color: style.mainTitleColor,
            lineWidth: style.lineWidthBase,
            lightingFunction: applyLighting
        ))

        // Year (large, in background)
        let yearLines = textToBezierPaths(
            year,
            font: .custom(style.mainFont, size: 48),
            fontName: style.mainFont,
            size: style.mainFontSize * 7.95,
            maxLineWidth: 10.0
        )
        let yearTransform = matrix_translation(translation: SIMD3<Float>(
            leftAlignValue - 0.441, 0.0, -0.5
        ))
        lines.append(contentsOf: renderTextLines(
            yearLines,
            transform: yearTransform,
            color: style.offWhiteColor,
            lineWidth: style.lineWidthBase,
            lightingFunction: applyLighting
        ))

        // Day text
        let dayLines = textToBezierPaths(
            day,
            font: .custom(style.mainFont, size: 48),
            fontName: style.mainFont,
            size: style.mainFontSize * 0.5,
            maxLineWidth: 10.0
        )
        let dayTransform = matrix_translation(translation: SIMD3<Float>(
            leftAlignValue * 0.5, 0.0, 1.0
        ))
        lines.append(contentsOf: renderTextLines(
            dayLines,
            transform: dayTransform,
            color: style.mainTitleColor,
            lineWidth: style.lineWidthBase,
            lightingFunction: applyLighting
        ))

        // Prompt text
        let promptLines = textToBezierPaths(
            prompt,
            font: .custom(style.secondaryFont, size: 48),
            fontName: style.secondaryFont,
            size: style.mainFontSize * 0.25,
            maxLineWidth: 10.0
        )
        let promptTransform = matrix_translation(translation: SIMD3<Float>(
            leftAlignValue * 0.5, -0.1, 1.0
        ))
        lines.append(contentsOf: renderTextLines(
            promptLines,
            transform: promptTransform,
            color: style.mainTitleColor,
            lineWidth: style.lineWidthBase * 0.5,
            lightingFunction: applyLighting
        ))

        // Credit text
        let creditLines = textToBezierPaths(
            credit,
            font: .custom(style.secondaryFont, size: 48),
            fontName: style.secondaryFont,
            size: style.mainFontSize * 0.25,
            maxLineWidth: 10.0
        )
        let creditTransform = matrix_translation(translation: SIMD3<Float>(
            0.25, -0.1, 1.0
        ))
        lines.append(contentsOf: renderTextLines(
            creditLines,
            transform: creditTransform,
            color: style.mainTitleColor,
            lineWidth: style.lineWidthBase * 0.5,
            lightingFunction: applyLighting
        ))

        return lines
    }

    // MARK: - Helper

    private func renderTextLines(
        _ textLines: [[Line]],
        transform: matrix_float4x4,
        color: SIMD4<Float>,
        lineWidth: Float,
        lightingFunction: (Line, SIMD4<Float>) -> Line
    ) -> [Line] {
        var result: [Line] = []

        for char in textLines {
            for line in char {
                var transformedLine = Line(
                    startPoint: line.startPoint,
                    endPoint: line.endPoint,
                    degree: line.degree,
                    controlPoints: line.controlPoints,
                    lineWidthStart: lineWidth,
                    lineWidthEnd: lineWidth
                )
                transformedLine = transformedLine.applyMatrix(transform)
                transformedLine = lightingFunction(transformedLine, color)
                result.append(transformedLine)
            }
        }

        return result
    }
}
```

---

### 5. Extract Duplicated Lighting Calculations

**Problem**: `calculateLitColor` and `calculateRedHighlight` appear identically at:
- Lines 1833-1870 (Day 13 portrait)
- Lines 2528-2550 (Day 13 text lighting)

**Create file** `LightingHelpers.swift`:

```swift
// LightingHelpers.swift

import Foundation
import simd

struct LightingHelpers {

    /// Generates a smooth, quasi-periodic path on a unit sphere
    /// - Parameter t: Time parameter
    /// - Returns: Normalized point on sphere
    static func fluidSpherePath(time t: Float) -> SIMD3<Float> {
        let x = sin(0.73 * t) + 0.37 * sin(2.19 * t + 0.5)
        let y = cos(1.11 * t) + 0.29 * cos(2.93 * t + 1.3)
        let z = 0.85 * sin(0.53 * t + 1.0) + 0.52 * sin(1.87 * t + 2.2)
        return simd_normalize(SIMD3<Float>(x, y, z))
    }

    /// Calculates lit color for a point based on light position
    /// Creates white -> yellow -> red -> black gradient based on distance
    /// - Parameters:
    ///   - point: Point to calculate color for
    ///   - lightPos: Position of the light source
    ///   - maxDistance: Maximum distance for falloff calculation
    ///   - colorMultiplier: Multiplier for final color intensity
    /// - Returns: SIMD4 color value
    static func calculateLitColor(
        for point: SIMD3<Float>,
        lightPos: SIMD3<Float>,
        maxDistance: Float = 2.5,
        colorMultiplier: Float = 1.4
    ) -> SIMD4<Float> {
        let toLight = lightPos - point
        let distanceToLight = simd_length(toLight)
        let normalizedDist = min(distanceToLight / maxDistance, 1.0)
        let input = Double(1.0 - normalizedDist)

        // Different thresholds create color shift from White -> Yellow -> Red -> Black
        let rSig = Float(sigmoidFunction(input: input, steepness: 15.0, threshold: 0.65))
        let gSig = Float(sigmoidFunction(input: input, steepness: 25.0, threshold: 0.55))
        let bSig = Float(sigmoidFunction(input: input, steepness: 25.0, threshold: 0.45))

        return SIMD4<Float>(
            colorMultiplier * rSig,
            colorMultiplier * gSig,
            colorMultiplier * bSig,
            1.0
        )
    }

    /// Calculates a red highlight accent for a point
    /// - Parameters:
    ///   - point: Point to calculate highlight for
    ///   - lightPos: Position of the secondary light source
    ///   - maxDistance: Maximum distance for falloff
    /// - Returns: SIMD4 color value (red channel only)
    static func calculateRedHighlight(
        for point: SIMD3<Float>,
        lightPos: SIMD3<Float>,
        maxDistance: Float = 2.5
    ) -> SIMD4<Float> {
        let toLight = lightPos - point
        let distanceToLight = simd_length(toLight)
        let normalizedDist = min(distanceToLight / maxDistance, 1.0)
        let input = Double(1.0 - normalizedDist)
        let rSig = Float(sigmoidFunction(input: input, steepness: 30.0, threshold: 0.6))

        return SIMD4<Float>(2.5 * rSig, 0.0, 0.0, 0.0)
    }

    /// Creates a lighting function for Day 13 style point lighting
    /// - Parameter time: Current time for light animation
    /// - Returns: Closure that applies lighting to a line
    static func day13LightingFunction(time: Double) -> (Line, SIMD4<Float>) -> Line {
        let lightPoint = fluidSpherePath(time: Float(time * 0.5))
        let lightPoint2 = fluidSpherePath(time: Float(time * 0.5 + 200.0))

        return { line, defaultColor in
            var startColor = calculateLitColor(for: line.startPoint, lightPos: lightPoint)
            var endColor = calculateLitColor(for: line.endPoint, lightPos: lightPoint)

            let startRed = calculateRedHighlight(for: line.startPoint, lightPos: lightPoint2)
            let endRed = calculateRedHighlight(for: line.endPoint, lightPos: lightPoint2)

            startColor += startRed
            endColor += endRed
            startColor.w = 1.0
            endColor.w = 1.0

            var mutableLine = line
            return mutableLine.setBasicEndPointColors(startColor: startColor, endColor: endColor)
        }
    }
}
```

---

### 6. Create Common Transformation Helpers

**Problem**: Nearly every day implementation repeats the same pattern:
```swift
for i in lines.indices {
    lines[i] = lines[i].applyMatrix(matrix)
    lines[i] = lines[i].setBasicEndPointColors(startColor: color, endColor: color)
    lines[i].lineWidthStart = lineWidthBase * multiplier
    lines[i].lineWidthEnd = lineWidthBase * multiplier
}
```

**Create file** `LineArrayExtensions.swift`:

```swift
// LineArrayExtensions.swift

import Foundation
import simd

extension Array where Element == Line {

    /// Applies transformations to all lines in the array
    /// - Parameters:
    ///   - matrix: Optional transformation matrix to apply
    ///   - color: Optional color to set (applied to both endpoints)
    ///   - lineWidth: Optional line width to set (applied to both ends)
    mutating func applyToAll(
        matrix: matrix_float4x4? = nil,
        color: SIMD4<Float>? = nil,
        lineWidth: Float? = nil
    ) {
        for i in indices {
            if let m = matrix {
                self[i] = self[i].applyMatrix(m)
            }
            if let c = color {
                self[i] = self[i].setBasicEndPointColors(startColor: c, endColor: c)
            }
            if let w = lineWidth {
                self[i].lineWidthStart = w
                self[i].lineWidthEnd = w
            }
        }
    }

    /// Applies transformation and styling in one call
    /// - Parameters:
    ///   - matrices: Array of matrices to apply in order
    ///   - color: Color to set
    ///   - lineWidthBase: Base line width
    ///   - lineWidthMultiplier: Multiplier for line width
    mutating func styleAndTransform(
        matrices: [matrix_float4x4] = [],
        color: SIMD4<Float>,
        lineWidthBase: Float,
        lineWidthMultiplier: Float = 1.0
    ) {
        for i in indices {
            for matrix in matrices {
                self[i] = self[i].applyMatrix(matrix)
            }
            self[i] = self[i].setBasicEndPointColors(startColor: color, endColor: color)
            self[i].lineWidthStart = lineWidthBase * lineWidthMultiplier
            self[i].lineWidthEnd = lineWidthBase * lineWidthMultiplier
        }
    }

    /// Returns a copy with transformations applied
    func applying(
        matrix: matrix_float4x4? = nil,
        color: SIMD4<Float>? = nil,
        lineWidth: Float? = nil
    ) -> [Line] {
        var result = self
        result.applyToAll(matrix: matrix, color: color, lineWidth: lineWidth)
        return result
    }
}
```

**Usage example**:
```swift
// Before (repeated ~50 times in the file):
for i in cubeLines.indices {
    cubeLines[i] = cubeLines[i].applyMatrix(rotationMatrix)
    cubeLines[i] = cubeLines[i].setBasicEndPointColors(startColor: cubeColor, endColor: cubeColor)
    cubeLines[i].lineWidthStart = lineWidthBase * 4
    cubeLines[i].lineWidthEnd = lineWidthBase * 4
}

// After:
cubeLines.applyToAll(matrix: rotationMatrix, color: cubeColor, lineWidth: lineWidthBase * 4)

// Or even simpler:
cubeLines.styleAndTransform(
    matrices: [rotationMatrix],
    color: cubeColor,
    lineWidthBase: lineWidthBase,
    lineWidthMultiplier: 4
)
```

---

## Recommended File Structure After Refactoring

```
GeometryGenerators/
├── Genuary2026/
│   ├── Genuary2026Generator.swift      (~150 lines - orchestrator)
│   ├── Genuary2026State.swift          (~80 lines - state container)
│   ├── Genuary2026Utilities.swift      (~200 lines - utility functions)
│   ├── Genuary2026TextRenderer.swift   (~150 lines - text rendering)
│   ├── LightingHelpers.swift           (~60 lines - lighting math)
│   ├── LineArrayExtensions.swift       (~30 lines - transformation helpers)
│   └── Days/
│       ├── GenuaryDayProtocol.swift    (~20 lines - protocol definition)
│       ├── Day01_Cube.swift            (~50 lines)
│       ├── Day02_AnimatedCube.swift    (~150 lines)
│       ├── Day03_FibonacciCubes.swift  (~250 lines)
│       ├── Day04_SpiralVoxels.swift    (~100 lines)
│       ├── Day05_CubeText.swift        (~80 lines)
│       ├── Day06_StrobeCubes.swift     (~100 lines)
│       ├── Day07_CubeIntersection.swift (~100 lines)
│       ├── Day08_Metropolis.swift      (~150 lines)
│       ├── Day09_CellularAutomata.swift (~80 lines)
│       ├── Day10_SphericalArcs.swift   (~120 lines)
│       ├── Day11_QuineCellularAutomata.swift (~60 lines)
│       ├── Day12_ColorCubes.swift      (~80 lines)
│       ├── Day13_SelfPortrait.swift    (~300 lines)
│       ├── Day14_RubiksCube.swift      (~150 lines)
│       ├── Day15_Shadows.swift         (~80 lines)
│       ├── Day16_BouncyCube.swift      (~100 lines)
│       └── Day17_Wallpaper.swift       (~150 lines)
```

---

## Suggested Implementation Order

### Phase 1: Foundation (Low Risk)
1. **Create `LineArrayExtensions.swift`** - Add the array extension, start using it in-place
2. **Create `Genuary2026Utilities.swift`** - Move the 4 utility functions
3. **Create `LightingHelpers.swift`** - Extract lighting calculations

### Phase 2: State Management
4. **Create `Genuary2026State.swift`** - Move all global state
5. **Update main generator to use state** - Pass state instance where needed

### Phase 3: Protocol & First Extractions
6. **Create `GenuaryDayProtocol.swift`** - Define the day generator interface
7. **Extract Day01 and Day11** - Start with the simplest days (Day01 is ~30 lines, Day11 is ~40 lines)
8. **Extract Day02** - Slightly more complex, good practice

### Phase 4: Bulk Extraction
9. **Extract remaining simple days** - Day03, Day04, Day05, Day06, Day07, Day10, Day12, Day15
10. **Extract complex days** - Day08 (Metropolis), Day09 (CA), Day13 (Portrait), Day14 (Rubik's), Day16 (Physics), Day17 (Wallpaper)

### Phase 5: Text Rendering
11. **Create `Genuary2026TextRenderer.swift`** - Extract text rendering
12. **Final cleanup** - Remove any remaining duplication, update imports

---

## Benefits After Refactoring

| Aspect | Before | After |
|--------|--------|-------|
| Main file size | 2,722 lines | ~150 lines |
| Finding Day 13 code | Scroll through 2400 lines | Open `Day13_SelfPortrait.swift` |
| Adding Day 18 | Add to massive if-else | Create new file, register in dictionary |
| Testing a single day | Not possible | Import and test individual day |
| Understanding text flow | Mixed with geometry | Dedicated `TextRenderer` file |
| Code reuse | Copy-paste patterns | Use extensions and helpers |
| Onboarding new contributor | Overwhelming | Clear, focused files |

---

## Quick Reference: Day Line Ranges

Use these to locate each day's code block when extracting:

| Day | Start Line | End Line | Approx. Lines | Key Features |
|-----|------------|----------|---------------|--------------|
| 1 | 362 | 364 | ~2 | Simple cube |
| 2 | 365 | 495 | ~130 | Animated squishing cube |
| 3 | 496 | 901 | ~405 | Fibonacci cubes with insets |
| 4 | 902 | 1009 | ~107 | Spiral with voxel grid |
| 5 | 1010 | 1076 | ~66 | Cube text "GENUARY" |
| 6 | 1077 | 1171 | ~94 | Strobe effect cubes |
| 7 | 1172 | 1248 | ~76 | Two cube intersection |
| 8 | 1249 | 1352 | ~103 | Metropolis city |
| 9 | 1353 | 1398 | ~45 | 3D Cellular automata |
| 10 | 1399 | 1504 | ~105 | Spherical arc chains |
| 11 | 1505 | 1544 | ~39 | Quine 1D CA visualization |
| 12 | 1545 | 1603 | ~58 | Color cubes with input |
| 13 | 1604 | 1910 | ~306 | Self portrait with lighting |
| 14 | 1911 | 2022 | ~111 | Rubik's cube animation |
| 15 | 2023 | 2071 | ~48 | Shadow projection |
| 16 | 2072 | 2136 | ~64 | Bouncy physics cube |
| 17 | 2137 | 2252 | ~115 | Wallpaper herringbone |
