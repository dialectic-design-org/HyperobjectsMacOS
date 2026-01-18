//
//  Day17_Wallpaper.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 18/01/2026.
//

import CoreGraphics

let wallpaperLattice = HerringboneLattice(shortSide: 0.12)
let wallpaperBounds = CGRect(x: -1.0, y: -0.25, width: 2.0, height: 0.5)
let wallpaperBricks = wallpaperLattice.generateBricks(in: wallpaperBounds)
var wallpaperBricksRotations: [Float] = []

struct Day17_Wallpaper: GenuaryDayGenerator {
    let dayNumber = "17"

    func generateLines(
        inputs: [String: Any],
        scene: GeometriesSceneBase,
        time: Double,
        lineWidthBase: Float,
        state: Genuary2026State
    ) -> (lines: [Line], replacementProbability: Float) {
        
        var outputLines: [Line] = []
        var colorLine = Line(
            startPoint: SIMD3<Float>(0.0, -0.5, 0.0), endPoint: SIMD3<Float>(0.0, 0.5, 0.0)
        )
        
        colorLine.setBasicEndPointColors(
            startColor: SIMD4<Float>(1.0, 0.5, 0.2, 1.0),
            endColor: SIMD4<Float>(1.0, 0.2, 0.5, 1.0)
        )
        colorLine.lineWidthStart = lineWidthBase * 5
        colorLine.lineWidthEnd = lineWidthBase * 5
        
        var lineAnimSpeedMultiplier: Double = 0.5
        
        var clTMatBefore = matrix_translation(translation: SIMD3<Float>(
            sin(Float(time * 0.05 * lineAnimSpeedMultiplier)) * 0.2,
            sin(Float(time * 0.04 * lineAnimSpeedMultiplier)) * 0.1,
            sin(Float(time * 0.0266 * lineAnimSpeedMultiplier)) * 0.2,
        ))
        
        var clRMatX = matrix_rotation(angle: Float(time * 0.15 * lineAnimSpeedMultiplier), axis: SIMD3<Float>(1.0, 0.0, 0.0))
        var clRMatY = matrix_rotation(angle: Float(time * 0.22 * lineAnimSpeedMultiplier), axis: SIMD3<Float>(0.0, 1.0, 0.0))
        var clRMatZ = matrix_rotation(angle: Float(time * 0.28 * lineAnimSpeedMultiplier), axis: SIMD3<Float>(0.0, 0.0, 1.0))
        
        var clTMatAfter = matrix_translation(translation: SIMD3<Float>(
            sin(Float(time * 0.4 * lineAnimSpeedMultiplier)) * 1.0,
            0.0,
            cos(Float(time * 0.1 * lineAnimSpeedMultiplier)) * 0.25,
        ))
        
        var clFullMat = clTMatAfter * clRMatZ * clRMatY * clRMatX * clTMatBefore
        colorLine = colorLine.applyMatrix(clFullMat)
        
        outputLines.append(colorLine)
        
        
        for (bi, brick) in wallpaperBricks.enumerated() {
            let rMat = matrix_rotation(angle: brick.rotation, axis: SIMD3<Float>(0.0, 0.0, 1.0))
            let tMat = matrix_translation(translation: SIMD3<Float>(brick.center.x, brick.center.y, 0.0))
            let sizingMultiplier: Float = 1.8
            let sMat = matrix_scale(scale: SIMD3<Float>(
                brick.halfSize.x * sizingMultiplier,
                brick.halfSize.y * sizingMultiplier,
                brick.halfSize.y * sizingMultiplier)
            )
            let totalMat =  tMat * rMat * sMat
            var brickLines = Cube(center: .zero, size: 1.0).wallOutlines()
            
            var brickDistanceT = colorLine.closestTFromPoint(SIMD3<Float>(brick.center.x, brick.center.y, 0.0))
            // Distance along color line from center point of brick
            let brickDistancePoint = colorLine.interpolate(t: brickDistanceT)
            var brickToColorLine = brickDistancePoint - SIMD3<Float>(brick.center.x, brick.center.y, 0.0)
            let brickToColorLineDistance = simd_length(brickToColorLine)
            // Apply sigmoid to distance and then apply rotation based on inverse distance, more rotation when closer
            let sigmoidDistance = Float(sigmoidFunction(input: Double(brickToColorLineDistance), steepness: 10.0, threshold: 0.3))
            
            // Closer bricks rotate more

            wallpaperBricksRotations[bi] += (0.9 - sigmoidDistance) * 0.02
            
            // Use accumulated rotation for smoother effect
            let accumulatedRotation = wallpaperBricksRotations[bi]
            let distanceOffsetRotation = matrix_rotation(angle: accumulatedRotation, axis: SIMD3<Float>(1.0, 0.0, 0.0))
            let adjustedTotalMat = tMat * rMat * distanceOffsetRotation * sMat

            // Slightly push the brick away from the line based on inverse sigmoid distance
            let pushDistance: Float = (1.0 - sigmoidDistance) * 0.5
            let pushDirection = simd_normalize(brickToColorLine)
            let pushTranslation = matrix_translation(translation: pushDirection * -pushDistance)
            let finalAdjustedTotalMat = pushTranslation * adjustedTotalMat
            
            
            for i in brickLines.indices {
                
                let startT = colorLine.closestTFromPoint(brickLines[i].startPoint)
                let endT = colorLine.closestTFromPoint(brickLines[i].endPoint)
                var startColorFromLine = colorLine.colorAtT(startT)
                var endColorFromLine = colorLine.colorAtT(endT)
                var startTPoint = colorLine.interpolate(t: startT)
                var endTPoint = colorLine.interpolate(t: endT)

                var blickLineStartToColorLine = startTPoint - brickLines[i].startPoint
                var blickLineEndToColorLine = endTPoint - brickLines[i].endPoint

                // Apply sigmoid to distance to color line to get a falloff effect
                let startDistance = simd_length(blickLineStartToColorLine)
                let endDistance = simd_length(blickLineEndToColorLine)
                let maxDistance: Float = 1.0
                let startDistanceNorm = min(startDistance / maxDistance, 1.0)
                let endDistanceNorm = min(endDistance / maxDistance, 1.0)
                let startFalloff = Float(sigmoidFunction(input: Double(1.0 - startDistanceNorm), steepness: 10.0, threshold: 0.2))
                let endFalloff = Float(sigmoidFunction(input: Double(1.0 - endDistanceNorm), steepness: 10.0, threshold: 0.2))
                startColorFromLine *= startFalloff * 1.5
                startColorFromLine[3] = 1.0
                endColorFromLine *= endFalloff * 1.5
                endColorFromLine[3] = 1.0




                brickLines[i].setBasicEndPointColors(startColor: startColorFromLine, endColor: endColorFromLine)
                brickLines[i].lineWidthStart = lineWidthBase + sigmoidDistance * lineWidthBase
                brickLines[i].lineWidthEnd = lineWidthBase + sigmoidDistance * lineWidthBase
                
                brickLines[i] = brickLines[i].applyMatrix(finalAdjustedTotalMat)
            }
            outputLines.append(contentsOf: brickLines)
        }
        
        
        return (outputLines, 0.0) // default replacement probability
    }
}
