//
//  HSVColorPickerView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 16/07/2025.
//

import SwiftUI

// MARK: - HSV Color Picker
struct HSVColorPickerView: View {
    @Binding var hue: Float
    @Binding var saturation: Float
    @Binding var value: Float
    @Binding var alpha: Float
    
    let onColorChanged: (Float, Float, Float, Float) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("H")
                    .frame(width: 20)
                Slider(value: $hue, in: 0...1)
                    .onChange(of: hue) { _, newValue in
                        onColorChanged(newValue, saturation, value, alpha)
                    }
                Text("\(Int(hue * 360))°")
                    .frame(width: 40)
            }
            
            HStack {
                Text("S")
                    .frame(width: 20)
                Slider(value: $saturation, in: 0...1)
                    .onChange(of: saturation) { _, newValue in
                        onColorChanged(hue, newValue, value, alpha)
                    }
                Text("\(Int(saturation * 100))%")
                    .frame(width: 40)
            }
            
            HStack {
                Text("V")
                    .frame(width: 20)
                Slider(value: $value, in: 0...1)
                    .onChange(of: value) { _, newValue in
                        onColorChanged(hue, saturation, newValue, alpha)
                    }
                Text("\(Int(value * 100))%")
                    .frame(width: 40)
            }
            
            HStack {
                Text("A")
                    .frame(width: 20)
                Slider(value: $alpha, in: 0...1)
                    .accentColor(.gray)
                    .onChange(of: alpha) { _, newValue in
                        onColorChanged(hue, saturation, value, newValue)
                    }
                Text("\(Int(alpha * 100))%")
                    .frame(width: 40)
            }
        }
    }
}
