//
//  Cube.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 04/01/2026.
//

import simd

struct Cube {
    var center: SIMD3<Float>
    var size: Float
    var orientation: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    var axisScale: SIMD3<Float> = SIMD3<Float>(1, 1, 1)
    
    func vertices() -> [SIMD3<Float>] {
        let halfSize = size / 2
        let localVertices = [
            SIMD3<Float>(-halfSize, -halfSize, -halfSize) * axisScale,
            SIMD3<Float>( halfSize, -halfSize, -halfSize) * axisScale,
            SIMD3<Float>( halfSize,  halfSize, -halfSize) * axisScale,
            SIMD3<Float>(-halfSize,  halfSize, -halfSize) * axisScale,
            SIMD3<Float>(-halfSize, -halfSize,  halfSize) * axisScale,
            SIMD3<Float>( halfSize, -halfSize,  halfSize) * axisScale,
            SIMD3<Float>( halfSize,  halfSize,  halfSize) * axisScale,
            SIMD3<Float>(-halfSize,  halfSize,  halfSize) * axisScale
        ]
        
        let rotationMatrixX = matrix_rotation(angle: orientation.x, axis: SIMD3<Float>(1, 0, 0))
        let rotationMatrixY = matrix_rotation(angle: orientation.y, axis: SIMD3<Float>(0, 1, 0))
        let rotationMatrixZ = matrix_rotation(angle: orientation.z, axis: SIMD3<Float>(0, 0, 1))
        let rotationMatrix = rotationMatrixZ * rotationMatrixY * rotationMatrixX
        
        return localVertices.map { vertex in
            let rotated = rotationMatrix * SIMD4<Float>(vertex, 1)
            return SIMD3<Float>(rotated.x, rotated.y, rotated.z) + center
        }
    }

    func volume() -> Float {
        return pow(size, 3) * axisScale.x * axisScale.y * axisScale.z
    }

    func surfaceArea() -> Float {
        let w = size * axisScale.x
        let h = size * axisScale.y
        let d = size * axisScale.z
        return 2 * (w * h + h * d + d * w)
    }

    func contains(point: SIMD3<Float>) -> Bool {
        let halfSize = size / 2
        
        let translatedPoint = point - center
        
        let rotationMatrixX = matrix_rotation(angle: orientation.x, axis: SIMD3<Float>(1, 0, 0))
        let rotationMatrixY = matrix_rotation(angle: orientation.y, axis: SIMD3<Float>(0, 1, 0))
        let rotationMatrixZ = matrix_rotation(angle: orientation.z, axis: SIMD3<Float>(0, 0, 1))
        let rotationMatrix = rotationMatrixZ * rotationMatrixY * rotationMatrixX
        
        let inverseRotation = rotationMatrix.inverse
        
        let localPoint4 = inverseRotation * SIMD4<Float>(translatedPoint, 1)
        let localPoint = SIMD3<Float>(localPoint4.x, localPoint4.y, localPoint4.z)
        
        return abs(localPoint.x) <= halfSize * axisScale.x &&
               abs(localPoint.y) <= halfSize * axisScale.y &&
               abs(localPoint.z) <= halfSize * axisScale.z
    }

    func wallOutlines() -> [Line] {
        let v = vertices()
        return [
            // Bottom face
            Line(startPoint: v[0], endPoint: v[1]),
            Line(startPoint: v[1], endPoint: v[2]),
            Line(startPoint: v[2], endPoint: v[3]),
            Line(startPoint: v[3], endPoint: v[0]),
            // Top face
            Line(startPoint: v[4], endPoint: v[5]),
            Line(startPoint: v[5], endPoint: v[6]),
            Line(startPoint: v[6], endPoint: v[7]),
            Line(startPoint: v[7], endPoint: v[4]),
            // Vertical edges
            Line(startPoint: v[0], endPoint: v[4]),
            Line(startPoint: v[1], endPoint: v[5]),
            Line(startPoint: v[2], endPoint: v[6]),
            Line(startPoint: v[3], endPoint: v[7])
        ]
    }
    func boundingBox() -> (min: SIMD3<Float>, max: SIMD3<Float>) {
        let verts = vertices()
        var minV = verts[0]
        var maxV = verts[0]
        for v in verts {
            minV = simd_min(minV, v)
            maxV = simd_max(maxV, v)
        }
        return (minV, maxV)
    }
    
