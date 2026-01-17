//
//  RubixCube.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 14/01/2026.
//

import simd
import Foundation

// MARK: - Enums

enum CubeFace: Int, CaseIterable {
    case right = 0   // +X
    case left = 1    // -X
    case up = 2      // +Y
    case down = 3    // -Y
    case front = 4   // +Z
    case back = 5    // -Z
    
    var axis: SIMD3<Float> {
        switch self {
        case .right: return SIMD3(1, 0, 0)
        case .left: return SIMD3(-1, 0, 0)
        case .up: return SIMD3(0, 1, 0)
        case .down: return SIMD3(0, -1, 0)
        case .front: return SIMD3(0, 0, 1)
        case .back: return SIMD3(0, 0, -1)
        }
    }
    
    var opposite: CubeFace {
        switch self {
        case .right: return .left
        case .left: return .right
        case .up: return .down
        case .down: return .up
        case .front: return .back
        case .back: return .front
        }
    }
}

enum CubeColor: Int, CaseIterable {
    case white = 0
    case yellow = 1
    case red = 2
    case orange = 3
    case blue = 4
    case green = 5
    case none = 6
    
    /// Standard color scheme: White up, Green front
    static func standard(for face: CubeFace) -> CubeColor {
        switch face {
        case .up: return .white
        case .down: return .yellow
        case .front: return .green
        case .back: return .blue
        case .right: return .red
        case .left: return .orange
        }
    }
}

enum CubeMove: String, CaseIterable {
    case R, RPrime, R2
    case L, LPrime, L2
    case U, UPrime, U2
    case D, DPrime, D2
    case F, FPrime, F2
    case B, BPrime, B2
    
    var face: CubeFace {
        switch self {
        case .R, .RPrime, .R2: return .right
        case .L, .LPrime, .L2: return .left
        case .U, .UPrime, .U2: return .up
        case .D, .DPrime, .D2: return .down
        case .F, .FPrime, .F2: return .front
        case .B, .BPrime, .B2: return .back
        }
    }
    
    /// Rotation angle in radians (positive = clockwise when looking at the face)
    var angle: Float {
        switch self {
        case .R, .L, .U, .D, .F, .B:
            return -.pi / 2
        case .RPrime, .LPrime, .UPrime, .DPrime, .FPrime, .BPrime:
            return .pi / 2
        case .R2, .L2, .U2, .D2, .F2, .B2:
            return .pi
        }
    }
    
    /// The axis of rotation (always positive direction, angle determines direction)
    var rotationAxis: SIMD3<Float> {
        face.axis
    }
    
    var inverse: CubeMove {
        switch self {
        case .R: return .RPrime
        case .RPrime: return .R
        case .R2: return .R2
        case .L: return .LPrime
        case .LPrime: return .L
        case .L2: return .L2
        case .U: return .UPrime
        case .UPrime: return .U
        case .U2: return .U2
        case .D: return .DPrime
        case .DPrime: return .D
        case .D2: return .D2
        case .F: return .FPrime
        case .FPrime: return .F
        case .F2: return .F2
        case .B: return .BPrime
        case .BPrime: return .B
        case .B2: return .B2
        }
    }
    
    var notation: String {
        switch self {
        case .R: return "R"
        case .RPrime: return "R'"
        case .R2: return "R2"
        case .L: return "L"
        case .LPrime: return "L'"
        case .L2: return "L2"
        case .U: return "U"
        case .UPrime: return "U'"
        case .U2: return "U2"
        case .D: return "D"
        case .DPrime: return "D'"
        case .D2: return "D2"
        case .F: return "F"
        case .FPrime: return "F'"
        case .F2: return "F2"
        case .B: return "B"
        case .BPrime: return "B'"
        case .B2: return "B2"
        }
    }
}

// MARK: - Cubelet

struct RubiksCubelet: Identifiable {
    let id: Int
    
    /// Logical position in the cube grid: each component is -1, 0, or 1
    var logicalPosition: SIMD3<Int>
    
    /// Orientation as a quaternion (accumulated from moves)
    var orientation: simd_quatf
    
    /// Face colors in the cubelet's local coordinate system
    /// Key is the local face direction, value is the color visible on that face
    var faceColors: [CubeFace: CubeColor]
    
    /// The home position this cubelet belongs to when solved
    let homePosition: SIMD3<Int>
    
