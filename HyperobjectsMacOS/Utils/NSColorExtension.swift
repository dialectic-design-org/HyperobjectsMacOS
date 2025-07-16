//
//  NSColorExtension.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 16/07/2025.
//

import AppKit

extension NSColor {
    convenience init(hex: String) {
        var hexFormatted = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if hexFormatted.hasPrefix("#") {
            hexFormatted.removeFirst()
        }
        
        assert(hexFormatted.count == 6, "Hex color must be 6 characters in RRGGBB format.")

        var rgbValue: UInt64 = 0
        Scanner(string: hexFormatted).scanHexInt64(&rgbValue)

        let red   = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
        let blue  = CGFloat(rgbValue & 0x0000FF) / 255.0

        self.init(srgbRed: red, green: green, blue: blue, alpha: 1.0)
    }
}


import SwiftUI

extension Color {
    init(hex: String) {
        self.init(NSColor(hex: hex))
    }
}


extension Color {
    func toSIMD4() -> SIMD4<Float> {
        let nsColor = NSColor(self)
            .usingColorSpace(.sRGB) ?? NSColor.black

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        nsColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return SIMD4<Float>(
            Float(red),
            Float(green),
            Float(blue),
            Float(alpha)
        )
    }
}
