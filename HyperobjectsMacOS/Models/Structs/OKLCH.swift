//
//  OKLCH.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 25/01/2026.
//

import simd
import Foundation

// MARK: - OKLCH Color Space

/// A color in OKLCH (Oklab Lightness, Chroma, Hue) perceptual color space.
/// This space provides perceptually uniform lightness and clean gradients,
/// making it ideal for generative art and computational color work.
///
/// - L: Lightness (0.0 = black, 1.0 = white)
/// - C: Chroma (0.0 = gray, typically 0.0-0.4 for displayable colors)
/// - H: Hue in degrees (0-360, where 0=pink, 90=yellow, 180=cyan, 270=blue)
struct OKLCH: Equatable, Hashable {
    var L: Float  // Lightness: 0...1
    var C: Float  // Chroma: 0...~0.4 (displayable range)
    var H: Float  // Hue: 0...360 degrees
    
    // MARK: - Initialization
    
    init(L: Float, C: Float, H: Float) {
        self.L = L
        self.C = C
        self.H = Self.normalizeHue(H)
    }
    
    /// Create from normalized values (all 0-1, hue will be scaled to 0-360)
    static func normalized(l: Float, c: Float, h: Float) -> OKLCH {
        OKLCH(L: l, C: c * 0.4, H: h * 360)
    }
    
    /// Create a neutral gray at the given lightness
    static func gray(_ lightness: Float) -> OKLCH {
        OKLCH(L: lightness, C: 0, H: 0)
    }
    
    /// Create from sRGB values (0-1 range)
    init(sRGB r: Float, _ g: Float, _ b: Float) {
        let lab = Self.sRGBtoOKLAB(r: r, g: g, b: b)
        let lch = Self.labToLCH(L: lab.L, a: lab.a, b: lab.b)
        self.L = lch.L
        self.C = lch.C
        self.H = lch.H
    }
    
    /// Create from a SIMD4<Float> (rgb or rgba, alpha ignored for conversion)
    init(simd: SIMD4<Float>) {
        self.init(sRGB: simd.x, simd.y, simd.z)
    }
    
    /// Create from 8-bit RGB values (0-255)
    init(rgb8 r: UInt8, _ g: UInt8, _ b: UInt8) {
        self.init(sRGB: Float(r) / 255, Float(g) / 255, Float(b) / 255)
    }
    
    /// Create from hex string (supports "FF5500", "#FF5500", "0xFF5500")
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        hexSanitized = hexSanitized.replacingOccurrences(of: "0X", with: "")
        
        guard hexSanitized.count == 6,
              let hexValue = UInt32(hexSanitized, radix: 16) else {
            return nil
        }
        
