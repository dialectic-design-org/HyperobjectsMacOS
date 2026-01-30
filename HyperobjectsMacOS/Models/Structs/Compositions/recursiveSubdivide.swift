//
//  recursiveSubdivide.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 27/01/2026.
//

func recursiveSubdivide(cube: Cube, input: SceneInput, depth: Int, maxDepth: Int = 10) -> [(Cube, Int)] {
    // Stop condition 1: Max depth
    if depth >= maxDepth { return [(cube, depth)] }
    
    // Stop condition 2: Min size
    // We check the smallest dimension of the cube
    let currentMinSize = cube.size * min(cube.axisScale.x, min(cube.axisScale.y, cube.axisScale.z))
    if currentMinSize < 0.03 { // Adjusted threshold to allow some depth
        return [(cube, depth)]
    }
    
    // Determine axis: X -> Y -> Z -> X ...
    let axisIndex = depth % 3
    var splitAxis = SIMD3<Int>(0, 0, 0)
    if axisIndex == 0 { splitAxis.x = 1 }
    else if axisIndex == 1 { splitAxis.y = 1 }
    else { splitAxis.z = 1 }
    
    // Subdivide
    // We use 0.5 for an even split, or we could vary it.
    // Given "iteratively along axes", a regular grid-like structure suggests constant split.
    // However, to make it interesting, we could alternate standard deviation or just use 0.5.
    // Let's use 0.5 to strictly follow "subdividing".
    let subCubes = cube.subdivide(division: 0.0001 + ensureValueIsFloat(input.getHistoryValue(millisecondsAgo: Double(depth * 450))), on: splitAxis)
    
    // Recurse
    return subCubes.flatMap { recursiveSubdivide(cube: $0, input: input, depth: depth + 1, maxDepth: maxDepth) }
}
