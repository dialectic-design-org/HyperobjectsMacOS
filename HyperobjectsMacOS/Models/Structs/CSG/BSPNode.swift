//
//  BSPNode.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 05/01/2026.
//

import simd

class BSPNode {
    var plane: Plane?
    var front: BSPNode?
    var back: BSPNode?
    var polygons: [CSGPolygon]
    
    init() {
        self.polygons = []
    }
    
    init(polygons: [CSGPolygon]) {
        self.polygons = polygons
        if !polygons.isEmpty {
            build(polygons)
        }
    }
    
    func clone() -> BSPNode {
        let node = BSPNode()
        node.plane = plane
        node.front = front?.clone()
        node.back = back?.clone()
        node.polygons = polygons
        return node
    }
    
    func invert() {
        for i in 0..<polygons.count {
            polygons[i] = polygons[i].flipped()
        }
        plane = plane?.flipped()
        front?.invert()
        back?.invert()
        swap(&front, &back)
    }
    
    func allPolygons() -> [CSGPolygon] {
        var result = polygons
        if let front = front {
            result.append(contentsOf: front.allPolygons())
        }
        if let back = back {
            result.append(contentsOf: back.allPolygons())
        }
        return result
    }
    
    func clipTo(_ bsp: BSPNode) {
        polygons = bsp.clipPolygons(polygons)
        front?.clipTo(bsp)
        back?.clipTo(bsp)
    }
    
    func clipPolygons(_ inputPolygons: [CSGPolygon]) -> [CSGPolygon] {
        guard let plane = plane else {
            return inputPolygons
        }
        
        var frontPolygons: [CSGPolygon] = []
        var backPolygons: [CSGPolygon] = []
        
        for polygon in inputPolygons {
            let (front, back) = splitPolygon(polygon, by: plane)
            frontPolygons.append(contentsOf: front)
            backPolygons.append(contentsOf: back)
        }
        
        if let front = front {
            frontPolygons = front.clipPolygons(frontPolygons)
        }
        
        if let back = back {
            backPolygons = back.clipPolygons(backPolygons)
        } else {
            backPolygons = []
        }
        
        return frontPolygons + backPolygons
    }
    
    private func splitPolygon(_ polygon: CSGPolygon, by plane: Plane) -> (front: [CSGPolygon], back: [CSGPolygon]) {
        let classification = polygon.classify(relativeTo: plane)
        
        switch classification {
        case .coplanarFront:
            return ([polygon], [])
        case .coplanarBack:
            return ([], [polygon])
        case .front:
            return ([polygon], [])
        case .back:
            return ([], [polygon])
        case .spanning:
            return polygon.split(by: plane)
        }
    }
    
    func build(_ inputPolygons: [CSGPolygon]) {
        guard !inputPolygons.isEmpty else { return }
        
        if plane == nil {
            plane = inputPolygons[0].plane
        }
        
        guard let plane = plane else { return }
        
        var frontPolygons: [CSGPolygon] = []
        var backPolygons: [CSGPolygon] = []
        for polygon in inputPolygons {
            let classification = polygon.classify(relativeTo: plane)
            switch classification {
            case .coplanarFront, .coplanarBack:
                // Store coplanar polygons in this node
                polygons.append(polygon)
            case .front:
                frontPolygons.append(polygon)
            case .back:
                backPolygons.append(polygon)
            case .spanning:
                let (front, back) = polygon.split(by: plane)
                frontPolygons.append(contentsOf: front)
                backPolygons.append(contentsOf: back)
            }
        }
        if !frontPolygons.isEmpty {
            if front == nil {
                front = BSPNode()
            }
            front?.build(frontPolygons)
        }
        
        if !backPolygons.isEmpty {
            if back == nil {
                back = BSPNode()
            }
            back?.build(backPolygons)
        }
    }
}
