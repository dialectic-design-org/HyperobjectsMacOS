//
//  Metropolis.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 07/01/2026.
//

struct Metropolis {
    var name: String
    var gridRows: Int
    var gridColumns: Int
    var blockSize: SIMD2<Double> // in meters
    var roadWidth: Double = 0.1 // in meters
    var outputScale: Double = 1.0 // scale factor for output representation
    var buildings: [Building] = []
    var cacheLines: [Line] = []
    var carPaths: [[SIMD3<Float>]] = [[]]


    init(name: String, gridRows: Int, gridColumns: Int, blockSize: SIMD2<Double>) {
        self.name = name
        self.gridRows = gridRows
        self.gridColumns = gridColumns
        self.blockSize = blockSize
        self.buildings = generateBuildings()
        initializeCarPaths(numberOfCars: 50, pathLength: 50)
        self.cacheLines = buildings.flatMap { $0.toLines() }
    }

    func gridSize() -> SIMD2<Double> {
        return SIMD2<Double>(Double(gridColumns) * blockSize.x, Double(gridRows) * blockSize.y)
    }

    func blockOutlineWithRoadInsets() -> [SIMD2<Double>] {
        let halfRoadWidth = roadWidth / 2.0
        return [
            SIMD2<Double>(halfRoadWidth, halfRoadWidth),
            SIMD2<Double>(blockSize.x - halfRoadWidth, halfRoadWidth),
            SIMD2<Double>(blockSize.x - halfRoadWidth, blockSize.y - halfRoadWidth),
            SIMD2<Double>(halfRoadWidth, blockSize.y - halfRoadWidth)
        ]
    }

    func centerOfCity() -> SIMD2<Double> {
        return gridSize() / 2.0
    }

    func generateBuildings() -> [Building] {
        var buildings: [Building] = []
        let floorHeight = 0.3
        
        for row in 0..<gridRows {
            for col in 0..<gridColumns {
                let blockOrigin = SIMD2<Double>(Double(col) * blockSize.x, Double(row) * blockSize.y)
                let center = blockOrigin + blockSize / 2.0
                
                // One building per block, slightly smaller than block
                let size = blockSize - SIMD2<Double>(roadWidth * 2.5, roadWidth * 2.5)
                
                // Height generation
                var height: Double
                if Float.random(in: 0...1) < 0.1 { // 10% high-rise
                    height = Double.random(in: 2.0...4.5)
                } else if Float.random(in: 0...1) < 0.05 { // 10% high-rise
                    height = Double.random(in: 4.0...10.5)
                } else {
                    height = Double.random(in: floorHeight...1.5)
                }
                
                // Clamp height to floor multiples
                let floors = max(1, (height / floorHeight).rounded())
                height = floors * floorHeight
                
                let usage = ["residential", "commercial", "industrial"].randomElement()!
                
                var building = Building(position: center, size: size, height: height, usageType: usage)
                building.floorHeight = floorHeight
                
                building.initializeWindows(density: Float.random(in: 0.2...0.5), randomizationFactor: Float.random(in: 0.1...0.4))
                buildings.append(building)
            }
        }
        return buildings
    }

