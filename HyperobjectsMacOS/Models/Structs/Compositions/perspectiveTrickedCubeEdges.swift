//
//  perspectiveTrickedCubeEdges.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 24/01/2026.
//

func perspectiveTrickCubeEdges(
    cubeSize: Float,
    cameraPosition: SIMD3<Float>,
    amplitude: Float,
    gradientDirection: SIMD3<Float>,
    frequency: Float
) -> [(SIMD3<Float>, SIMD3<Float>)] {
    let s = cubeSize / 2
    
    let vertices: [SIMD3<Float>] = [
        SIMD3<Float>(-s, -s, -s),
        SIMD3<Float>( s, -s, -s),
        SIMD3<Float>( s,  s, -s),
        SIMD3<Float>(-s,  s, -s),
        SIMD3<Float>(-s, -s,  s),
        SIMD3<Float>( s, -s,  s),
        SIMD3<Float>( s,  s,  s),
        SIMD3<Float>(-s,  s,  s)
    ]
    
    let edgeIndices: [(Int, Int)] = [
        (0, 1), (1, 2), (2, 3), (3, 0),  // back face
        (4, 5), (5, 6), (6, 7), (7, 4),  // front face
        (0, 4), (1, 5), (2, 6), (3, 7)   // connecting edges
    ]
    
    let gradDir = normalize(gradientDirection)
    
    let displacedVertices = vertices.map { v -> SIMD3<Float> in
        let ray = v - cameraPosition
        let phase = frequency * dot(v, gradDir)
        let t = 1.0 + amplitude * sin(phase)
        return cameraPosition + t * ray
    }
    
    return edgeIndices.map { (displacedVertices[$0.0], displacedVertices[$0.1]) }
}
