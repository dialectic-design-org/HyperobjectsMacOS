//
//  Shader_Line.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 19/07/2025.
//

import simd

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
        
        return Shader_PathSeg(
            p0_world: p0_world,
            p1_world: p1_world,
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
            
            degree: Int32(degree),
            
            halfWidth0: halfWidth0,
            halfWidth1: halfWidth1,
            antiAlias: antialias,
            // p0_depth: 0.0,
            // p1_depth: 0.0,
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
            
            p_depth: (Float(0.0),Float(0.0),Float(0.0),Float(0.0)),
            p_inv_w: (Float(0.0),Float(0.0),Float(0.0),Float(0.0)),
            p_depth_over_w: (Float(0.0),Float(0.0),Float(0.0),Float(0.0))
        )
    }
}
