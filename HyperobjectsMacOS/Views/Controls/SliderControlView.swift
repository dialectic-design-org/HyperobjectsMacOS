//
//  SliderControlView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 18/03/2025.
//

import SwiftUI


struct SliderControlView: View {
    var body: some View {
        Text("SliderControlView")
        Slider(value: .constant(0.5))
    }
}