    // MARK: Animation State
    
    /// Current interpolated rotation for animation (applied on top of orientation)
    var animatedRotation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
    
    /// Global rotation applied content-wide (e.g. from momentum)
    var globalRotation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
    
    /// Whether this cubelet is currently being animated (part of the rotating face)
    var isAnimating: Bool = false
    
    // MARK: Computed Properties
    
    /// World-space position including animation
    var worldPosition: SIMD3<Float> {
        let basePos = SIMD3<Float>(logicalPosition)
        // First Apply animation rotation (local move), then global rotation (momentum)
        
        let animatedPos = animatedRotation.act(basePos)
        return globalRotation.act(animatedPos)
    }
    
    /// World-space orientation including animation
    var worldOrientation: simd_quatf {
        // Global * Animated * Base
        return globalRotation * animatedRotation * orientation
    }
    
    /// The type of cubelet based on how many colored faces it has
    var cubeletType: CubeletType {
        let coloredFaces = faceColors.values.filter { $0 != .none }.count
        switch coloredFaces {
        case 3: return .corner
        case 2: return .edge
        case 1: return .center
        default: return .core
        }
    }
    
    enum CubeletType {
        case corner  // 8 corners, 3 colors each
        case edge    // 12 edges, 2 colors each
        case center  // 6 centers, 1 color each
        case core    // 1 invisible core
    }
    
    /// Get the color visible on a world-space face direction
    func colorOnWorldFace(_ worldFace: CubeFace) -> CubeColor {
        // Transform world direction to local direction
        let worldDir = worldFace.axis
        let localDir = worldOrientation.inverse.act(worldDir)
        
        // Find closest local face
        var bestFace: CubeFace = .front
        var bestDot: Float = -2
        for face in CubeFace.allCases {
            let dot = simd_dot(localDir, face.axis)
            if dot > bestDot {
                bestDot = dot
                bestFace = face
            }
        }
        
        return faceColors[bestFace] ?? .none
    }
    
    // MARK: Initialization
    
    init(id: Int, position: SIMD3<Int>) {
        self.id = id
        self.logicalPosition = position
        self.homePosition = position
        self.orientation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        
        // Assign colors based on position
        var colors: [CubeFace: CubeColor] = [:]
        if position.x == 1 { colors[.right] = CubeColor.standard(for: .right) }
        if position.x == -1 { colors[.left] = CubeColor.standard(for: .left) }
        if position.y == 1 { colors[.up] = CubeColor.standard(for: .up) }
        if position.y == -1 { colors[.down] = CubeColor.standard(for: .down) }
        if position.z == 1 { colors[.front] = CubeColor.standard(for: .front) }
        if position.z == -1 { colors[.back] = CubeColor.standard(for: .back) }
        
        // Fill remaining faces with none
        for face in CubeFace.allCases {
            if colors[face] == nil {
                colors[face] = .none
            }
        }
        
        self.faceColors = colors
    }
    
    // MARK: Mutation
    
    /// Apply a discrete rotation (after animation completes)
    mutating func applyRotation(axis: SIMD3<Float>, angle: Float) {
        let rotation = simd_quatf(angle: angle, axis: simd_normalize(axis))
        
        // Update orientation
        orientation = rotation * orientation
        
        // Update logical position
        let newPos = rotation.act(SIMD3<Float>(logicalPosition))
        logicalPosition = SIMD3<Int>(
            Int(round(newPos.x)),
            Int(round(newPos.y)),
            Int(round(newPos.z))
        )
    }
    
    /// Check if this cubelet is on a given face layer
    func isOnFace(_ face: CubeFace) -> Bool {
        switch face {
        case .right: return logicalPosition.x == 1
        case .left: return logicalPosition.x == -1
        case .up: return logicalPosition.y == 1
        case .down: return logicalPosition.y == -1
        case .front: return logicalPosition.z == 1
        case .back: return logicalPosition.z == -1
        }
    }
}

// MARK: - Main Rubik's Cube

struct RubiksCube {
    
    // MARK: State
    
    /// Current state of all 26 cubelets (or 27 including invisible core)
    var cubelets: [RubiksCubelet]
    
    /// The initial scrambled state (stored for reference/reset)
    private(set) var initialState: [RubiksCubelet]
    
    /// Sequence of moves to solve from initial state
    var solution: [CubeMove]
    