    /// Check if two bounding boxes overlap
    private static func boundingBoxesOverlap(
        _ a: (min: SIMD3<Float>, max: SIMD3<Float>),
        _ b: (min: SIMD3<Float>, max: SIMD3<Float>)
    ) -> Bool {
        // Check for separation along each axis
        if a.max.x < b.min.x - CSG_EPSILON || b.max.x < a.min.x - CSG_EPSILON { return false }
        if a.max.y < b.min.y - CSG_EPSILON || b.max.y < a.min.y - CSG_EPSILON { return false }
        if a.max.z < b.min.z - CSG_EPSILON || b.max.z < a.min.z - CSG_EPSILON { return false }
        return true
    }
    
    /// Apply a boolean operation with another cube
    /// - Parameters:
    ///   - other: The other cube to combine with
    ///   - operation: The boolean operation to apply
    /// - Returns: BooleanResult containing resulting geometry (possibly multiple solids)
    func applyBoolean(other: Cube, operation: BooleanOperation) -> BooleanResult {
        // Early exit: check bounding box overlap
        let bbA = self.boundingBox()
        let bbB = other.boundingBox()
        let overlaps = Cube.boundingBoxesOverlap(bbA, bbB)
        
        // Handle non-overlapping cases efficiently
        if !overlaps {
            switch operation {
            case .intersection:
                // No overlap = empty intersection
                return BooleanResult(fromCSGSolid: CSGSolid(polygons: []))
            case .union:
                // No overlap = two separate solids
                let solidA = CSGSolid.fromCube(self)
                let solidB = CSGSolid.fromCube(other)
                let polyA = Polyhedron(fromPolygons: solidA.polygons)
                let polyB = Polyhedron(fromPolygons: solidB.polygons)
                return BooleanResult(solids: [polyA, polyB])
            case .difference:
                // No overlap = A unchanged
                let solidA = CSGSolid.fromCube(self)
                return BooleanResult(fromCSGSolid: solidA)
            case .symmetricDifference:
                // No overlap = both solids
                let solidA = CSGSolid.fromCube(self)
                let solidB = CSGSolid.fromCube(other)
                let polyA = Polyhedron(fromPolygons: solidA.polygons)
                let polyB = Polyhedron(fromPolygons: solidB.polygons)
                return BooleanResult(solids: [polyA, polyB])
            }
        }
        
        // Standard CSG operation for overlapping cubes
        let solidA = CSGSolid.fromCube(self)
        let solidB = CSGSolid.fromCube(other)
        
        let resultCSG: CSGSolid
        
        switch operation {
        case .union:
            resultCSG = solidA.union(solidB)
        case .intersection:
            resultCSG = solidA.intersection(solidB)
        case .difference:
            resultCSG = solidA.subtract(solidB)
        case .symmetricDifference:
            resultCSG = solidA.symmetricDifference(solidB)
        }
        
        return BooleanResult(fromCSGSolid: resultCSG)
    }
    
    /// Convenience method for intersection
    func intersect(with other: Cube) -> BooleanResult {
        applyBoolean(other: other, operation: .intersection)
    }
    
    /// Convenience method for union
    func union(with other: Cube) -> BooleanResult {
        applyBoolean(other: other, operation: .union)
    }
    
    /// Convenience method for difference (self - other)
    func subtract(_ other: Cube) -> BooleanResult {
        applyBoolean(other: other, operation: .difference)
    }
    
    /// Convenience method for symmetric difference (XOR)
    func symmetricDifference(with other: Cube) -> BooleanResult {
        applyBoolean(other: other, operation: .symmetricDifference)
    }
}
