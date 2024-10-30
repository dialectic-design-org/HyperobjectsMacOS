//
//  conversions.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 15/10/2024.
//

import Foundation
import simd


func toCGPoint(inVec: SIMD3<Float>, direction: String) -> CGPoint {
    if direction == "z" {
        return CGPoint(x: CGFloat(inVec.x), y: CGFloat(inVec.y))
    } else if direction == "x" {
        return CGPoint(x: CGFloat(inVec.z), y: CGFloat(inVec.y))
    } else if direction == "y" {
        return CGPoint(x: CGFloat(inVec.x), y: CGFloat(inVec.z))
    }
    return CGPoint(x: CGFloat(inVec.x), y: CGFloat(inVec.y))
}