    // MARK: Animation Parameters
    
    /// Steepness of the sigmoid easing curve (higher = sharper transition)
    /// Typical values: 5-15
    var easingSteepness: Float = 10.0
    
    /// Ratio of hold time to total time per move (0 = all animation, 1 = all hold)
    /// A value of 0.2 means 20% hold, 80% animation per move slot
    var holdRatio: Float = 0.1
    
    // Padding logic: factor of 1 (where 1 is the main animation content length)
    // If StartPadding=0.2 and EndPadding=0.2, and Moves=1.0 length, Real Total = 1.4
    var animationStartPadding: Float = 0.0
    var animationEndPadding: Float = 0.0
    
    // Physics / Momentum
    var momentumFactor: Float = 0.2 // Max rotation angle in radians kick per move
    var momentumDecay: Float = 3.0 // Decay rate (higher = stops faster)
    var clockwiseMomentumFactor: Float = 2.0 // Factor for clockwise moves (vs counter-clockwise)
    
    /// Current animation time (0 = initial state, 1 = fully solved, although padding extends this range)
    /// This property tracks input time
    private(set) var currentTime: Float = 0.0
    
    /// Current move index being animated
    private(set) var currentMoveIndex: Int = 0
    
    /// Progress within current move (0-1)
    private(set) var currentMoveProgress: Float = 0.0
    
    // MARK: Initialization
    
    /// Create a solved cube
    init() {
        var cubelets: [RubiksCubelet] = []
        var id = 0
        
        for x in -1...1 {
            for y in -1...1 {
                for z in -1...1 {
                    // Skip the invisible core (optional - can include it)
                    if x == 0 && y == 0 && z == 0 { continue }
                    
                    cubelets.append(RubiksCubelet(id: id, position: SIMD3(x, y, z)))
                    id += 1
                }
            }
        }
        
        self.cubelets = cubelets
        self.initialState = cubelets
        self.solution = []
    }
    
    /// Create a cube with a specific scramble
    init(scramble: [CubeMove]) {
        self.init()
        apply(moves: scramble)
        self.initialState = cubelets
        self.solution = scramble.reversed().map { $0.inverse }
    }
    
    // MARK: Move Application
    
    /// Apply a single move instantly (no animation)
    mutating func apply(move: CubeMove) {
        let face = move.face
        let angle = move.angle
        let axis = move.rotationAxis
        
        for i in cubelets.indices {
            if cubelets[i].isOnFace(face) {
                cubelets[i].applyRotation(axis: axis, angle: angle)
            }
        }
    }
    
    /// Apply multiple moves instantly
    mutating func apply(moves: [CubeMove]) {
        for move in moves {
            apply(move: move)
        }
    }
    
    /// Reset to initial state
    mutating func reset() {
        cubelets = initialState
        currentTime = 0
        updateAnimation(time: 0)
    }
    
    // MARK: Animation
    
