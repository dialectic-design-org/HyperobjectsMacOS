//
//  ColorPickerControlWrapperView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 16/07/2025.
//

import SwiftUI

struct ColorPickerControlWrapperView: View {
    @ObservedObject var input: SceneInput

    // FIX #1: persistent observable owned here
    @StateObject private var userValue = ColorInput()

    var body: some View {
        VStack {
            ColorPickerControlView(colorInput: userValue) { newColor in
                // commit outward only on meaningful change
                if input.value as! Color != newColor {
                    input.value = newColor
                }
            }
        }
        .onAppear {
            userValue.updateFromColor(input.value as! Color) // one-time sync-in
        }
    }
}
