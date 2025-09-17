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
    var rgbRed: Float = 0.0
    var rgbGreen: Float = 0.0
    var rgbBlue: Float = 0.0
    var rgbAlpha: Float = 1.0
    
    var hsvHue: Float = 0.0
    var hsvSaturation: Float = 1.0
    var hsvValue: Float = 1.0
    var hsvAlpha: Float = 1.0
    
    // Performance optimization: Debounce timer for batch updates
    private var updateTimer: Timer?
    private let updateDebounceInterval: TimeInterval = 0.016 // ~60 FPS
    
    init(initialColor: Color = .black) {
        color = initialColor
    }
    
    // Optimized update methods with debouncing
    func updateFromRGB(debounced: Bool = true) {
        if debounced {
            scheduleUpdate { [weak self] in
                self?.performRGBUpdate()
            }
        } else {
            performRGBUpdate()
        }
    }
    
    func updateFromHSV(debounced: Bool = true) {
        if debounced {
            scheduleUpdate { [weak self] in
                self?.performHSVUpdate()
            }
        } else {
            performHSVUpdate()
        }
    }
    
    private func scheduleUpdate(_ action: @escaping () -> Void) {
        print("Scheduling update")
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateDebounceInterval, repeats: false) { _ in
            DispatchQueue.main.async {
                action()
            }
        }
    }
    
    private func performRGBUpdate() {
        color = Color(.sRGB, red: Double(rgbRed), green: Double(rgbGreen), blue: Double(rgbBlue), opacity: Double(rgbAlpha))
        updateHSVFromRGB()
    }
    
    private func performHSVUpdate() {
        let rgb = hsvToRGB(h: hsvHue, s: hsvSaturation, v: hsvValue)
        rgbRed = rgb.r
        rgbGreen = rgb.g
        rgbBlue = rgb.b
        rgbAlpha = hsvAlpha
        color = Color(.sRGB, red: Double(rgbRed), green: Double(rgbGreen), blue: Double(rgbBlue), opacity: Double(rgbAlpha))
    }
    
    func updateFromColor(_ newColor: Color) {
        // Cache the color conversion to avoid repeated NSColor operations
        color = newColor
        
        // More efficient color component extraction
        let components = extractColorComponents(from: newColor)
        rgbRed = components.r
        rgbGreen = components.g
        rgbBlue = components.b
        rgbAlpha = components.a
        
        updateHSVFromRGB()
    }
    
    // Optimized color component extraction
    private func extractColorComponents(from color: Color) -> (r: Float, g: Float, b: Float, a: Float) {
        let nsColor = NSColor(color)
        let rgbColor = nsColor.usingColorSpace(.sRGB) ?? nsColor
        
        return (
            r: Float(rgbColor.redComponent),
            g: Float(rgbColor.greenComponent),
            b: Float(rgbColor.blueComponent),
            a: Float(rgbColor.alphaComponent)
        )
    }
    
    private func updateHSVFromRGB() {
        let hsv = rgbToHSV(r: rgbRed, g: rgbGreen, b: rgbBlue)
        hsvHue = hsv.h
        hsvSaturation = hsv.s
        hsvValue = hsv.v
        hsvAlpha = rgbAlpha
    }
    
    // Optimized color space conversion functions
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
    
    deinit {
        updateTimer?.invalidate()
    }
}

// MARK: - Color Picker Modes
enum ColorPickerMode: String, CaseIterable {
    case palette = "Palette"
    case range = "Range"
    case rgb = "RGB"
    case hsv = "HSV"
}

// MARK: - Performance-Optimized Color Picker View
struct ColorPickerControlView: View {
    @ObservedObject var colorInput: ColorInput
    
    var onColorChange: ((Color) -> Void)? = nil  // Optional callback
    
    // Local state mirrors - now with reduced update frequency
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
    
    // Performance optimization: Debounce timer for UI updates
    @State private var colorDisplayTimer: Timer?
    @State private var displayColor: Color = .red
    
    var body: some View {
        VStack(spacing: 2) {
            // Mode Selector
            Picker("Color Mode", selection: $selectedMode) {
                ForEach(ColorPickerMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // Current Color Display - Optimized with debounced updates
            RoundedRectangle(cornerRadius: 0)
                .fill(displayColor)
                .frame(height: 40)
                .drawingGroup() // Rasterize for better performance
            
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
                    OptimizedRGBColorPickerView(
                        red: $localRGBRed,
                        green: $localRGBGreen,
                        blue: $localRGBBlue,
                        alpha: $localRGBAlpha,
                        onColorChanged: { r, g, b, a in
                            colorInput.rgbRed = r
                            colorInput.rgbGreen = g
                            colorInput.rgbBlue = b
                            colorInput.rgbAlpha = a
                            colorInput.updateFromRGB(debounced: true)
                        }
                    )
                    
                case .hsv:
                    OptimizedHSVColorPickerView(
                        hue: $localHSVHue,
                        saturation: $localHSVSaturation,
                        value: $localHSVValue,
                        alpha: $localHSVAlpha,
                        onColorChanged: { h, s, v, a in
                            colorInput.hsvHue = h
                            colorInput.hsvSaturation = s
                            colorInput.hsvValue = v
                            colorInput.hsvAlpha = a
                            colorInput.updateFromHSV(debounced: true)
                        }
                    )
                }
            }
            .drawingGroup() // Rasterize complex UI for better performance
        }
        .onAppear {
            syncLocalState()
            displayColor = colorInput.color
        }
        .onChange(of: colorInput.color) { oldValue, newValue in
            // Debounced display color update
            scheduleDisplayColorUpdate(newValue)
            syncLocalState()
            onColorChange?(newValue)
        }
    }
    