    /// Update the cube's animated state based on time parameter
    /// - Parameter time: Progress 0..1 relative to the container timeline.
    /// This function handles time-remapping based on padding.
    mutating func updateAnimation(time: Float) {
        let inputTime = max(0, min(1, time))
        self.currentTime = inputTime
        
        guard !solution.isEmpty else {
            clearAnimationState()
            return
        }
        
        let moveCount = Float(solution.count)
        
        // Time Mapping Logic
        // Total Duration Units = startPad + 1.0 (moves) + endPad
        // Input `time` maps 0->1 across this whole range.
        // We need to extract `movesTime` (0->1) for the logic below.
        
        let totalUnits = animationStartPadding + 1.0 + animationEndPadding
        let currentUnitTime = inputTime * totalUnits
        
        // movesTime is 0 when currentUnitTime == startPadding
        // movesTime is 1 when currentUnitTime == startPadding + 1.0
        let movesTimeRaw = currentUnitTime - animationStartPadding
        let clampedMovesTime = max(0, min(1, movesTimeRaw))
        
        // Reset to initial state first
        cubelets = initialState
        
        let timePerMove = 1.0 / moveCount
        let exactMoveIndex = clampedMovesTime * moveCount
        currentMoveIndex = min(Int(exactMoveIndex), solution.count - 1)
        
        // Apply all completed moves
        for i in 0..<currentMoveIndex {
            apply(move: solution[i])
        }
        
        // Calculate progress within current move
        let moveStartTime = Float(currentMoveIndex) * timePerMove
        let rawProgress = (clampedMovesTime - moveStartTime) / timePerMove
        
        // Apply hold ratio: first (holdRatio/2) is hold, then animate, then hold again
        let holdStart = holdRatio / 2
        let holdEnd = 1.0 - holdRatio / 2
        
        let animationProgress: Float
        if rawProgress <= holdStart {
            animationProgress = 0
        } else if rawProgress >= holdEnd {
            animationProgress = 1
        } else {
            // Map to 0-1 range for the animation portion
            animationProgress = (rawProgress - holdStart) / (holdEnd - holdStart)
        }
        
        // Apply easing
        let easedProgress = sigmoidEase(animationProgress)
        self.currentMoveProgress = easedProgress
        
        // If we haven't completed this move, animate the current move
        // Only if we are actually inside the moves timeframe
        if currentMoveIndex < solution.count && movesTimeRaw < 1.0 && movesTimeRaw >= 0.0 {
            animateCurrentMove(progress: easedProgress)
        } else {
            // Apply final move if we're at the end (and movesTime > 1.0 means we finished)
            if movesTimeRaw >= 1.0 && currentMoveIndex < solution.count {
               // Apply all remaining moves if any skipped?
               // The loop `for i in 0..<currentMoveIndex` handles up to N-1.
               // We need to apply the last one if we are done.
               // Actually logic: `min(..., solution.count - 1)` ensures index is valid.
               // If `clampedMovesTime` == 1.0, `exactMoveIndex` == count. `currentMoveIndex` == count-1.
               // Loop applies up to count-1. We need to apply the last one manually if we are fully done.
               if movesTimeRaw >= 1.0 {
                   apply(move: solution[currentMoveIndex])
               }
            }
            clearAnimationState()
        }
        
        // MARK: Global Momentum Calculation
        
        // We simulate the accumulated rotation from all moves that have started up to `movesTimeRaw`
        var totalGlobalRotation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        
        for i in 0..<solution.count {
            let move = solution[i]
            let mStartTime = Float(i) * timePerMove
            
            // Time since this move started (in move-sequence 0-1 time units)
            // But momentumDecay is usually in seconds-ish or move-units?
            // Let's use "move units" (where 1 move = 1/count time).
            // Actually, let's convert to "number of moves elapsed".
            
            // `movesTimeRaw` is 0..1.
            // Move starts at `mStartTime` (0..1).
            // Delta in "normalized time"
            let deltaNorm = movesTimeRaw - mStartTime
            
            if deltaNorm > 0 {
                // Convert to "Moves Elapsed" units for easier tuning
                // e.g. delay = 1.0 means 1 move later.
                let movesElapsed = deltaNorm * moveCount
                
                // Damped Sine Wave Impulse
                // Angle = Factor * exp(-decay * t) * sin(freq * t)
                // We use Sine to simulate the "kick" and "wobble back".
                
                let decay = momentumDecay
                let wobbleFreq: Float = 3.0 // Radians per move-time
                
                // Direction Logic
                // Clockwise move angles are negative (e.g. -.pi/2)
                let isClockwise = move.angle < 0
                let cwFactor = isClockwise ? clockwiseMomentumFactor : 1.0
                
                let amplitude = momentumFactor * cwFactor * exp(-decay * movesElapsed) * sin(wobbleFreq * movesElapsed)
                
                // Rotation Axis: The move's axis
                // Direction: If move is clockwise, does body react counter-clockwise?
                // Let's assume re-action torque -> opposite direction.
                // Move angle sign:
                let moveSign: Float = isClockwise ? 1.0 : -1.0
                
                let impulseRot = simd_quatf(angle: amplitude * moveSign, axis: simd_normalize(move.rotationAxis))
                
                // Accumulate quaternion
                totalGlobalRotation = totalGlobalRotation * impulseRot
            }
        }
        
        // Apply global rotation to all cubelets
        for i in cubelets.indices {
            cubelets[i].globalRotation = totalGlobalRotation
        }
    }
    