    // Function to initialize car paths, which are arrays of 3D points, tracing random routes through the city
    mutating func initializeCarPaths(numberOfCars: Int, pathLength: Int) {
        carPaths = []
        let roadY: Float = 0.5 // Slightly above ground
        
        // Ensure path length is even to to guarantee we can return to start (parity of grid)
        // If odd, we can never close the loop perfectly on a taxicab grid
        let adjustedPathLength = pathLength % 2 == 0 ? pathLength : pathLength + 1

        for _ in 0..<numberOfCars {
            var path: [SIMD3<Float>] = []
            
            // Random start position within the grid (inclusive of edges)
            let startCol = Int.random(in: 0...gridColumns)
            let startRow = Int.random(in: 0...gridRows)
            
            var currentCol = startCol
            var currentRow = startRow
            
            var prevDir = SIMD2<Int>(0, 0)
            
            // Add start point
            path.append(SIMD3<Float>(Float(Double(currentCol) * blockSize.x), roadY, Float(Double(currentRow) * blockSize.y)))
            
            for step in 1...adjustedPathLength {
                let remainingSteps = adjustedPathLength - step
                
                // Potential moves: Up, Down, Left, Right
                let directions = [SIMD2<Int>(0, 1), SIMD2<Int>(0, -1), SIMD2<Int>(1, 0), SIMD2<Int>(-1, 0)]
                
                // Filter for valid moves that allow returning to start
                let validDirections = directions.filter { dir in
                    let nextCol = currentCol + dir.x
                    let nextRow = currentRow + dir.y
                    
                    // 1. Boundary check
                    if nextCol < 0 || nextCol > gridColumns || nextRow < 0 || nextRow > gridRows { return false }
                    
                    // 2. Reachability check: Can we get back to start in the remaining steps?
                    let distToStart = abs(nextCol - startCol) + abs(nextRow - startRow)
                    return distToStart <= remainingSteps
                }
                
                if validDirections.isEmpty { break } // Should happen only if boxed in, unlikely
                
                // Strategy: Prefer not to reverse immediately for better flow, but prioritize validity
                let nonReverseCandidates = validDirections.filter { $0 != SIMD2<Int>(-prevDir.x, -prevDir.y) }
                
                let chosenDir: SIMD2<Int>
                if let dir = nonReverseCandidates.randomElement() {
                    chosenDir = dir
                } else {
                    // Must reverse to stay on track (dead end or forced return)
                    chosenDir = validDirections.randomElement()!
                }
                
                currentCol += chosenDir.x
                currentRow += chosenDir.y
                prevDir = chosenDir
                
                path.append(SIMD3<Float>(Float(Double(currentCol) * blockSize.x), roadY, Float(Double(currentRow) * blockSize.y)))
            }
            
            // Only add if it's a non-trivial loop or path
            if path.count > 1 {
                carPaths.append(path)
            }
        }
    }

    func carPathsToLines() -> [[Line]] {
        var allCarLines: [[Line]] = []
        for path in carPaths {
            var carLines: [Line] = []
            for i in 0..<(path.count - 1) {
                let line = Line(startPoint: path[i], endPoint: path[i + 1])
                carLines.append(line)
            }
            allCarLines.append(carLines)
        }
        return allCarLines
    }
}

struct Building {
    var position: SIMD2<Double>
    var size: SIMD2<Double>
    var height: Double
    var usageType: String // e.g., residential, commercial, industrial
    var floorHeight: Double = 3.0 // in meters
    var windowToWallRatio: Double = 0.4 // percentage of wall area that is windows
    var roofType: String = "flat" // e.g., flat, gabled, hipped
    var windowWidth: Double = 1.5 // in meters
    var windowHeight: Double = 1.5 // in meters
    var windows: [RectangleCustom] = []

    init(position: SIMD2<Double>, size: SIMD2<Double>, height: Double, usageType: String) {
        self.position = position
        self.size = size
        self.height = height
        self.usageType = usageType
    }

