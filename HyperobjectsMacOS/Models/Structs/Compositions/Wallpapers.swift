//
//  Wallpapers.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 17/01/2026.
//

import simd
import CoreGraphics

struct Brick {
    var center: SIMD2<Float>
    var halfSize: SIMD2<Float>
    var rotation: Float
}

struct HerringboneLattice {
    let shortSide: Float
    let basisA: SIMD2<Float>
    let basisB: SIMD2<Float>
    
    init(shortSide: Float) {
        self.shortSide = shortSide
        let twoS = 2.0 as Float * shortSide
        self.basisA = SIMD2<Float>(twoS, twoS)
        self.basisB = SIMD2<Float>(-twoS, twoS)
    }
    
    func motifBricks(origin: SIMD2<Float>) -> [Brick] {
        let halfWidth = shortSide
        let halfHeight = shortSide / 2
        let halfSize = SIMD2<Float>(halfWidth, halfHeight)
        
        let horizontalBrick = Brick(
            center: origin - SIMD2<Float>(shortSide * 0.5, -shortSide * 0.5),
            halfSize: halfSize,
            rotation: 0.0
        )
        
        let horizontalBrickTwo = Brick(
            center: origin - SIMD2<Float>(shortSide * 0.5, -shortSide * 0.5) + SIMD2<Float>(shortSide, -shortSide),
            halfSize: halfSize,
            rotation: 0.0
        )
        
        let offset = SIMD2<Float>(shortSide, shortSide)
        let verticalCenter = origin + offset
        let verticalBrick = Brick(
            center: verticalCenter,
            halfSize: halfSize,
            rotation: .pi / 2
        )
        
        let verticalBrickTwo = Brick(
            center: verticalCenter + SIMD2<Float>(-shortSide, shortSide),
            halfSize: halfSize,
            rotation: .pi / 2
        )
        return [horizontalBrick, horizontalBrickTwo, verticalBrick, verticalBrickTwo]
    }
    
    func generateBricks(in bounds: CGRect, maxCells: Int = 100) -> [Brick] {
        let minX = Float(bounds.minX)
        let maxX = Float(bounds.maxX)
        let minY = Float(bounds.minY)
        let maxY = Float(bounds.maxY)
        
        let lengthA = simd_length(basisA)
        let lengthB = simd_length(basisB)
        
        let dx = maxX - minX
        let dy = maxY - minY
        let diag = sqrt(dx * dx + dy * dy)
        
        let minStep = max(1e-6 as Float, min(lengthA, lengthB))
        var radius = Int(ceil(diag / minStep)) + 2
        
        radius = min(radius, maxCells)
        
        var bricks: [Brick] = []
        
        bricks.reserveCapacity((2 * radius + 1) * (2 * radius + 1) * 2)
        
        for m in -radius...radius {
            for n in -radius...radius {
                // Compute origin = m * basisA + n * basisB.
                let origin = Float(m) * basisA + Float(n) * basisB

                // Quickly cull cells that are far outside the bounding box.
                // We approximate each cell as a disk with radius ~ lengthA + lengthB.
                let approxRadius = lengthA + lengthB
                if origin.x + approxRadius < minX { continue }
                if origin.x - approxRadius > maxX { continue }
                if origin.y + approxRadius < minY { continue }
                if origin.y - approxRadius > maxY { continue }

                // Get motif bricks for this cell.
                let cellBricks = motifBricks(origin: origin)

                // Optionally cull bricks more precisely:
                // we check their centers against bounds enlarged by one brick size.
                let maxExtent = 2.0 as Float * shortSide
                let minXExt = minX - maxExtent
                let maxXExt = maxX + maxExtent
                let minYExt = minY - maxExtent
                let maxYExt = maxY + maxExtent

                for brick in cellBricks {
                    let c = brick.center
                    if c.x < minXExt || c.x > maxXExt { continue }
                    if c.y < minYExt || c.y > maxYExt { continue }

                    bricks.append(brick)
                }
            }
        }

        return bricks
    }
}
