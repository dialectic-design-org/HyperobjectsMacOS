//
//  GameOfLife3D.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 09/01/2026.
//

struct CellularAutomata3D {
    enum RulePreset {
        /// 4555: Survives with 4-5 neighbors, born with 5. Creates coral-like growth.
        case coral
        /// 5766: Survives with 5-7, born with 6. Slower, more stable structures.
        case crystals
        /// 4-5/5: Same as coral, balanced growth and decay
        case balanced
        /// 6-8/6-7: Denser structures, slower evolution
        case dense
        /// 2-6/4-5: More chaotic, expansive growth
        case chaotic
        /// 5-6/5: Creates web-like structures
        case web
        /// Custom rule set
        case custom(survive: ClosedRange<Int>, birth: ClosedRange<Int>)
        
        var surviveRange: ClosedRange<Int> {
            switch self {
            case .coral, .balanced: return 4...5
            case .crystals: return 5...7
            case .dense: return 6...8
            case .chaotic: return 2...6
            case .web: return 5...6
            case .custom(let survive, _): return survive
            }
        }
        
        var birthRange: ClosedRange<Int> {
            switch self {
            case .coral, .balanced: return 5...5
            case .crystals: return 6...6
            case .dense: return 6...7
            case .chaotic: return 4...5
            case .web: return 5...5
            case .custom(_, let birth): return birth
            }
        }
    }
    
    struct Cell: Hashable {
        let x: Int
        let y: Int
        let z: Int
    }
    
    let width: Int
    let height: Int
    let depth: Int
    
    private var cells: [Bool]
    private var nextCells: [Bool]
    private var cellColors: [SIMD4<Float>] // RGBA colors for each cell index
    
    var surviveRange: ClosedRange<Int>
    var birthRange: ClosedRange<Int>
    var wrapsAtEdges: Bool
    
    private(set) var generation: Int = 0
    
    // Configurable Palette
    // Base palette: range of venom green colors (Dark Green -> Bright Green)
    var palette: [SIMD4<Float>] = [
        SIMD4<Float>(0.0, 0.0, 0.0, 1.0),  // Black
        SIMD4<Float>(0.0, 0.0, 0.0, 1.0),  // Black
        SIMD4<Float>(0.0, 0.0, 0.0, 1.0),  // Black
        SIMD4<Float>(0.0, 0.0, 0.0, 1.0),  // Black
        SIMD4<Float>(0.0, 0.0, 0.0, 1.0),  // Black
        SIMD4<Float>(0.0, 0.0, 0.0, 1.0),  // Black
        SIMD4<Float>(0.0, 0.0, 0.0, 1.0),  // Black
        SIMD4<Float>(0.0, 0.0, 0.0, 1.0),  // Black

        
        SIMD4<Float>(0.0, 0.2, 0.0, 1.0), // Dark venom
        SIMD4<Float>(0.1, 0.4, 0.1, 1.0),
        SIMD4<Float>(0.2, 0.6, 0.2, 1.0),
        SIMD4<Float>(0.3, 0.8, 0.3, 1.0),
        SIMD4<Float>(0.4, 1.0, 0.4, 1.0),  // Bright venom
        SIMD4<Float>(1.0, 0.0, 0.2, 1.0),  // Bright yellow
    ]
    
    var liveCellCount: Int {
        cells.reduce(0) { $0 + ($1 ? 1 : 0) }
    }
    
    init(width: Int, height: Int, depth: Int, preset: RulePreset = .coral, wrapsAtEdges: Bool = true) {
        self.width = width
        self.height = height
        self.depth = depth
        self.surviveRange = preset.surviveRange
        self.birthRange = preset.birthRange
        self.wrapsAtEdges = wrapsAtEdges
        
        let totalCells = width * height * depth
        self.cells = [Bool](repeating: false, count: totalCells)
        self.nextCells = [Bool](repeating: false, count: totalCells)
        self.cellColors = [SIMD4<Float>](repeating: SIMD4<Float>(0,0,0,0), count: totalCells)
    }
    
