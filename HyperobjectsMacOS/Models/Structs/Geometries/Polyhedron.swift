//
//  Polyhedron.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 05/01/2026.
//

struct Polyhedron {
    var vertices: [SIMD3<Float>]
    var faces: [[Int]]
    
    init(fromPolygons polygons: [CSGPolygon]) {
        var uniqueVertices: [SIMD3<Float>] = []
        var faces: [[Int]] = []
        
        // Helper to find or add vertex
        func findOrAddVertex(_ position: SIMD3<Float>) -> Int {
            // Linear search for matching vertex (ensures correctness over hash collisions)
            for (index, existing) in uniqueVertices.enumerated() {
                if simd_length(existing - position) < CSG_EPSILON {
                    return index
                }
            }
            // Not found - add new vertex
            let newIndex = uniqueVertices.count
            uniqueVertices.append(position)
            return newIndex
        }
        
        for polygon in polygons {
            // Skip degenerate polygons
            guard polygon.vertices.count >= 3 else { continue }
            
            var faceIndices: [Int] = []
            var lastIndex: Int = -1
            
            for vertex in polygon.vertices {
                let index = findOrAddVertex(vertex.position)
                // Skip duplicate consecutive vertices
                if index != lastIndex {
                    faceIndices.append(index)
                    lastIndex = index
                }
            }
            
            // Also check if first and last are the same
            if faceIndices.count > 1 && faceIndices.first == faceIndices.last {
                faceIndices.removeLast()
            }
            
            // Only add valid polygons (at least 3 unique vertices)
            if faceIndices.count >= 3 {
                faces.append(faceIndices)
            }
        }
        
        self.vertices = uniqueVertices
        self.faces = faces
    }
    
    // Get all unique edges as Lines
    func edgeLines() -> [Line] {
        var edgeSet = Set<EdgeKey>()
        var result: [Line] = []
        
        for face in faces {
            for i in 0..<face.count {
                let j = (i + 1) % face.count
                let i1 = face[i]
                let i2 = face[j]
                
                let key = EdgeKey(min(i1, i2), max(i1, i2))
                if !edgeSet.contains(key) {
                    edgeSet.insert(key)
                    result.append(Line(startPoint: vertices[i1], endPoint: vertices[i2]))
                }
            }
        }
        
        return result
    }
    
    /// Compute volume using divergence theorem
    func volume() -> Float {
        var total: Float = 0
        
        for face in faces {
            guard face.count >= 3 else { continue }
            
            // Triangulate the face
            let v0 = vertices[face[0]]
            for i in 1..<(face.count - 1) {
                let v1 = vertices[face[i]]
                let v2 = vertices[face[i + 1]]
                
                // Signed volume of tetrahedron with origin
                total += simd_dot(v0, simd_cross(v1, v2)) / 6.0
            }
        }
        
        return abs(total)
    }
    
    /// Compute surface area
    func surfaceArea() -> Float {
        var total: Float = 0
        
        for face in faces {
            guard face.count >= 3 else { continue }
            
            // Triangulate the face
            let v0 = vertices[face[0]]
            for i in 1..<(face.count - 1) {
                let v1 = vertices[face[i]]
                let v2 = vertices[face[i + 1]]
                
                // Area of triangle
                let cross = simd_cross(v1 - v0, v2 - v0)
                total += simd_length(cross) / 2.0
            }
        }
        
        return total
    }
    
    /// Check if the polyhedron is convex
    func isConvex() -> Bool {
        // A polyhedron is convex if all vertices are on or behind each face plane
        for face in faces {
            guard face.count >= 3 else { continue }
            
            let plane = Plane(a: vertices[face[0]],
                            b: vertices[face[1]],
                            c: vertices[face[2]])
            
            for vertex in vertices {
                if plane.signedDistance(to: vertex) > CSG_EPSILON {
                    return false
                }
            }
        }
        return true
    }
    
    /// Check if polyhedron is empty (no faces or degenerate)
    var isEmpty: Bool {
        faces.isEmpty || vertices.count < 4
    }
    
    /// Get the centroid of the polyhedron
    func centroid() -> SIMD3<Float> {
        guard !vertices.isEmpty else { return .zero }
        var sum = SIMD3<Float>(0, 0, 0)
        for v in vertices {
            sum += v
        }
        return sum / Float(vertices.count)
    }
    
    /// Get axis-aligned bounding box
    func boundingBox() -> (min: SIMD3<Float>, max: SIMD3<Float>) {
        guard let first = vertices.first else {
            return (.zero, .zero)
        }
        
        var minV = first
        var maxV = first
        
        for v in vertices {
            minV = simd_min(minV, v)
            maxV = simd_max(maxV, v)
        }
        
        return (minV, maxV)
    }
}

extension Polyhedron {
    init(vertices: [SIMD3<Float>], faces: [[Int]]) {
        self.vertices = vertices
        self.faces = faces
    }
}
