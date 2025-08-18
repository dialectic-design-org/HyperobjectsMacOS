//
//  Shader_Line.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 19/07/2025.
//

import simd


private func tupleFromArray<T>(_ array: [T]) -> (
    T, T, T, T, T, T, T, T,
    T, T, T, T, T, T, T, T,
    T, T, T, T, T, T, T, T,
    T, T, T, T, T, T, T, T
) {
    precondition(array.count == 32)
    return (
        array[0], array[1], array[2], array[3], array[4], array[5], array[6], array[7],
        array[8], array[9], array[10], array[11], array[12], array[13], array[14], array[15],
        array[16], array[17], array[18], array[19], array[20], array[21], array[22], array[23],
        array[24], array[25], array[26], array[27], array[28], array[29], array[30], array[31]
    )
}

extension Shader_PathSeg {
    static func initWithValues(
        p0_world: SIMD3<Float> = SIMD3<Float>(0,0,0),
        p1_world: SIMD3<Float> = SIMD3<Float>(0,0,0),
        degree: Int = 1,
        controlPoints: [SIMD3<Float>] = [],
        halfWidth0: Float = 1.0,
        halfWidth1: Float = 1.0,
        antialias: Float = 0.7,
        colorPremul0: SIMD4<Float> = SIMD4<Float>(1,1,1,1),
        colorPremul0OuterLeft: SIMD4<Float> = SIMD4<Float>(1,1,1,1),
        colorPremul0OuterRight: SIMD4<Float> = SIMD4<Float>(1,1,1,1),
        sigmoidSteepness0: Float = 0.5,
        sigmoidMidpoint0: Float = 0.5,
        
        colorPremul1: SIMD4<Float> = SIMD4<Float>(1,1,1,1),
        colorPremul1OuterLeft: SIMD4<Float> = SIMD4<Float>(1,1,1,1),
        colorPremul1OuterRight: SIMD4<Float> = SIMD4<Float>(1,1,1,1),
        sigmoidSteepness1: Float = 0.5,
        sigmoidMidpoint1: Float = 0.5
        
    ) -> Shader_PathSeg {
        
        var world_p0: SIMD4<Float> = SIMD4<Float>(p0_world, 1.0)
        var world_p1: SIMD4<Float> = SIMD4<Float>(p1_world, 1.0)
        var world_p2: SIMD4<Float> = SIMD4<Float>(repeating: 0.0)
        var world_p3: SIMD4<Float> = SIMD4<Float>(repeating: 0.0)
        
        if (degree == 2) {
            world_p2 = SIMD4<Float>(p1_world, 1.0)
            world_p1 = SIMD4<Float>(controlPoints[0], 1.0);
        } else if (degree == 3) {
            world_p3 = SIMD4<Float>(p1_world, 1.0)
            world_p1 = SIMD4<Float>(controlPoints[0], 1.0);
            world_p2 = SIMD4<Float>(controlPoints[1], 1.0);
        }
        
        let dashPatternPx = (
            Float(0.0),
            Float(0.0),
            Float(0.0),
            Float(0.0),
            Float(0.0),
            Float(0.0),
            Float(0.0),
            Float(0.0))
        
        let sLUTPlaceholder = tupleFromArray(Array(repeating: Float(0), count: Int(ARC_LUT_SAMPLES)))
        
        let posLUTPLaceholder = tupleFromArray(Array(repeating: SIMD2<Float>(0.0, 0.0), count: Int(ARC_LUT_SAMPLES)))
        
        let tanLUTPlaceholder = tupleFromArray(Array(repeating: SIMD2<Float>(0.0, 0.0), count: Int(ARC_LUT_SAMPLES)))
        
        return Shader_PathSeg(
            p_world: (
                world_p0,
                world_p1,
                world_p2,
                world_p3
            ),
            
            p_screen: (
                SIMD2<Float>(0.0, 0.0),
                SIMD2<Float>(0.0, 0.0),
                SIMD2<Float>(0.0, 0.0),
                SIMD2<Float>(0.0, 0.0)
            ),
            
            degree: Int16(degree),
            
            halfWidth0: halfWidth0,
            halfWidth1: halfWidth1,
            antiAlias: antialias,
            _pad0: 0.0,
            colorPremul0: colorPremul0,
            colorPremul0OuterLeft: colorPremul0OuterLeft,
            colorPremul0OuterRight: colorPremul0OuterRight,
            colorPremul1: colorPremul1,
            colorPremul1OuterLeft: colorPremul1OuterLeft,
            colorPremul1OuterRight: colorPremul1OuterRight,
            sigmoidSteepness0: sigmoidSteepness0,
            sigmoidMidpoint0: sigmoidMidpoint0,
            sigmoidSteepness1: sigmoidSteepness1,
            sigmoidMidpoint1: sigmoidMidpoint1,
            
            dashPatternPx: dashPatternPx,
            dashCount: 0,
            dashTotalPx: 0.0,
            dashPhasePx: 0.0,
            _padDash: 0,
            
            p_depth: (Float(0.0),Float(0.0),Float(0.0),Float(0.0)),
            p_inv_w: (Float(0.0),Float(0.0),Float(0.0),Float(0.0)),
            p_depth_over_w: (Float(0.0),Float(0.0),Float(0.0),Float(0.0)),
            
            sLUT: sLUTPlaceholder,
            segLengthPx: 0.0,
            
            posLUT: posLUTPLaceholder,
            tanLUT: tanLUTPlaceholder,
            
            lutCount: 0,
            bboxMinSS: SIMD2<Float>(0.0, 0.0),
            bboxMaxSS: SIMD2<Float>(0.0, 0.0)
            
        )
    }
}
