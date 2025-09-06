//
//  RGBColorPickerView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 16/07/2025.
//

import SwiftUI


// MARK: - RGB Color Picker
struct RGBColorPickerView: View {
    @Binding var red: Float
    @Binding var green: Float
    @Binding var blue: Float
    @Binding var alpha: Float
    
    let onColorChanged: (Float, Float, Float, Float) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("R")
                    .frame(width: 20)
                Slider(value: $red, in: 0...1)
                    .accentColor(.red)
                    .onChange(of: red) { _, newValue in
                        onColorChanged(newValue, green, blue, alpha)
                    }
                Text("\(Int(red * 255))")
                    .frame(width: 30)
            }
            
            HStack {
                Text("G")
                    .frame(width: 20)
                Slider(value: $green, in: 0...1)
                    .accentColor(.green)
                    .onChange(of: green) { _, newValue in
                        onColorChanged(red, newValue, blue, alpha)
                    }
                Text("\(Int(green * 255))")
                    .frame(width: 30)
            }
            
            HStack {
                Text("B")
                    .frame(width: 20)
                Slider(value: $blue, in: 0...1)
                    .accentColor(.blue)
                    .onChange(of: blue) { _, newValue in
                        onColorChanged(red, green, newValue, alpha)
                    }
                Text("\(Int(blue * 255))")
                    .frame(width: 30)
            }
            
            HStack {
                Text("A")
                    .frame(width: 20)
                Slider(value: $alpha, in: 0...1)
                    .accentColor(.gray)
                    .onChange(of: alpha) { _, newValue in
                        onColorChanged(red, green, blue, newValue)
                    }
                Text("\(Int(alpha * 255))")
                    .frame(width: 30)
            }
        }
    }
}