    init(width: Int, height: Int, depth: Int,
         surviveRange: ClosedRange<Int>,
         birthRange: ClosedRange<Int>,
         wrapsAtEdges: Bool = true) {
        self.width = width
        self.height = height
        self.depth = depth
        self.surviveRange = surviveRange
        self.birthRange = birthRange
        self.wrapsAtEdges = wrapsAtEdges
        
        let totalCells = width * height * depth
        self.cells = [Bool](repeating: false, count: totalCells)
        self.nextCells = [Bool](repeating: false, count: totalCells)
        self.cellColors = [SIMD4<Float>](repeating: SIMD4<Float>(0,0,0,0), count: totalCells)
    }

    func updatePreset(to preset: RulePreset) -> CellularAutomata3D {
        var updated = self
        updated.surviveRange = preset.surviveRange
        updated.birthRange = preset.birthRange
        return updated
    }
    
    @inline(__always)
    private func index(x: Int, y: Int, z: Int) -> Int {
        return z * (width * height) + y * width + x
    }
    
    @inline(__always)
    private func wrap(_ value: Int, max: Int) -> Int {
        if value < 0 { return value + max }
        if value >= max { return value - max }
        return value
    }
    
    @inline(__always)
    private func isInBounds(x: Int, y: Int, z: Int) -> Bool {
        return x >= 0 && x < width && y >= 0 && y < height && z >= 0 && z < depth
    }
    
    // Check if cell is alive on position
    func isAlive(x: Int, y: Int, z: Int) -> Bool {
        guard isInBounds(x: x, y: y, z: z) else { return false }
        return cells[index(x: x, y: y, z: z)]
    }
    
    // Check if cell is alive through cell struct
    func isAlive(_ cell: Cell) -> Bool {
        return isAlive(x: cell.x, y: cell.y, z: cell.z)
    }
    
    // Set cell on position
    mutating func setCell(x: Int, y: Int, z: Int, alive: Bool) {
        guard isInBounds(x: x, y: y, z: z) else { return }
        let idx = index(x: x, y: y, z: z)
        let wasAlive = cells[idx]
        cells[idx] = alive
        
        if alive && !wasAlive {
            // Just turned alive -> Assign random color from palette
            cellColors[idx] = palette.randomElement() ?? SIMD4<Float>(0,1,0,1)
        } else if !alive {
            cellColors[idx] = SIMD4<Float>(0,0,0,0)
        }
    }
    
    // Set cell through cell struct
    mutating func setCell(_ cell: Cell, alive: Bool) {
        setCell(x: cell.x, y: cell.y, z: cell.z, alive: alive)
    }
    
    mutating func toggleCell(x: Int, y: Int, z: Int) {
        guard isInBounds(x: x, y: y, z: z) else { return }
        let idx = index(x: x, y: y, z: z)
        let alive = !cells[idx]
        cells[idx] = alive
        
        if alive {
             cellColors[idx] = palette.randomElement() ?? SIMD4<Float>(0,1,0,1)
        } else {
             cellColors[idx] = SIMD4<Float>(0,0,0,0)
        }
    }
    
    private func countNeighbors(x: Int, y: Int, z: Int) -> Int {
        var count = 0
        
        for dz in -1...1 {
            for dy in -1...1 {
                for dx in -1...1 {
                    // Skip the center cell itself
                    if dx == 0 && dy == 0 && dz == 0 { continue }
                    
                    var nx = x + dx
                    var ny = y + dy
                    var nz = z + dz
                    
                    if wrapsAtEdges {
                        nx = wrap(nx, max: width)
                        ny = wrap(ny, max: height)
                        nz = wrap(nz, max: depth)
                    } else {
                        if !isInBounds(x: nx, y: ny, z: nz) { continue }
                    }
                    
                    if cells[index(x: nx, y: ny, z: nz)] {
                        count += 1
                    }
                }
            }
        }
        
        return count
    }
    
    mutating func clear() {
        let total = width * height * depth
        cells = [Bool](repeating: false, count: total)
        cellColors = [SIMD4<Float>](repeating: SIMD4<Float>(0,0,0,0), count: total)
        generation = 0
    }
    
