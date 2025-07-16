//
//  ColorPickerView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 16/07/2025.
//
import SwiftUI

// MARK: - Color Input Observable Object
class ColorInput: ObservableObject {
    @Published var color: Color = .black
    @Published var rgbRed: Float = 0.0
    @Published var rgbGreen: Float = 0.0
    @Published var rgbBlue: Float = 0.0
    @Published var rgbAlpha: Float = 1.0
    
    @Published var hsvHue: Float = 0.0
    @Published var hsvSaturation: Float = 1.0
    @Published var hsvValue: Float = 1.0
    @Published var hsvAlpha: Float = 1.0
    
    func updateFromRGB() {
        color = Color(.sRGB, red: Double(rgbRed), green: Double(rgbGreen), blue: Double(rgbBlue), opacity: Double(rgbAlpha))
        updateHSVFromRGB()
    }
    
    func updateFromHSV() {
        let rgb = hsvToRGB(h: hsvHue, s: hsvSaturation, v: hsvValue)
        rgbRed = rgb.r
        rgbGreen = rgb.g
        rgbBlue = rgb.b
        rgbAlpha = hsvAlpha
        color = Color(.sRGB, red: Double(rgbRed), green: Double(rgbGreen), blue: Double(rgbBlue), opacity: Double(rgbAlpha))
    }
    
    func updateFromColor(_ newColor: Color) {
        color = newColor
        let nsColor = NSColor(newColor)
        let rgbColor = nsColor.usingColorSpace(.sRGB) ?? nsColor
        
        rgbRed = Float(rgbColor.redComponent)
        rgbGreen = Float(rgbColor.greenComponent)
        rgbBlue = Float(rgbColor.blueComponent)
        rgbAlpha = Float(rgbColor.alphaComponent)
        
        updateHSVFromRGB()
    }
    
    private func updateHSVFromRGB() {
        let hsv = rgbToHSV(r: rgbRed, g: rgbGreen, b: rgbBlue)
        hsvHue = hsv.h
        hsvSaturation = hsv.s
        hsvValue = hsv.v
        hsvAlpha = rgbAlpha
    }
    
    private func rgbToHSV(r: Float, g: Float, b: Float) -> (h: Float, s: Float, v: Float) {
        let max = Swift.max(r, g, b)
        let min = Swift.min(r, g, b)
        let delta = max - min
        
        let v = max
        let s = max == 0 ? 0 : delta / max
        
        var h: Float = 0
        if delta != 0 {
            switch max {
            case r: h = (g - b) / delta + (g < b ? 6 : 0)
            case g: h = (b - r) / delta + 2
            case b: h = (r - g) / delta + 4
            default: break
            }
            h /= 6
        }
        
        return (h: h, s: s, v: v)
    }
    
    private func hsvToRGB(h: Float, s: Float, v: Float) -> (r: Float, g: Float, b: Float) {
        let i = Int(h * 6)
        let f = h * 6 - Float(i)
        let p = v * (1 - s)
        let q = v * (1 - f * s)
        let t = v * (1 - (1 - f) * s)
        
        switch i % 6 {
        case 0: return (r: v, g: t, b: p)
        case 1: return (r: q, g: v, b: p)
        case 2: return (r: p, g: v, b: t)
        case 3: return (r: p, g: q, b: v)
        case 4: return (r: t, g: p, b: v)
        case 5: return (r: v, g: p, b: q)
        default: return (r: 0, g: 0, b: 0)
        }
    }
}

// MARK: - Color Picker Modes
enum ColorPickerMode: String, CaseIterable {
    case palette = "Palette"
    case range = "Range"
    case rgb = "RGB"
    case hsv = "HSV"
}

// MARK: - Main Color Picker View
struct ColorPickerControlView: View {
    @ObservedObject var colorInput: ColorInput
    
    var onColorChange: ((Color) -> Void)? = nil  // Optional callback
    
    // Local state mirrors
    @State private var selectedMode: ColorPickerMode = .palette
    @State private var localRGBRed: Float = 1.0
    @State private var localRGBGreen: Float = 0.0
    @State private var localRGBBlue: Float = 0.0
    @State private var localRGBAlpha: Float = 1.0
    
    @State private var localHSVHue: Float = 0.0
    @State private var localHSVSaturation: Float = 1.0
    @State private var localHSVValue: Float = 1.0
    @State private var localHSVAlpha: Float = 1.0
    
    @State private var selectedPaletteColor: Color = .red
    @State private var selectedRangeColor: Color = .red
    
    var body: some View {
        VStack(spacing: 2) {
            // Mode Selector
            Picker("Color Mode", selection: $selectedMode) {
                ForEach(ColorPickerMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // Current Color Display
            RoundedRectangle(cornerRadius: 0)
                .fill(colorInput.color)
                .frame(height: 40)
            
            // Mode-specific controls
            Group {
                switch selectedMode {
                case .palette:
                    PaletteColorPickerView(
                        selectedColor: $selectedPaletteColor,
                        onColorSelected: { color in
                            colorInput.updateFromColor(color)
                        }
                    )
                    
                case .range:
                    RangeColorPickerView(
                        selectedColor: $selectedRangeColor,
                        onColorSelected: { color in
                            colorInput.updateFromColor(color)
                        }
                    )
                    
                case .rgb:
                    RGBColorPickerView(
                        red: $localRGBRed,
                        green: $localRGBGreen,
                        blue: $localRGBBlue,
                        alpha: $localRGBAlpha,
                        onColorChanged: { r, g, b, a in
                            colorInput.rgbRed = r
                            colorInput.rgbGreen = g
                            colorInput.rgbBlue = b
                            colorInput.rgbAlpha = a
                            colorInput.updateFromRGB()
                        }
                    )
                    
                case .hsv:
                    HSVColorPickerView(
                        hue: $localHSVHue,
                        saturation: $localHSVSaturation,
                        value: $localHSVValue,
                        alpha: $localHSVAlpha,
                        onColorChanged: { h, s, v, a in
                            colorInput.hsvHue = h
                            colorInput.hsvSaturation = s
                            colorInput.hsvValue = v
                            colorInput.hsvAlpha = a
                            colorInput.updateFromHSV()
                        }
                    )
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedMode)
        }
        .onAppear {
            syncLocalState()
        }
        .onChange(of: colorInput.color) { oldValue, newValue in
            // Update local state when color changes externally
            syncLocalState()
            onColorChange?(newValue)
        }
    }
    
    private func syncLocalState() {
        localRGBRed = colorInput.rgbRed
        localRGBGreen = colorInput.rgbGreen
        localRGBBlue = colorInput.rgbBlue
        localRGBAlpha = colorInput.rgbAlpha
        
        localHSVHue = colorInput.hsvHue
        localHSVSaturation = colorInput.hsvSaturation
        localHSVValue = colorInput.hsvValue
        localHSVAlpha = colorInput.hsvAlpha
        
        selectedPaletteColor = colorInput.color
        selectedRangeColor = colorInput.color
    }
}



// MARK: - Utility Functions
private func clampFloat(_ value: Float, min: Float, max: Float) -> Float {
    return Swift.min(Swift.max(value, min), max)
}
