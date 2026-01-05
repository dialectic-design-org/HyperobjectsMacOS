//
//  BooleanResult.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 05/01/2026.
//


/// Result of a boolean operation, potentially containing multiple disconnected solids
struct BooleanResult {
    var solids: [Polyhedron]
    
    /// Direct initializer with pre-computed solids
    init(solids: [Polyhedron]) {
        self.solids = solids.filter { !$0.isEmpty }
    }
    
    /// Create from CSG result
    init(fromCSGSolid csg: CSGSolid) {
        // First create a single polyhedron from all polygons
        let combined = Polyhedron(fromPolygons: csg.polygons)
        
        // Then separate into connected components
        self.solids = BooleanResult.separateComponents(combined)
    }
    
    /// Separate a polyhedron into connected components
    private static func separateComponents(_ polyhedron: Polyhedron) -> [Polyhedron] {
        guard !polyhedron.faces.isEmpty else {
            return []
        }
        
        // Build adjacency: vertex -> faces containing it
        var vertexToFaces: [[Int]] = Array(repeating: [], count: polyhedron.vertices.count)
        for (faceIndex, face) in polyhedron.faces.enumerated() {
            for vertexIndex in face {
                vertexToFaces[vertexIndex].append(faceIndex)
            }
        }
        
        // Find connected components using flood fill on faces
        var visited = Array(repeating: false, count: polyhedron.faces.count)
        var components: [[Int]] = []
        
        for startFace in 0..<polyhedron.faces.count {
            if visited[startFace] { continue }
            
            var component: [Int] = []
            var queue = [startFace]
            visited[startFace] = true
            
            while !queue.isEmpty {
                let current = queue.removeFirst()
                component.append(current)
                
                // Find adjacent faces (share at least one vertex)
                for vertexIndex in polyhedron.faces[current] {
                    for adjacentFace in vertexToFaces[vertexIndex] {
                        if !visited[adjacentFace] {
                            visited[adjacentFace] = true
                            queue.append(adjacentFace)
                        }
                    }
                }
            }
            
            components.append(component)
        }
        
        // Build separate polyhedra for each component
        var result: [Polyhedron] = []
        
        for component in components {
            // Collect faces and remap vertices
            var usedVertices = Set<Int>()
            for faceIndex in component {
                for vertexIndex in polyhedron.faces[faceIndex] {
                    usedVertices.insert(vertexIndex)
                }
            }
            
            // Create vertex remapping
            let sortedVertices = usedVertices.sorted()
            var vertexRemap: [Int: Int] = [:]
            for (newIndex, oldIndex) in sortedVertices.enumerated() {
                vertexRemap[oldIndex] = newIndex
            }
            
            // Build new polyhedron
            let newVertices = sortedVertices.map { polyhedron.vertices[$0] }
            let newFaces = component.map { faceIndex in
                polyhedron.faces[faceIndex].map { vertexRemap[$0]! }
            }
            
            let componentPolyhedron = Polyhedron(vertices: newVertices, faces: newFaces)
            if !componentPolyhedron.isEmpty {
                result.append(componentPolyhedron)
            }
        }
        
        return result
    }
    
    /// Check if result is empty (no geometry)
    var isEmpty: Bool {
        solids.isEmpty || solids.allSatisfy { $0.isEmpty }
    }
    
    /// Check if result is a single connected solid
    var isSingleSolid: Bool {
        solids.count == 1
    }
    
    /// Get all edge lines from all solids
    func allEdgeLines() -> [Line] {
        solids.flatMap { $0.edgeLines() }
    }
    
    /// Get total volume of all solids
    func totalVolume() -> Float {
        solids.reduce(0) { $0 + $1.volume() }
    }
    
    /// Get total surface area of all solids
    func totalSurfaceArea() -> Float {
        solids.reduce(0) { $0 + $1.surfaceArea() }
    }
    
    /// Get number of disconnected pieces
    var pieceCount: Int {
        solids.count
    }
}
