//
//  ColorPickerControlWrapperView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 16/07/2025.
//

import SwiftUI

struct ColorPickerControlWrapperView: View {
    @ObservedObject var input: SceneInput
    
    // Local state mirrors
    @State private var userValue: ColorInput = ColorInput()
    
    var body: some View {
        VStack {
            ColorPickerControlView(colorInput: userValue) { newColor in
                input.value = newColor
            }
        }
    }
}