        let r = UInt8((hexValue >> 16) & 0xFF)
        let g = UInt8((hexValue >> 8) & 0xFF)
        let b = UInt8(hexValue & 0xFF)
        self.init(rgb8: r, g, b)
    }
    
    // MARK: - Output Conversions
    
    /// Convert to SIMD4<Float> in sRGB space (alpha = 1.0)
    var simd: SIMD4<Float> {
        simd4(alpha: 1.0)
    }
    
    /// Convert to SIMD4<Float> in sRGB space with custom alpha
    func simd4(alpha: Float) -> SIMD4<Float> {
        let rgb = toSRGB()
        return SIMD4<Float>(rgb.r, rgb.g, rgb.b, alpha)
    }
    
    /// Convert to sRGB tuple (values clamped to 0-1)
    func toSRGB() -> (r: Float, g: Float, b: Float) {
        let lab = Self.lchToLAB(L: L, C: C, H: H)
        return Self.oklabToSRGB(L: lab.L, a: lab.a, b: lab.b)
    }
    
    /// Convert to linear RGB (for shader calculations that expect linear light)
    func toLinearRGB() -> SIMD4<Float> {
        let lab = Self.lchToLAB(L: L, C: C, H: H)
        let linear = Self.oklabToLinearRGB(L: lab.L, a: lab.a, b: lab.b)
        return SIMD4<Float>(linear.r, linear.g, linear.b, 1.0)
    }
    
    /// Convert to 8-bit RGB values
    func toRGB8() -> (r: UInt8, g: UInt8, b: UInt8) {
        let rgb = toSRGB()
        return (
            UInt8(clamping: Int(rgb.r * 255)),
            UInt8(clamping: Int(rgb.g * 255)),
            UInt8(clamping: Int(rgb.b * 255))
        )
    }
    
    /// Convert to hex string (e.g., "FF5500")
    var hex: String {
        let rgb8 = toRGB8()
        return String(format: "%02X%02X%02X", rgb8.r, rgb8.g, rgb8.b)
    }
    
    /// Check if this color is within the sRGB gamut
    var isInGamut: Bool {
        let rgb = toSRGB()
        return rgb.r >= 0 && rgb.r <= 1 &&
               rgb.g >= 0 && rgb.g <= 1 &&
               rgb.b >= 0 && rgb.b <= 1
    }
    
    /// Return a gamut-mapped version (reduces chroma until displayable)
    func gamutMapped() -> OKLCH {
        var result = self
        while !result.isInGamut && result.C > 0.001 {
            result.C *= 0.95
        }
        return result
    }
    
    // MARK: - Color Manipulation
    
    /// Adjust lightness (clamped to 0-1)
    func withLightness(_ newL: Float) -> OKLCH {
        OKLCH(L: max(0, min(1, newL)), C: C, H: H)
    }
    
    /// Adjust chroma (clamped to 0+)
    func withChroma(_ newC: Float) -> OKLCH {
        OKLCH(L: L, C: max(0, newC), H: H)
    }
    
    /// Adjust hue (normalized to 0-360)
    func withHue(_ newH: Float) -> OKLCH {
        OKLCH(L: L, C: C, H: newH)
    }
    
    /// Shift lightness by delta
    func lighten(_ delta: Float) -> OKLCH {
        withLightness(L + delta)
    }
    
    /// Shift chroma by delta
    func saturate(_ delta: Float) -> OKLCH {
        withChroma(C + delta)
    }
    
    /// Rotate hue by degrees
    func rotateHue(_ degrees: Float) -> OKLCH {
        withHue(H + degrees)
    }
    
    /// Desaturate to grayscale
    var grayscale: OKLCH {
        OKLCH(L: L, C: 0, H: H)
    }
    
    // MARK: - Color Harmonies
    
    /// Complementary color (180° rotation)
    var complementary: OKLCH {
        rotateHue(180)
    }
    
    /// Split complementary colors (±150°)
    var splitComplementary: (OKLCH, OKLCH) {
        (rotateHue(150), rotateHue(210))
    }
    
    /// Triadic colors (120° apart)
    var triadic: (OKLCH, OKLCH) {
        (rotateHue(120), rotateHue(240))
    }
    
    /// Tetradic/square colors (90° apart)
    var tetradic: (OKLCH, OKLCH, OKLCH) {
        (rotateHue(90), rotateHue(180), rotateHue(270))
    }
    
    /// Analogous colors at given spread angle
    func analogous(spread: Float = 30) -> (OKLCH, OKLCH) {
        (rotateHue(-spread), rotateHue(spread))
    }
    
    /// Generate n evenly-spaced hues starting from this color
    func polyad(_ n: Int) -> [OKLCH] {
        let step = 360.0 / Float(n)
        return (0..<n).map { rotateHue(Float($0) * step) }
    }
    
    // MARK: - Range & Gradient Generation
    
    /// Linear interpolation to another color
    func lerp(to other: OKLCH, t: Float) -> OKLCH {
        let t = max(0, min(1, t))
        
        // Handle hue interpolation through shortest path
        var deltaH = other.H - H
        if deltaH > 180 { deltaH -= 360 }
        if deltaH < -180 { deltaH += 360 }
        
        return OKLCH(
            L: L + (other.L - L) * t,
            C: C + (other.C - C) * t,
            H: H + deltaH * t
        )
    }
    
    /// Generate n colors interpolated between self and target
    func gradient(to other: OKLCH, steps: Int) -> [OKLCH] {
        guard steps > 1 else { return [self] }
        return (0..<steps).map { lerp(to: other, t: Float($0) / Float(steps - 1)) }
    }
    
    /// Generate a lightness ramp (same hue/chroma, varying lightness)
    func lightnessRamp(from minL: Float = 0.2, to maxL: Float = 0.9, steps: Int = 5) -> [OKLCH] {
        let step = (maxL - minL) / Float(steps - 1)
        return (0..<steps).map { OKLCH(L: minL + Float($0) * step, C: C, H: H) }
    }
    
    /// Generate a chroma ramp (gray to saturated)
    func chromaRamp(from minC: Float = 0, to maxC: Float = 0.3, steps: Int = 5) -> [OKLCH] {
        let step = (maxC - minC) / Float(steps - 1)
        return (0..<steps).map { OKLCH(L: L, C: minC + Float($0) * step, H: H) }
    }
    
    /// Generate a hue sweep (constant L and C)
    func hueSweep(steps: Int = 12) -> [OKLCH] {
        polyad(steps)
    }
    
    /// Generate colors along a hue arc
    func hueArc(sweep: Float, steps: Int) -> [OKLCH] {
        let stepAngle = sweep / Float(steps - 1)
        return (0..<steps).map { rotateHue(Float($0) * stepAngle) }
    }
    
    // MARK: - Palette Generation
    
    /// Generate a monochromatic palette with varying lightness
    func monochromatic(count: Int = 5) -> [OKLCH] {
        let minL: Float = 0.25
        let maxL: Float = 0.85
        let step = (maxL - minL) / Float(count - 1)
        return (0..<count).map {
            OKLCH(L: minL + Float($0) * step, C: C, H: H)
        }
    }
    
    /// Generate an analogous palette
    func analogousPalette(count: Int = 5, spread: Float = 60) -> [OKLCH] {
        let startH = H - spread / 2
        let step = spread / Float(count - 1)
        return (0..<count).map {
            OKLCH(L: L, C: C, H: startH + Float($0) * step)
        }
    }
    
    /// Generate a warm-to-cool gradient through this color
    func warmCoolGradient(steps: Int = 7) -> [OKLCH] {
        let warm = withHue(30)   // Orange
        let cool = withHue(240) // Blue
        return warm.gradient(to: cool, steps: steps)
    }
    
    // MARK: - Random Generation
    
    /// Random color with full ranges
    static func random() -> OKLCH {
        OKLCH(
            L: Float.random(in: 0.3...0.85),
            C: Float.random(in: 0.05...0.25),
            H: Float.random(in: 0...360)
        )
    }
    
    /// Random color within specified ranges
    static func random(
        lightness: ClosedRange<Float> = 0.3...0.85,
        chroma: ClosedRange<Float> = 0.05...0.25,
        hue: ClosedRange<Float> = 0...360
    ) -> OKLCH {
        OKLCH(
            L: Float.random(in: lightness),
            C: Float.random(in: chroma),
            H: Float.random(in: hue)
        )
    }
    
    /// Random pastel (high lightness, low chroma)
    static func randomPastel() -> OKLCH {
        random(lightness: 0.75...0.9, chroma: 0.05...0.12)
    }
    
    /// Random vibrant color (medium lightness, high chroma)
    static func randomVibrant() -> OKLCH {
        random(lightness: 0.55...0.75, chroma: 0.18...0.3)
    }
    
    /// Random dark/moody color
    static func randomDark() -> OKLCH {
        random(lightness: 0.2...0.4, chroma: 0.05...0.15)
    }
    
    /// Random variation of this color within deltas
    func randomized(
        lightnessVariation: Float = 0.1,
        chromaVariation: Float = 0.05,
        hueVariation: Float = 20
    ) -> OKLCH {
        OKLCH(
            L: L + Float.random(in: -lightnessVariation...lightnessVariation),
            C: C + Float.random(in: -chromaVariation...chromaVariation),
            H: H + Float.random(in: -hueVariation...hueVariation)
        )
    }
    
    // MARK: - Probabilistic Palettes (Tyler Hobbs style)
    
    /// A weighted color for probabilistic selection
    struct WeightedColor {
        let color: OKLCH
        let weight: Float
        
        init(_ color: OKLCH, weight: Float = 1.0) {
            self.color = color
            self.weight = weight
        }
    }
    
    /// Select a random color from weighted options
    static func weightedRandom(from palette: [WeightedColor]) -> OKLCH {
        let totalWeight = palette.reduce(0) { $0 + $1.weight }
        var random = Float.random(in: 0..<totalWeight)
        
        for item in palette {
            random -= item.weight
            if random <= 0 {
                return item.color
            }
        }
        return palette.last?.color ?? .random()
    }
    
    /// Create a probabilistic palette with specified weights
    static func probabilisticPalette(_ colors: [(OKLCH, Float)]) -> [WeightedColor] {
        colors.map { WeightedColor($0.0, weight: $0.1) }
    }
    
    // MARK: - Perceptual Utilities
    
    /// Perceptual contrast ratio approximation (useful for readability)
    func contrastWith(_ other: OKLCH) -> Float {
        let lighterL = max(L, other.L)
        let darkerL = min(L, other.L)
        return (lighterL + 0.05) / (darkerL + 0.05)
    }
    
    /// Find a contrasting color for text/overlay
    func contrastingColor(minContrast: Float = 4.5) -> OKLCH {
        // Try white or black first
        let white = OKLCH(L: 1.0, C: 0, H: H)
        let black = OKLCH(L: 0.0, C: 0, H: H)
        
        if contrastWith(white) >= minContrast {
            return white
        } else if contrastWith(black) >= minContrast {
            return black
        }
        
        // Return whichever has better contrast
        return contrastWith(white) > contrastWith(black) ? white : black
    }
    
    /// Euclidean distance in OKLCH space (approximate perceptual difference)
    func distance(to other: OKLCH) -> Float {
        let dL = L - other.L
        let dC = C - other.C
        var dH = (H - other.H) / 360.0 // Normalize hue to 0-1 for distance
        if dH > 0.5 { dH -= 1.0 }
        if dH < -0.5 { dH += 1.0 }
        return sqrt(dL * dL + dC * dC + dH * dH)
    }
    
    // MARK: - Color Space Conversion Internals
    
    private static func normalizeHue(_ h: Float) -> Float {
        var hue = h.truncatingRemainder(dividingBy: 360)
        if hue < 0 { hue += 360 }
        return hue
    }
    
    // OKLAB to OKLCH
    private static func labToLCH(L: Float, a: Float, b: Float) -> (L: Float, C: Float, H: Float) {
        let C = sqrt(a * a + b * b)
        var H = atan2(b, a) * 180 / .pi
        if H < 0 { H += 360 }
        return (L, C, H)
    }
    
    // OKLCH to OKLAB
    private static func lchToLAB(L: Float, C: Float, H: Float) -> (L: Float, a: Float, b: Float) {
        let hRad = H * .pi / 180
        let a = C * cos(hRad)
        let b = C * sin(hRad)
        return (L, a, b)
    }
    
    // sRGB to Linear RGB
    private static func sRGBToLinear(_ c: Float) -> Float {
        if c <= 0.04045 {
            return c / 12.92
        }
        return pow((c + 0.055) / 1.055, 2.4)
    }
    
    // Linear RGB to sRGB
    private static func linearToSRGB(_ c: Float) -> Float {
        if c <= 0.0031308 {
            return c * 12.92
        }
        return 1.055 * pow(c, 1.0 / 2.4) - 0.055
    }
    
    // sRGB to OKLAB
    private static func sRGBtoOKLAB(r: Float, g: Float, b: Float) -> (L: Float, a: Float, b: Float) {
        let lr = sRGBToLinear(r)
        let lg = sRGBToLinear(g)
        let lb = sRGBToLinear(b)
        
        let l = 0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb
        let m = 0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb
        let s = 0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb
        
        let l_ = cbrt(l)
        let m_ = cbrt(m)
        let s_ = cbrt(s)
        
        let L = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_
        let a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_
        let bOut = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_
        
        return (L, a, bOut)
    }
    
    // OKLAB to Linear RGB
    private static func oklabToLinearRGB(L: Float, a: Float, b: Float) -> (r: Float, g: Float, b: Float) {
        let l_ = L + 0.3963377774 * a + 0.2158037573 * b
        let m_ = L - 0.1055613458 * a - 0.0638541728 * b
        let s_ = L - 0.0894841775 * a - 1.2914855480 * b
        
        let l = l_ * l_ * l_
        let m = m_ * m_ * m_
        let s = s_ * s_ * s_
        
        let r = +4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
        let g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
        let bOut = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
        
        return (r, g, bOut)
    }
    
    // OKLAB to sRGB (clamped)
    private static func oklabToSRGB(L: Float, a: Float, b: Float) -> (r: Float, g: Float, b: Float) {
        let linear = oklabToLinearRGB(L: L, a: a, b: b)
        return (
            max(0, min(1, linearToSRGB(linear.r))),
            max(0, min(1, linearToSRGB(linear.g))),
            max(0, min(1, linearToSRGB(linear.b)))
        )
    }
}

