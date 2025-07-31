//
//  Color.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 31/07/2025.
//

import SwiftUI
import simd

enum ColorScaleMode {
    case rgb
    case hsl
    case lch
    case hcl
    case sinewave
    case spiral
    case hyperPulse
}


struct ColorStop {
    var color: SIMD3<Double> // interpreted as RGB in linear space
}

class ColorScale {
    private let stops: [ColorStop]
    private let mode: ColorScaleMode

    init(colors: [Color], mode: ColorScaleMode) {
        self.mode = mode
        self.stops = colors.map { color in
            let nsColor = NSColor(color)
            guard let sRGB = nsColor.usingColorSpace(.sRGB) else {
                return ColorStop(color: SIMD3(1.0, 0.0, 1.0)) // fallback: magenta
            }
            return ColorStop(color: SIMD3(Double(sRGB.redComponent),
                                          Double(sRGB.greenComponent),
                                          Double(sRGB.blueComponent)))
        }
    }

    func color(at time: Double, saturation: Double = 1.0, brightness: Double = 1.0) -> Color {
        let t = max(0.0, min(time, 1.0))
        
        let baseRGB: SIMD3<Double> = {
            switch mode {
            case .rgb:
                return interpolateRGB(t).toSIMD3Double()
            case .hsl:
                return interpolateHSL(t).toSIMD3Double()
            case .lch:
                return interpolateLCH(t).toSIMD3Double()
            case .hcl:
                return interpolateHCL(t).toSIMD3Double()
            case .sinewave:
                return sineWaveScale(t).toSIMD3Double()
            case .spiral:
                return spiralHue(t).toSIMD3Double()
            case .hyperPulse:
                return hyperPulse(t).toSIMD3Double()
            }
        }()
        
        let (h, s, l) = self.rgbToHSL(baseRGB)
        let adjustedRGB = self.hslToRGB(
            h,
            s * saturation,
            l * brightness
        )
        
        let clamped = SIMD3<Double>(
            x: min(max(adjustedRGB.x, 0.0), 1.0),
            y: min(max(adjustedRGB.y, 0.0), 1.0),
            z: min(max(adjustedRGB.z, 0.0), 1.0)
        )
        
        return Color(red: clamped.x, green: clamped.y, blue: clamped.z)
    }
    
    func hslToRGB(_ h: Double, _ s: Double, _ l: Double) -> SIMD3<Double> {
        func hueToRGB(_ p: Double, _ q: Double, _ t: Double) -> Double {
            var t = t
            if t < 0.0 { t += 1.0 }
            if t > 1.0 { t -= 1.0 }
            if t < 1.0 / 6.0 { return p + (q - p) * 6.0 * t }
            if t < 1.0 / 2.0 { return q }
            if t < 2.0 / 3.0 { return p + (q - p) * (2.0 / 3.0 - t) * 6.0 }
            return p
        }

        if s == 0.0 {
            // achromatic gray
            return SIMD3(repeating: l)
        }

        let q = l < 0.5 ? l * (1.0 + s) : (l + s - l * s)
        let p = 2.0 * l - q

        let r = hueToRGB(p, q, h + 1.0/3.0)
        let g = hueToRGB(p, q, h)
        let b = hueToRGB(p, q, h - 1.0/3.0)

        return SIMD3(r, g, b)
    }

    private func interpolateRGB(_ t: Double) -> Color {
        let idx = t * Double(stops.count - 1)
        let i = Int(idx)
        let frac = idx - Double(i)
        let c0 = stops[i].color
        let c1 = stops[min(i+1, stops.count-1)].color
        let c = mix(c0, c1, t: frac)
        return Color(red: c.x, green: c.y, blue: c.z)
    }

    private func interpolateHSL(_ t: Double) -> Color {
        // Interpolate via HSL
        let (h0, s0, l0) = rgbToHSL(stops.first!.color)
        let (h1, s1, l1) = rgbToHSL(stops.last!.color)
        let h = mixAngle(h0, h1, t)
        let s = simd_mix(s0, s1, t)
        let l = simd_mix(l0, l1, t)
        return hslToColor(h, s, l)
    }

    private func interpolateLCH(_ t: Double) -> Color {
        // Convert RGB to approximate LCH via HSL and manipulate
        return interpolateHSL(pow(t, 0.8)) // perceptual shaping
    }

    private func interpolateHCL(_ t: Double) -> Color {
        // Simple approximation
        return interpolateHSL(sqrt(t))
    }

    private func sineWaveScale(_ t: Double) -> Color {
        let phase = t * 2 * Double.pi
        let r = 0.5 + 0.5 * sin(phase)
        let g = 0.5 + 0.5 * sin(phase + 2 * Double.pi / 3)
        let b = 0.5 + 0.5 * sin(phase + 4 * Double.pi / 3)
        return Color(red: r, green: g, blue: b)
    }

    private func spiralHue(_ t: Double) -> Color {
        let radius = 0.5 + 0.5 * sin(6 * Double.pi * t)
        let angle = 2 * Double.pi * t
        let h = angle / (2 * Double.pi)
        let s = radius
        let l = 0.5
        return hslToColor(h, s, l)
    }

    private func hyperPulse(_ t: Double) -> Color {
        let pulse = pow(sin(Double.pi * t), 20)
        return Color(red: pulse, green: pulse * 0.5, blue: 1.0 - pulse)
    }

    // Helpers

    private func mix(_ a: SIMD3<Double>, _ b: SIMD3<Double>, t: Double) -> SIMD3<Double> {
        return a + t * (b - a)
    }

    private func simd_mix(_ a: Double, _ b: Double, _ t: Double) -> Double {
        return a + t * (b - a)
    }

    private func mixAngle(_ a: Double, _ b: Double, _ t: Double) -> Double {
        let delta = fmod((b - a + 1.5), 1.0) - 0.5
        return fmod((a + delta * t + 1.0), 1.0)
    }

    private func rgbToHSL(_ rgb: SIMD3<Double>) -> (Double, Double, Double) {
        let r = rgb.x, g = rgb.y, b = rgb.z
        let maxVal = max(r, g, b)
        let minVal = min(r, g, b)
        let l = 0.5 * (maxVal + minVal)

        var h: Double = 0
        var s: Double = 0

        if maxVal != minVal {
            let d = maxVal - minVal
            s = l > 0.5 ? d / (2.0 - maxVal - minVal) : d / (maxVal + minVal)

            if maxVal == r {
                h = (g - b) / d + (g < b ? 6 : 0)
            } else if maxVal == g {
                h = (b - r) / d + 2
            } else {
                h = (r - g) / d + 4
            }
            h /= 6
        }

        return (h, s, l)
    }

    private func hslToColor(_ h: Double, _ s: Double, _ l: Double) -> Color {
        func hueToRGB(_ p: Double, _ q: Double, _ t: Double) -> Double {
            var t = t
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            if t < 1/6 { return p + (q - p) * 6 * t }
            if t < 1/2 { return q }
            if t < 2/3 { return p + (q - p) * (2/3 - t) * 6 }
            return p
        }

        let q = l < 0.5 ? l * (1 + s) : (l + s - l * s)
        let p = 2 * l - q
        let r = hueToRGB(p, q, h + 1/3)
        let g = hueToRGB(p, q, h)
        let b = hueToRGB(p, q, h - 1/3)
        return Color(red: r, green: g, blue: b)
    }
}