    private func scheduleDisplayColorUpdate(_ newColor: Color) {
        colorDisplayTimer?.invalidate()
        colorDisplayTimer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: false) { _ in // ~30 FPS for display
            DispatchQueue.main.async {
                displayColor = newColor
            }
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

// MARK: - Performance-Optimized RGB Picker
struct OptimizedRGBColorPickerView: View {
    @Binding var red: Float
    @Binding var green: Float
    @Binding var blue: Float
    @Binding var alpha: Float
    
    let onColorChanged: (Float, Float, Float, Float) -> Void
    
    // Local state to avoid excessive callbacks
    @State private var localRed: Float = 0.0
    @State private var localGreen: Float = 0.0
    @State private var localBlue: Float = 0.0
    @State private var localAlpha: Float = 1.0
    
    var body: some View {
        VStack(spacing: 8) {
            ColorSliderRow(
                label: "R",
                value: $localRed,
                color: .red,
                range: 0...1,
                onChanged: { newValue in
                    red = newValue
                    onColorChanged(newValue, green, blue, alpha)
                }
            )
            
            ColorSliderRow(
                label: "G",
                value: $localGreen,
                color: .green,
                range: 0...1,
                onChanged: { newValue in
                    green = newValue
                    onColorChanged(red, newValue, blue, alpha)
                }
            )
            
            ColorSliderRow(
                label: "B",
                value: $localBlue,
                color: .blue,
                range: 0...1,
                onChanged: { newValue in
                    blue = newValue
                    onColorChanged(red, green, newValue, alpha)
                }
            )
            
            ColorSliderRow(
                label: "A",
                value: $localAlpha,
                color: .gray,
                range: 0...1,
                onChanged: { newValue in
                    alpha = newValue
                    onColorChanged(red, green, blue, newValue)
                }
            )
        }
        .onAppear {
            localRed = red
            localGreen = green
            localBlue = blue
            localAlpha = alpha
        }
    }
}

// MARK: - Performance-Optimized HSV Picker
struct OptimizedHSVColorPickerView: View {
    @Binding var hue: Float
    @Binding var saturation: Float
    @Binding var value: Float
    @Binding var alpha: Float
    
    let onColorChanged: (Float, Float, Float, Float) -> Void
    
    // Local state to avoid excessive callbacks
    @State private var localHue: Float = 0.0
    @State private var localSaturation: Float = 1.0
    @State private var localValue: Float = 1.0
    @State private var localAlpha: Float = 1.0
    
    var body: some View {
        VStack(spacing: 8) {
            ColorSliderRow(
                label: "H",
                value: $localHue,
                color: .primary,
                range: 0...1,
                displayValue: "\(Int(localHue * 360))°",
                onChanged: { newValue in
                    hue = newValue
                    onColorChanged(newValue, saturation, value, alpha)
                }
            )
            
            ColorSliderRow(
                label: "S",
                value: $localSaturation,
                color: .primary,
                range: 0...1,
                displayValue: "\(Int(localSaturation * 100))%",
                onChanged: { newValue in
                    saturation = newValue
                    onColorChanged(hue, newValue, value, alpha)
                }
            )
            
            ColorSliderRow(
                label: "V",
                value: $localValue,
                color: .primary,
                range: 0...1,
                displayValue: "\(Int(localValue * 100))%",
                onChanged: { newValue in
                    value = newValue
                    onColorChanged(hue, saturation, newValue, alpha)
                }
            )
            
            ColorSliderRow(
                label: "A",
                value: $localAlpha,
                color: .gray,
                range: 0...1,
                displayValue: "\(Int(localAlpha * 100))%",
                onChanged: { newValue in
                    alpha = newValue
                    onColorChanged(hue, saturation, value, newValue)
                }
            )
        }
        .onAppear {
            localHue = hue
            localSaturation = saturation
            localValue = value
            localAlpha = alpha
        }
    }
}

struct ColorSliderRow: View {
    let label: String
    @Binding var value: Float
    let color: Color
    let range: ClosedRange<Float>
    var displayValue: String?
    let onChanged: (Float) -> Void

    @State private var pendingTask: Task<Void, Never>?
    @State private var isEditing = false

    var body: some View {
        HStack {
            Text(label).frame(width: 20)
            Slider(
                value: Binding(
                    get: { value },
                    set: { newValue in
                        value = newValue
                        if isEditing {
                            // FIX #3a: throttled while dragging
                            pendingTask?.cancel()
                            pendingTask = Task { // ~30 fps throttle
                                try? await Task.sleep(nanoseconds: 33_000_000)
                                onChanged(newValue)
                            }
                        } else {
                            // not editing (programmatic), avoid callback loop
                        }
                    }
                ),
                in: range,
                onEditingChanged: { editing in
                    isEditing = editing
                    if !editing {
                        // FIX #3b: single commit at drag end
                        pendingTask?.cancel()
                        onChanged(value)
                    }
                }
            )
            .accentColor(color)

            Text(displayValue ?? "\(Int(value * 255))")
                .frame(width: 40)
                .fontDesign(.monospaced)
        }
    }
}



// MARK: - Utility Functions
private func clampFloat(_ value: Float, min: Float, max: Float) -> Float {
    return Swift.min(Swift.max(value, min), max)
}
