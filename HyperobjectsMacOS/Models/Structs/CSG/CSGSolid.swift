//
//  CSGSolid.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 05/01/2026.
//

struct CSGSolid {
    var polygons: [CSGPolygon]
    
    init(polygons: [CSGPolygon]) {
        self.polygons = polygons
    }
    
    static func fromCube(_ cube: Cube) -> CSGSolid {
        let verts = cube.vertices()
        
        // Define the 6 faces with CCW winding (viewed from outside)
        // Vertex indices for each face
        let faceIndices: [[Int]] = [
            [0, 3, 2, 1],  // Back face (negative Z)
            [4, 5, 6, 7],  // Front face (positive Z)
            [0, 1, 5, 4],  // Bottom face (negative Y)
            [2, 3, 7, 6],  // Top face (positive Y)
            [0, 4, 7, 3],  // Left face (negative X)
            [1, 2, 6, 5]   // Right face (positive X)
        ]
        
        var polygons: [CSGPolygon] = []
        for indices in faceIndices {
            let vertices = indices.map { CSGVertex(verts[$0]) }
            polygons.append(CSGPolygon(vertices: vertices))
        }
        
        return CSGSolid(polygons: polygons)
    }
    
    /// Union: A ∪ B - combines both solids
    func union(_ other: CSGSolid) -> CSGSolid {
        let a = BSPNode(polygons: self.polygons)
        let b = BSPNode(polygons: other.polygons)
        
        a.clipTo(b)
        b.clipTo(a)
        b.invert()
        b.clipTo(a)
        b.invert()
        a.build(b.allPolygons())
        
        return CSGSolid(polygons: a.allPolygons())
    }
    
    /// Intersection: A ∩ B - keeps only overlapping region
    func intersection(_ other: CSGSolid) -> CSGSolid {
        let a = BSPNode(polygons: self.polygons)
        let b = BSPNode(polygons: other.polygons)
        
        a.invert()
        b.clipTo(a)
        b.invert()
        a.clipTo(b)
        b.clipTo(a)
        a.build(b.allPolygons())
        a.invert()
        
        return CSGSolid(polygons: a.allPolygons())
    }
    
    /// Difference: A - B - subtracts B from A
    func subtract(_ other: CSGSolid) -> CSGSolid {
        let a = BSPNode(polygons: self.polygons)
        let b = BSPNode(polygons: other.polygons)
        
        a.invert()
        a.clipTo(b)
        b.clipTo(a)
        b.invert()
        b.clipTo(a)
        b.invert()
        a.build(b.allPolygons())
        a.invert()
        
        return CSGSolid(polygons: a.allPolygons())
    }
    
    /// Symmetric Difference (XOR): (A - B) ∪ (B - A)
    func symmetricDifference(_ other: CSGSolid) -> CSGSolid {
        let aMinusB = self.subtract(other)
        let bMinusA = other.subtract(self)
        return aMinusB.union(bMinusA)
    }
}