    /// Animate the cubelets for the current move
    private mutating func animateCurrentMove(progress: Float) {
        guard currentMoveIndex < solution.count else { return }
        
        let move = solution[currentMoveIndex]
        let face = move.face
        let fullAngle = move.angle
        let axis = move.rotationAxis
        
        let currentAngle = fullAngle * progress
        let rotation = simd_quatf(angle: currentAngle, axis: simd_normalize(axis))
        
        for i in cubelets.indices {
            if cubelets[i].isOnFace(face) {
                cubelets[i].isAnimating = true
                cubelets[i].animatedRotation = rotation
            } else {
                cubelets[i].isAnimating = false
                cubelets[i].animatedRotation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
            }
        }
    }
    
    private mutating func clearAnimationState() {
        for i in cubelets.indices {
            cubelets[i].isAnimating = false
            cubelets[i].animatedRotation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        }
    }
    
    // MARK: Easing Functions
    
    /// Sigmoid easing function for smooth acceleration/deceleration
    func sigmoidEase(_ t: Float) -> Float {
        // Using a scaled sigmoid: 1 / (1 + e^(-k*(t-0.5)))
        // Normalized to map [0,1] -> [0,1]
        let k = easingSteepness
        let sigmoid = { (x: Float) -> Float in
            1.0 / (1.0 + exp(-k * (x - 0.5)))
        }
        
        let start = sigmoid(0)
        let end = sigmoid(1)
        
        return (sigmoid(t) - start) / (end - start)
    }
    
    /// Alternative: smoothstep easing
    func smoothstepEase(_ t: Float) -> Float {
        let x = max(0, min(1, t))
        return x * x * (3 - 2 * x)
    }
    
    /// Alternative: customizable ease with steepness
    func customEase(_ t: Float, steepness: Float) -> Float {
        // Power-based easing that responds to steepness
        // steepness < 1: ease-out feel
        // steepness > 1: ease-in feel
        // Combined for ease-in-out
        if t < 0.5 {
            return 0.5 * pow(2 * t, steepness)
        } else {
            return 1 - 0.5 * pow(2 * (1 - t), steepness)
        }
    }
    
    // MARK: Solving
    
    /// Set a custom solution sequence
    mutating func setSolution(_ moves: [CubeMove]) {
        self.solution = moves
        self.currentTime = 0
        updateAnimation(time: 0)
    }
    
    /// Generate solution from a scramble (reverses the scramble)
    mutating func solveFromScramble(_ scramble: [CubeMove]) {
        self.solution = scramble.reversed().map { $0.inverse }
    }
    
    /// Scramble the cube randomly and generate solution
    mutating func scramble(moveCount: Int = 20) {
        let baseMoves: [CubeMove] = [.R, .RPrime, .L, .LPrime, .U, .UPrime, .D, .DPrime, .F, .FPrime, .B, .BPrime]
        
        var scrambleMoves: [CubeMove] = []
        var lastFace: CubeFace? = nil
        
        for _ in 0..<moveCount {
            var move: CubeMove
            repeat {
                move = baseMoves.randomElement()!
            } while move.face == lastFace  // Avoid redundant consecutive moves on same face
            
            scrambleMoves.append(move)
            lastFace = move.face
        }
        
        // Reset to solved, apply scramble, store as initial
        cubelets = createSolvedCubelets()
        apply(moves: scrambleMoves)
        initialState = cubelets
        
        // Solution is reverse of scramble
        solution = scrambleMoves.reversed().map { $0.inverse }
        currentTime = 0
    }
    
    private func createSolvedCubelets() -> [RubiksCubelet] {
        var result: [RubiksCubelet] = []
        var id = 0
        
        for x in -1...1 {
            for y in -1...1 {
                for z in -1...1 {
                    if x == 0 && y == 0 && z == 0 { continue }
                    result.append(RubiksCubelet(id: id, position: SIMD3(x, y, z)))
                    id += 1
                }
            }
        }
        return result
    }
    
    // MARK: State Queries
    
    /// Check if the cube is solved
    var isSolved: Bool {
        for cubelet in cubelets {
            // Check if cubelet is in home position
            if cubelet.logicalPosition != cubelet.homePosition {
                return false
            }
            // Check if orientation is identity (no rotation)
            let identityQuat = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
            if abs(simd_dot(cubelet.orientation, identityQuat)) < 0.99 {
                return false
            }
        }
        return true
    }
    
    /// Get cubelets by type
    func cubelets(ofType type: RubiksCubelet.CubeletType) -> [RubiksCubelet] {
        cubelets.filter { $0.cubeletType == type }
    }
    