    mutating func randomize(density: Double = 0.2) {
        let clampedDensity = max(0.0, min(1.0, density))
        for i in 0..<cells.count {
            let alive = Double.random(in: 0..<1) < clampedDensity
            cells[i] = alive
            if alive {
                cellColors[i] = palette.randomElement() ?? SIMD4<Float>(0,1,0,1)
            } else {
                cellColors[i] = SIMD4<Float>(0,0,0,0)
            }
        }
        generation = 0
    }
    
    mutating func randomlyTurnOn(density: Double = 0.2) {
        let clampedDensity = max(0.0, min(1.0, density))
        for i in 0..<cells.count {
            if Double.random(in: 0..<1) < clampedDensity {
                if !cells[i] {
                    cells[i] = true
                    cellColors[i] = palette.randomElement() ?? SIMD4<Float>(0,1,0,1)
                }
            }
        }
        generation = 0
    }
    
    mutating func populateSphere(center: Cell, radius: Double, density: Double = 0.4) {
        let radiusSquared = radius * radius
        let clampedDensity = max(0.0, min(1.0, density))
        
        let minX = max(0, Int(Double(center.x) - radius))
        let maxX = min(width - 1, Int(Double(center.x) + radius))
        let minY = max(0, Int(Double(center.y) - radius))
        let maxY = min(height - 1, Int(Double(center.y) + radius))
        let minZ = max(0, Int(Double(center.z) - radius))
        let maxZ = min(depth - 1, Int(Double(center.z) + radius))
        
        for z in minZ...maxZ {
            for y in minY...maxY {
                for x in minX...maxX {
                    let dx = Double(x - center.x)
                    let dy = Double(y - center.y)
                    let dz = Double(z - center.z)
                    let distSquared = dx*dx + dy*dy + dz*dz
                    
                    if distSquared <= radiusSquared {
                        if Double.random(in: 0..<1) < clampedDensity {
                            let idx = index(x: x, y: y, z: z)
                            if !cells[idx] {
                                cells[idx] = true
                                cellColors[idx] = palette.randomElement() ?? SIMD4<Float>(0,1,0,1)
                            }
                        }
                    }
                }
            }
        }
        generation = 0
    }
    
    mutating func populateCube(minCorner: Cell, maxCorner: Cell, density: Double = 0.4) {
        let clampedDensity = max(0.0, min(1.0, density))
        
        let x0 = max(0, min(minCorner.x, maxCorner.x))
        let x1 = min(width - 1, max(minCorner.x, maxCorner.x))
        let y0 = max(0, min(minCorner.y, maxCorner.y))
        let y1 = min(height - 1, max(minCorner.y, maxCorner.y))
        let z0 = max(0, min(minCorner.z, maxCorner.z))
        let z1 = min(depth - 1, max(minCorner.z, maxCorner.z))
        
        for z in z0...z1 {
            for y in y0...y1 {
                for x in x0...x1 {
                    if Double.random(in: 0..<1) < clampedDensity {
                        let idx = index(x: x, y: y, z: z)
                        if !cells[idx] {
                            cells[idx] = true
                            cellColors[idx] = palette.randomElement() ?? SIMD4<Float>(0,1,0,1)
                        }
                    }
                }
            }
        }
        generation = 0
    }
    
    mutating func populate(cells cellPositions: [Cell]) {
        for cell in cellPositions {
            setCell(cell, alive: true)
        }
    }
    
    
    mutating func populateCenteredSeed(radius: Int = 3, density: Double = 0.5) {
        let center = Cell(
            x: width / 2,
            y: height / 2,
            z: depth / 2
        )
        populateSphere(center: center, radius: Double(radius), density: density)
    }
    
    
    
    
    mutating func tick() {
        // Apply rules to compute next generation
        for z in 0..<depth {
            for y in 0..<height {
                for x in 0..<width {
                    let idx = index(x: x, y: y, z: z)
                    let neighbors = countNeighbors(x: x, y: y, z: z)
                    let currentlyAlive = cells[idx]
                    
                    let willBeAlive: Bool
                    if currentlyAlive {
                        // Survival rule: live cell stays alive if neighbor count is in survive range
                        willBeAlive = surviveRange.contains(neighbors)
                    } else {
                        // Birth rule: dead cell becomes alive if neighbor count is in birth range
                        willBeAlive = birthRange.contains(neighbors)
                    }
                    
                    nextCells[idx] = willBeAlive
                    
                    if willBeAlive {
                        if !currentlyAlive {
                            // Birth: Assign new color
                            cellColors[idx] = palette.randomElement() ?? SIMD4<Float>(0,1,0,1)
                        } 
                        // If already alive, keep existing color
                    } else {
                        // Dead
                        cellColors[idx] = SIMD4<Float>(0,0,0,0)
                    }
                }
            }
        }
        
        // Swap buffers
        swap(&cells, &nextCells)
        generation += 1
    }
    
