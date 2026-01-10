//
//  ArcParameters.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 10/01/2026.
//

struct ArcParameters {
    let arcLength: Float
    let orientation: Float
    
    init(arcLength: Float, orientation: Float) {
        self.arcLength = arcLength
        self.orientation = orientation
    }
}

func createArcChain(
    from pairs: [ArcParameters],
    origin: SIMD3<Float>,
    radius: Float,
    initialTheta: Float,
    initialPhi: Float,
    initialDirection: Float
) -> [Arc3D] {
    guard !pairs.isEmpty else { return [] }
    
    var arcs: [Arc3D] = []
    var currentTheta = initialTheta
    var currentPhi = initialPhi
    var currentDirection = initialDirection
    
    for pair in pairs {
        let adjustedDirection = currentDirection + pair.orientation
        
        let arc = Arc3D(
            origin: origin,
            radius: radius,
            startTheta: currentTheta,
            startPhi: currentPhi,
            direction: adjustedDirection,
            arcLength: pair.arcLength
        )
        
        arcs.append(arc)
        
        currentTheta = arc.endTheta
        currentPhi = arc.endPhi
        currentDirection = arc.endDirection
    }
    
    return arcs
}

func createArcChain(
    from pairs: [(arcLength: Float, orientation: Float)],
    origin: SIMD3<Float>,
    radius: Float,
    initialTheta: Float,
    initialPhi: Float,
    initialDirection: Float
) -> [Arc3D] {
    let parameters = pairs.map { ArcParameters(arcLength: $0.arcLength, orientation: $0.orientation) }
    return createArcChain(
        from: parameters,
        origin: origin,
        radius: radius,
        initialTheta: initialTheta,
        initialPhi: initialPhi,
        initialDirection: initialDirection
    )
}