// MARK: - CustomStringConvertible

extension OKLCH: CustomStringConvertible {
    var description: String {
        String(format: "OKLCH(L: %.3f, C: %.3f, H: %.1f°)", L, C, H)
    }
}

// MARK: - Codable

extension OKLCH: Codable {}

// MARK: - Array Extensions for Palettes

extension Array where Element == OKLCH {
    /// Convert entire palette to SIMD4 array
    var simds: [SIMD4<Float>] {
        map { $0.simd }
    }
    
    /// Get a random color from the palette
    var randomElement: OKLCH? {
        isEmpty ? nil : self[Int.random(in: 0..<count)]
    }
    
    /// Gamut-map all colors in palette
    var gamutMapped: [OKLCH] {
        map { $0.gamutMapped() }
    }
    
    /// Sort by lightness
    var sortedByLightness: [OKLCH] {
        sorted { $0.L < $1.L }
    }
    
    /// Sort by hue
    var sortedByHue: [OKLCH] {
        sorted { $0.H < $1.H }
    }
    
    /// Sort by chroma
    var sortedByChroma: [OKLCH] {
        sorted { $0.C < $1.C }
    }
}

// MARK: - Usage Examples

/*
 
// Basic creation and conversion
let coral = OKLCH(L: 0.7, C: 0.15, H: 30)
let metalColor = coral.simd  // SIMD4<Float> for Metal shaders

// From hex
let fromHex = OKLCH(hex: "#FF6B6B")!

// Color harmonies
let complement = coral.complementary
let (triad1, triad2) = coral.triadic
let analogColors = coral.analogous(spread: 25)

// Gradients
let gradient = coral.gradient(to: coral.complementary, steps: 10)
let lightnessRamp = coral.lightnessRamp(steps: 7)

// Random generation
let pastel = OKLCH.randomPastel()
let vibrant = OKLCH.randomVibrant()
let variation = coral.randomized(hueVariation: 15)

// Probabilistic palette (Tyler Hobbs style)
let palette = OKLCH.probabilisticPalette([
    (OKLCH(L: 0.65, C: 0.2, H: 30), 0.4),   // 40% coral
    (OKLCH(L: 0.7, C: 0.15, H: 200), 0.3),  // 30% teal
    (OKLCH(L: 0.9, C: 0.02, H: 60), 0.2),   // 20% off-white
    (OKLCH(L: 0.25, C: 0.05, H: 270), 0.1)  // 10% dark purple
])
let selected = OKLCH.weightedRandom(from: palette)

// For Metal: get array of SIMD4 colors
let colors = gradient.simds

*/