    mutating func tick(generations: Int) {
        for _ in 0..<generations {
            tick()
        }
    }
    
    func getLiveCells() -> [Cell] {
        var result: [Cell] = []
        result.reserveCapacity(liveCellCount)
        
        for z in 0..<depth {
            for y in 0..<height {
                for x in 0..<width {
                    if cells[index(x: x, y: y, z: z)] {
                        result.append(Cell(x: x, y: y, z: z))
                    }
                }
            }
        }
        
        return result
    }

    
    func getLiveCellsNormalized() -> [(x: Float, y: Float, z: Float)] {
        let liveCells = getLiveCells()
        let w = Float(width - 1)
        let h = Float(height - 1)
        let d = Float(depth - 1)
        
        return liveCells.map { cell in
            (
                x: w > 0 ? Float(cell.x) / w : 0.5,
                y: h > 0 ? Float(cell.y) / h : 0.5,
                z: d > 0 ? Float(cell.z) / d : 0.5
            )
        }
    }
    
    func getLiveCellsCentered() -> [(x: Float, y: Float, z: Float)] {
        return getLiveCellsNormalized().map { pos in
            (x: pos.x - 0.5, y: pos.y - 0.5, z: pos.z - 0.5)
        }
    }
    
    // Get colors for only the live cells, maintaining the same order as getLiveCells()
    func getLiveCellColors() -> [SIMD4<Float>] {
        var result: [SIMD4<Float>] = []
        result.reserveCapacity(liveCellCount)
        
        for z in 0..<depth {
            for y in 0..<height {
                for x in 0..<width {
                    let idx = index(x: x, y: y, z: z)
                    if cells[idx] {
                        result.append(cellColors[idx])
                    }
                }
            }
        }
        return result
    }
    
    // Returns combined position and color data for live cells
    // Useful for single-pass iteration when rendering
    func getLiveCellsCenteredWithColors() -> [(position: (x: Float, y: Float, z: Float), color: SIMD4<Float>)] {
        var result: [(position: (x: Float, y: Float, z: Float), color: SIMD4<Float>)] = []
        result.reserveCapacity(liveCellCount)
        
        let w = Float(width - 1)
        let h = Float(height - 1)
        let d = Float(depth - 1)
        
        for z in 0..<depth {
            for y in 0..<height {
                for x in 0..<width {
                    let idx = index(x: x, y: y, z: z)
                    if cells[idx] {
                        let nx = w > 0 ? Float(x) / w : 0.5
                        let ny = h > 0 ? Float(y) / h : 0.5
                        let nz = d > 0 ? Float(z) / d : 0.5
                        
                        let pos = (x: nx - 0.5, y: ny - 0.5, z: nz - 0.5)
                        result.append((position: pos, color: cellColors[idx]))
                    }
                }
            }
        }
        return result
    }
}

extension CellularAutomata3D {
    /// Create a standard cubic world
    static func cube(size: Int, preset: RulePreset = .coral) -> CellularAutomata3D {
        return CellularAutomata3D(width: size, height: size, depth: size, preset: preset)
    }
}

extension CellularAutomata3D.Cell {
    /// Create cell at integer coordinates
    init(_ x: Int, _ y: Int, _ z: Int) {
        self.x = x
        self.y = y
        self.z = z
    }
}