    mutating func initializeWindows(density: Float, randomizationFactor: Float) {
        windows = []
        let floors = Int(height / floorHeight)
        let winW = Float(windowWidth)
        let winH = Float(windowHeight)
        
        let fSizeX = Float(size.x)
        let fSizeZ = Float(size.y)
        let fPos = SIMD3<Float>(Float(position.x), 0, Float(position.y))
        
        // Ensure count is non-negative to prevent fatal error: Range requires lowerBound <= upperBound
        let colsZ = max(0, Int((fSizeX / winW) * density))
        let stepX_Z = colsZ > 0 ? fSizeX / Float(colsZ) : 0
        
        // Ensure count is non-negative to prevent fatal error: Range requires lowerBound <= upperBound
        let colsX = max(0, Int((fSizeZ / winW) * density))
        let stepZ_X = colsX > 0 ? fSizeZ / Float(colsX) : 0

        for r in 0..<floors {
            let y = Float(r) * Float(floorHeight) + (Float(floorHeight) - winH) / 2.0
            
            // Z+ Face (Front)
            for c in 0..<colsZ {
                if shouldPlaceWindow(col: c, row: r, factor: randomizationFactor) {
                    let xOffset = -fSizeX/2 + (Float(c) + 0.5) * stepX_Z
                    let pos = fPos + SIMD3<Float>(xOffset, y, fSizeZ/2)
                    windows.append(RectangleCustom(position: pos, size: SIMD2<Float>(winW, winH), orientation: SIMD3<Float>(0, 0, 0)))
                }
            }
            
            // Z- Face (Back)
            for c in 0..<colsZ {
                if shouldPlaceWindow(col: c, row: r, factor: randomizationFactor) {
                    let xOffset = -fSizeX/2 + (Float(c) + 0.5) * stepX_Z
                    let pos = fPos + SIMD3<Float>(xOffset, y, -fSizeZ/2)
                    windows.append(RectangleCustom(position: pos, size: SIMD2<Float>(winW, winH), orientation: SIMD3<Float>(0, Float.pi, 0)))
                }
            }
            
            // X+ Face (Right)
            for c in 0..<colsX {
                if shouldPlaceWindow(col: c, row: r, factor: randomizationFactor) {
                    let zOffset = -fSizeZ/2 + (Float(c) + 0.5) * stepZ_X
                    let pos = fPos + SIMD3<Float>(fSizeX/2, y, zOffset)
                    windows.append(RectangleCustom(position: pos, size: SIMD2<Float>(winW, winH), orientation: SIMD3<Float>(0, Float.pi/2, 0)))
                }
            }
            
            // X- Face (Left)
            for c in 0..<colsX {
                if shouldPlaceWindow(col: c, row: r, factor: randomizationFactor) {
                    let zOffset = -fSizeZ/2 + (Float(c) + 0.5) * stepZ_X
                    let pos = fPos + SIMD3<Float>(-fSizeX/2, y, zOffset)
                    windows.append(RectangleCustom(position: pos, size: SIMD2<Float>(winW, winH), orientation: SIMD3<Float>(0, -Float.pi/2, 0)))
                }
            }
        }
    }
    
    func shouldPlaceWindow(col: Int, row: Int, factor: Float) -> Bool {
        let pattern: Float = 1.0
        let noise = Float.random(in: 0...1)
        let probability = pattern * (1.0 - factor) + noise * factor
        return probability > 0.5
    }

    func volume() -> Double {
        return size.x * size.y * height
    }

    func toCube() -> Cube {
        let boxCenter = SIMD3<Float>(Float(position.x), Float(height / 2.0), Float(position.y))
        let boxScale = SIMD3<Float>(Float(size.x), Float(height), Float(size.y))
        return Cube(center: boxCenter, size: 1.0, axisScale: boxScale)
    }

    // Return all windows and cube outline as flat array of Line objects
    func toLines() -> [Line] {
        var lines: [Line] = []
        
        // Building outline (cube)
        let cube = toCube()
        let cubeVertices = cube.vertices()
        
        let cubeEdgesIndices = [
            (0,1), (1,2), (2,3), (3,0), // Bottom face
            (4,5), (5,6), (6,7), (7,4), // Top face
            (0,4), (1,5), (2,6), (3,7)  // Vertical edges
        ]
        
        for (startIdx, endIdx) in cubeEdgesIndices {
            let startPoint = cubeVertices[startIdx]
            let endPoint = cubeVertices[endIdx]
            lines.append(Line(startPoint: startPoint, endPoint: endPoint))
        }
        
        // Windows
        for window in windows {
            let windowLines = window.toLines()
            lines.append(contentsOf: windowLines)
        }
        
        return lines
    }
}
