//
//  projectedCubeLines.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 15/01/2026.
//

import simd

func projectedCubeLines(
    innerRotation: SIMD3<Float>,
    outerRotation: SIMD3<Float>,
    innerSize: Float,
    outerSize: Float
) -> [(SIMD3<Float>, SIMD3<Float>)] {
    let unitVertices: [SIMD3<Float>] = [
        SIMD3(-0.5, -0.5, -0.5),
        SIMD3( 0.5, -0.5, -0.5),
        SIMD3( 0.5,  0.5, -0.5),
        SIMD3(-0.5,  0.5, -0.5),
        SIMD3(-0.5, -0.5,  0.5),
        SIMD3( 0.5, -0.5,  0.5),
        SIMD3( 0.5,  0.5,  0.5),
        SIMD3(-0.5,  0.5,  0.5)
    ]
    
    let edges: [(Int, Int)] = [
        (0, 1), (1, 2), (2, 3), (3, 0),
        (4, 5), (5, 6), (6, 7), (7, 4),
        (0, 4), (1, 5), (2, 6), (3, 7)
    ]
    
    let faceDefinitions: [(normal: SIMD3<Float>, tangent1: SIMD3<Float>, tangent2: SIMD3<Float>)] = [
        (SIMD3( 1,  0,  0), SIMD3( 0,  0, -1), SIMD3( 0,  1,  0)),  // +X face
        (SIMD3(-1,  0,  0), SIMD3( 0,  0,  1), SIMD3( 0,  1,  0)),  // -X face
        (SIMD3( 0,  1,  0), SIMD3( 1,  0,  0), SIMD3( 0,  0,  1)),  // +Y face
        (SIMD3( 0, -1,  0), SIMD3( 1,  0,  0), SIMD3( 0,  0, -1)),  // -Y face
        (SIMD3( 0,  0,  1), SIMD3( 1,  0,  0), SIMD3( 0,  1,  0)),  // +Z face
        (SIMD3( 0,  0, -1), SIMD3(-1,  0,  0), SIMD3( 0,  1,  0))   // -Z face
    ]
    
    func rotationMatrix(from angles: SIMD3<Float>) -> simd_float3x3 {
        let cx = cos(angles.x), sx = sin(angles.x)
        let cy = cos(angles.y), sy = sin(angles.y)
        let cz = cos(angles.z), sz = sin(angles.z)
        
        let rx = simd_float3x3(rows: [
            SIMD3(1,  0,   0),
            SIMD3(0, cx, -sx),
            SIMD3(0, sx,  cx)
        ])
        
        let ry = simd_float3x3(rows: [
            SIMD3( cy, 0, sy),
            SIMD3(  0, 1,  0),
            SIMD3(-sy, 0, cy)
        ])
        
        let rz = simd_float3x3(rows: [
            SIMD3(cz, -sz, 0),
            SIMD3(sz,  cz, 0),
            SIMD3( 0,   0, 1)
        ])
        
        return rz * ry * rx
    }
    
    func clipLineToSquare(
        p0: SIMD2<Float>,
        p1: SIMD2<Float>,
        halfSize: Float
    ) -> (SIMD2<Float>, SIMD2<Float>)? {
        let delta = p1 - p0
        
        let p: [Float]  = [-delta.x, delta.x, -delta.y, delta.y]
        let q: [Float] = [
            p0.x - (-halfSize),
            halfSize - p0.x,
            p0.y - (-halfSize),
            halfSize - p0.y
        ]
        
        var tMin: Float = 0.0
        var tMax: Float = 1.0
        
        for i in 0..<4 {
            if p[i] == 0 {
                if q[i] < 0 {
                    return nil
                }
            } else {
                let t = q[i] / p[i]
                if p[i] < 0 {
                    tMin = max(tMin, t)
                } else {
                    tMax = min(tMax, t)
                }
            }
        }
        
        if tMin > tMax {
            return nil
        }
        
        let clippedP0 = p0 + tMin * delta
        let clippedP1 = p0 + tMax * delta
        
        return (clippedP0, clippedP1)
    }
    
    let innerMatrix = rotationMatrix(from: innerRotation)
    let outerMatrix = rotationMatrix(from: outerRotation)
    
    let innerVertices = unitVertices.map { innerMatrix * ($0 * innerSize) }
    
    let outerHalfSize = outerSize * 0.5
    
    var result: [(SIMD3<Float>, SIMD3<Float>)] = []
    
    for face in faceDefinitions {
        let normal = outerMatrix * face.normal
        let tangent1 = outerMatrix * face.tangent1
        let tangent2 = outerMatrix * face.tangent2
        let faceCenter = normal * outerHalfSize
        
        for (i0, i1) in edges {
            let p0 = innerVertices[i0]
            let p1 = innerVertices[i1]
            
            let t0 = simd_dot(faceCenter - p0, normal)
            let t1 = simd_dot(faceCenter - p1, normal)
            
            let projected0 = p0 + t0 * normal
            let projected1 = p1 + t1 * normal
            
            let local0 = projected0 - faceCenter
            let local1 = projected1 - faceCenter
            
            let p0_2d = SIMD2<Float>(
                simd_dot(local0, tangent1),
                simd_dot(local0, tangent2)
            )
            
            let p1_2d = SIMD2<Float>(
                simd_dot(local1, tangent1),
                simd_dot(local1, tangent2)
            )
            
            guard let (clipped0_2d, clipped1_2d) = clipLineToSquare(
                p0: p0_2d,
                p1: p1_2d,
                halfSize: outerHalfSize) else {
                continue
            }
            
            let clipped0_3d = faceCenter + clipped0_2d.x * tangent1 + clipped0_2d.y * tangent2
            let clipped1_3d = faceCenter + clipped1_2d.x * tangent1 + clipped1_2d.y * tangent2
            
            result.append((clipped0_3d, clipped1_3d))
        }
    }
    
    return result
}
