//
//  conversions.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 15/10/2024.
//

import Foundation
import SwiftUI
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

func floatFromInputs(_ inputs: [String: Any], name: String) -> Float {
    if let inputValue: Double = inputs[name] as? Double {
        return Float(inputValue)
    } else if let inputValue: Float = inputs[name] as? Float {
        return inputValue
    } else {
        return Float(0.0)
    }
}

func intFromInputs(_ inputs: [String: Any], name: String) -> Int {
    if let inputValue: Int = inputs[name] as? Int {
        return inputValue
    } else {
        return 0
    }
}

func colorFromInputs(_ inputs: [String: Any], name: String) -> Color {
    if let inputColor: Color = inputs[name] as? Color {
        return inputColor
    } else {
        return Color.red
    }
}

func stringFromInputs(_ inputs: [String: Any], name: String) -> String {
    if let inputValue: String = inputs[name] as? String {
        return inputValue
    } else {
        return ""
    }
}


func colorToVector(_ color: Color) -> vector_float3 {
    let nsColor = NSColor(color) // Convert SwiftUI.Color to NSColor

    // Convert to calibrated RGB color space
    guard let rgbColor = nsColor.usingColorSpace(.deviceRGB) else {
        return vector_float3(0, 0, 0) // Fallback
    }

    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0

    rgbColor.getRed(&red, green: &green, blue: &blue, alpha: nil)

    return vector_float3(Float(red), Float(green), Float(blue))
}



