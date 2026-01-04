//
//  VoxelGrid.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 04/01/2026.
//

struct VoxelGrid {
    var dimensions: (Int, Int, Int)
    var voxelSize: Float
    
    init(dimensions: (Int, Int, Int), voxelSize: Float) {
        self.dimensions = dimensions
        self.voxelSize = voxelSize
    }

    func totalVoxels() -> Int {
        return dimensions.0 * dimensions.1 * dimensions.2
    }

    func volume() -> Float {
        let (dx, dy, dz) = dimensions
        return Float(dx * dy * dz) * pow(voxelSize, 3)
    }

    func voxelCenter(at index: (Int, Int, Int)) -> SIMD3<Float> {
        let (i, j, k) = index
        let x = (Float(i) + 0.5) * voxelSize
        let y = (Float(j) + 0.5) * voxelSize
        let z = (Float(k) + 0.5) * voxelSize
        return SIMD3<Float>(x, y, z)
    }

    func isValidIndex(_ index: (Int, Int, Int)) -> Bool {
        let (i, j, k) = index
        return i >= 0 && i < dimensions.0 &&
               j >= 0 && j < dimensions.1 &&
               k >= 0 && k < dimensions.2
    }

    func voxelsAlongAxis(axis: Int) -> Int {
        switch axis {
        case 0:
            return dimensions.0
        case 1:
            return dimensions.1
        case 2:
            return dimensions.2
        default:
            return 0
        }
    }

    func gridCenter() -> SIMD3<Float> {
        let centerX = (Float(dimensions.0) * voxelSize) / 2
        let centerY = (Float(dimensions.1) * voxelSize) / 2
        let centerZ = (Float(dimensions.2) * voxelSize) / 2
        return SIMD3<Float>(centerX, centerY, centerZ)
    }
     
    func voxels() -> [Voxel] {
        var voxels: [Voxel] = []
        for i in 0..<dimensions.0 {
            for j in 0..<dimensions.1 {
                for k in 0..<dimensions.2 {
                    let center = voxelCenter(at: (i, j, k))
                    let voxel = Voxel(center: center, size: voxelSize)
                    voxels.append(voxel)
                }
            }
        }
        return voxels
    }
}
