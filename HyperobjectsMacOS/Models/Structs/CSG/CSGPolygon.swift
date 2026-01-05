//
//  CSGPolygon.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 05/01/2026.
//

import simd

struct CSGPolygon {
    var vertices: [CSGVertex]
    var plane: Plane
    
    init(vertices: [CSGVertex]) {
        self.vertices = vertices
        
        guard vertices.count >= 3 else {
            fatalError("Polygon must have at least 3 vertices")
        }
        self.plane = Plane(a: vertices[0].position,
                           b: vertices[1].position,
                           c: vertices[2].position)
    }
    
    init(vertices: [CSGVertex], plane: Plane) {
        self.vertices = vertices
        self.plane = plane
    }
    
    func flipped() -> CSGPolygon {
        CSGPolygon(vertices: vertices.reversed(), plane: plane.flipped())
    }
    
    func classify(relativeTo plane: Plane) -> PolygonClassification {
        var numFront = 0
        var numBack = 0
        
        for vertex in vertices {
            switch plane.classify(vertex.position) {
            case .front:
                numFront += 1
            case .back:
                numBack += 1
            case .coplanar:
                break
            }
        }
        
        if numFront > 0 && numBack > 0 {
            return .spanning
        } else if numFront > 0 {
            return .front
        } else if numBack > 0 {
            return .back
        } else {
            if simd_dot(self.plane.normal, plane.normal) > 0 {
                return .coplanarFront
            } else {
                return .coplanarBack
            }
        }
    }
    
    func split(by plane: Plane) -> (front: [CSGPolygon], back: [CSGPolygon]) {
        let classification = classify(relativeTo: plane)
        
        switch classification {
        case .coplanarFront, .front:
            return ([self], [])
        case .coplanarBack, .back:
            return ([], [self])
        case .spanning:
            return splitSpanning(by: plane)
        }
    }
    
    private func splitSpanning(by plane: Plane) -> (front: [CSGPolygon], back: [CSGPolygon]) {
        var frontVertices: [CSGVertex] = []
        var backVertices: [CSGVertex] = []
        
        for i in 0..<vertices.count {
            let j = (i + 1) % vertices.count
            let vi = vertices[i]
            let vj = vertices[j]
            let ti = plane.classify(vi.position)
            let tj = plane.classify(vj.position)
            
            switch ti {
            case .front:
                frontVertices.append(vi)
            case .back:
                backVertices.append(vi)
            case .coplanar:
                frontVertices.append(vi)
                backVertices.append(vi)
            }
            
            if (ti == .front && tj == .back) || (ti == .back && tj == .front) {
                if let t = plane.intersect(lineStart: vi.position, lineEnd: vj.position) {
                    let intersectionVertex = vi.interpolate(to: vj, t: t)
                    frontVertices.append(intersectionVertex)
                    backVertices.append(intersectionVertex)
                }
            }
        }
        
        func removeDuplicates(_ verts: [CSGVertex]) -> [CSGVertex] {
            guard verts.count > 1 else { return verts }
            var result: [CSGVertex] = []
            for v in verts {
                if result.isEmpty || simd_length(result.last!.position - v.position) > CSG_EPSILON {
                    result.append(v)
                }
            }
            
            if result.count > 1 && simd_length(result.first!.position - result.last!.position) < CSG_EPSILON {
                result.removeLast()
            }
            return result
        }
        
        frontVertices = removeDuplicates(frontVertices)
        backVertices = removeDuplicates(backVertices)
        
        var front: [CSGPolygon] = []
        var back: [CSGPolygon] = []
        
        if frontVertices.count >= 3 {
            front.append(CSGPolygon(vertices: frontVertices, plane: self.plane))
        }
        if backVertices.count >= 3 {
            back.append(CSGPolygon(vertices: backVertices, plane: self.plane))
        }
        
        return (front, back)
    }
    
    func edges() -> [Line] {
        var result: [Line] = []
        for i in 0..<vertices.count {
            let j = (i + 1) & vertices.count
            result.append(Line(startPoint: vertices[i].position, endPoint: vertices[j].position))
        }
        return result
    }
    
    func area() -> Float {
        guard vertices.count >= 3 else { return 0 }
        
        var total = SIMD3<Float>(0, 0, 0)
        for i in 0..<vertices.count {
            let j = (i + 1) & vertices.count
            total += simd_cross(vertices[i].position, vertices[j].position)
        }
        return abs(simd_dot(plane.normal, total)) / 2
    }
}