    /// Get cubelets on a specific face
    func cubelets(onFace face: CubeFace) -> [RubiksCubelet] {
        cubelets.filter { $0.isOnFace(face) }
    }
    
    /// Get the cubelet at a specific position
    func cubelet(at position: SIMD3<Int>) -> RubiksCubelet? {
        cubelets.first { $0.logicalPosition == position }
    }
    
    /// Get the face colors as a flat array for a specific face (3x3 grid)
    func faceColors(_ face: CubeFace) -> [[CubeColor]] {
        var result: [[CubeColor]] = Array(repeating: Array(repeating: .none, count: 3), count: 3)
        
        let faceCubelets = cubelets(onFace: face)
        
        for cubelet in faceCubelets {
            // Map 3D position to 2D grid position on the face
            let (row, col) = gridPosition(for: cubelet.logicalPosition, on: face)
            result[row][col] = cubelet.colorOnWorldFace(face)
        }
        
        return result
    }
    
    private func gridPosition(for position: SIMD3<Int>, on face: CubeFace) -> (row: Int, col: Int) {
        // Map the 3D position to a 2D grid based on which face we're looking at
        let x = position.x + 1  // 0, 1, 2
        let y = position.y + 1
        let z = position.z + 1
        
        switch face {
        case .front:  return (2 - y, x)      // Looking at +Z face
        case .back:   return (2 - y, 2 - x)  // Looking at -Z face
        case .right:  return (2 - y, 2 - z)  // Looking at +X face
        case .left:   return (2 - y, z)      // Looking at -X face
        case .up:     return (2 - z, x)      // Looking at +Y face
        case .down:   return (z, x)          // Looking at -Y face
        }
    }
    
    // MARK: Animation State Summary
    
    /// Current animation status
    var animationStatus: AnimationStatus {
        AnimationStatus(
            time: currentTime,
            moveIndex: currentMoveIndex,
            totalMoves: solution.count,
            moveProgress: currentMoveProgress,
            currentMove: currentMoveIndex < solution.count ? solution[currentMoveIndex] : nil,
            isComplete: currentTime >= 1.0 || solution.isEmpty
        )
    }
    
    struct AnimationStatus {
        let time: Float
        let moveIndex: Int
        let totalMoves: Int
        let moveProgress: Float
        let currentMove: CubeMove?
        let isComplete: Bool
        
        var description: String {
            if isComplete {
                return "Complete"
            } else if let move = currentMove {
                return "Move \(moveIndex + 1)/\(totalMoves): \(move.notation) (\(Int(moveProgress * 100))%)"
            } else {
                return "Ready"
            }
        }
    }
}

// MARK: - Convenience Extensions

extension SIMD3 where Scalar == Int {
    init(_ float3: SIMD3<Float>) {
        self.init(Int(float3.x), Int(float3.y), Int(float3.z))
    }
}

extension SIMD3 where Scalar == Float {
    init(_ int3: SIMD3<Int>) {
        self.init(Float(int3.x), Float(int3.y), Float(int3.z))
    }
}

// MARK: - Transformation Matrix Helper

extension RubiksCubelet {
    /// Get the 4x4 transformation matrix for rendering
    /// - Parameter cubeSize: The total size of the cube (cubelets will be positioned accordingly)
    /// - Parameter cubeletSpacing: Gap between cubelets (typically 0.05-0.1)
    func transformMatrix(cubeSize: Float = 3.0, cubeletSpacing: Float = 0.05) -> simd_float4x4 {
        let scale = (cubeSize / 3.0) * (1.0 - cubeletSpacing)
        let offset = cubeSize / 3.0
        
        // Position
        let position = worldPosition * offset
        
        // Rotation
        let rotation = worldOrientation
        
        // Build matrix: Scale -> Rotate -> Translate
        let scaleMatrix = simd_float4x4(diagonal: SIMD4(scale, scale, scale, 1))
        let rotationMatrix = simd_float4x4(rotation)
        let translationMatrix = simd_float4x4(columns: (
            SIMD4(1, 0, 0, 0),
            SIMD4(0, 1, 0, 0),
            SIMD4(0, 0, 1, 0),
            SIMD4(position.x, position.y, position.z, 1)
        ))
        
        return translationMatrix * rotationMatrix * scaleMatrix
    }
}
