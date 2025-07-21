//
//  Shader_Line.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 19/07/2025.
//

import simd

extension Shader_Line {
    static func initWithValues(
        p0_world: SIMD3<Float> = SIMD3<Float>(0,0,0),
        p1_world: SIMD3<Float> = SIMD3<Float>(0,0,0),
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
        
    ) -> Shader_Line {
        return Shader_Line(
            p0_world: p0_world,
            p1_world: p1_world,
            p0_screen: SIMD2<Float>(0,0),
            p1_screen: SIMD2<Float>(0,0),
            halfWidth0: halfWidth0,
            halfWidth1: halfWidth1,
            antiAlias: antialias,
            p0_depth: 0.0,
            p1_depth: 0.0,
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
            p0_inv_w: 0.0,
            p1_inv_w: 0.0,
            p0_depth_over_w: 0.0,
            p1_depth_over_w: 0.0
        )
    }
}
