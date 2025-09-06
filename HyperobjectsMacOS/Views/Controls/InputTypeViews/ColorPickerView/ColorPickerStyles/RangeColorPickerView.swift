//
//  RangeColorPickerView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 16/07/2025.
//

import SwiftUI


// MARK: - Range Color Picker
struct RangeColorPickerView: View {
    @Binding var selectedColor: Color
    let onColorSelected: (Color) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Hue Range")
                .font(.caption)
            
            // Hue gradient bar
            GeometryReader { geometry in
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.sRGB, red: 1, green: 0, blue: 0),
                        Color(.sRGB, red: 1, green: 1, blue: 0),
                        Color(.sRGB, red: 0, green: 1, blue: 0),
                        Color(.sRGB, red: 0, green: 1, blue: 1),
                        Color(.sRGB, red: 0, green: 0, blue: 1),
                        Color(.sRGB, red: 1, green: 0, blue: 1),
                        Color(.sRGB, red: 1, green: 0, blue: 0)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .cornerRadius(10)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let hue = max(0, min(1, Float(value.location.x / max(1, geometry.size.width))))
                            let color = Color(hue: Double(hue), saturation: 1.0, brightness: 1.0)
                            selectedColor = color
                            onColorSelected(color)
                        }
                )
            }
            .frame(height: 20)
            
            Text("Brightness Range")
                .font(.caption)
            
            // Brightness gradient bar
            GeometryReader { geometry in
                LinearGradient(
                    gradient: Gradient(colors: [.black, selectedColor]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .cornerRadius(10)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let brightness = max(0, min(1, Float(value.location.x / max(1, geometry.size.width))))
                            let nsColor = NSColor(selectedColor)
                            let rgbColor = nsColor.usingColorSpace(.sRGB) ?? nsColor
                            
                            let color = Color(
                                hue: Double(rgbColor.hueComponent),
                                saturation: Double(rgbColor.saturationComponent),
                                brightness: Double(brightness),
                                opacity: Double(rgbColor.alphaComponent)
                            )
                            selectedColor = color
                            onColorSelected(color)
                        }
                )
            }
            .frame(height: 20)
        }
    }
}
