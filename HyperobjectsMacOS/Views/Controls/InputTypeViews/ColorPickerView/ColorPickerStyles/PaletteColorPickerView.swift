//
//  PalettePickerView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 16/07/2025.
//

import SwiftUI


// MARK: - Palette Color Picker
struct PaletteColorPickerView: View {
    @Binding var selectedColor: Color
    let onColorSelected: (Color) -> Void
    
    private let paletteColors: [Color] = [
        .white, .black,
        
        // Dark green palette
        Color(hex: "#3A8C75"),
        Color(hex: "#31594E"),
        Color(hex: "#09402C"),
        Color(hex: "#0A261C"),
        Color(hex: "#0D0D0D"),
        
        // Red palette
        Color(hex: "#F23005"),
        Color(hex: "#A62205"),
        Color(hex: "#591E11"),
        Color(hex: "#D9B1AD"),
        Color(hex: "#0D0D0D"),
    
        // Fashion palette
        Color(hex: "#D9731A"),
        Color(hex: "#260E09"),
        Color(hex: "#BF281B"),
        Color(hex: "#400F0A"),
        Color(hex: "#8C1414"),
        
        // Bungie marathon
        Color(hex: "#c2fe0b"),
        Color(hex: "#01ffff"),
        Color(hex: "#ff0d1a"),
        Color(hex: "#29324f"),
        Color(hex: "#59b41d")
    ]
    
    var body: some View {
        HStack(spacing: 1) {
            ForEach(paletteColors.indices, id: \.self) { index in
                let color = paletteColors[index]
                RoundedRectangle(cornerRadius: 0)
                    .fill(color)
                    .frame(width: 20, height: 20)
                    .onTapGesture {
                        selectedColor = color
                        onColorSelected(color)
                    }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
