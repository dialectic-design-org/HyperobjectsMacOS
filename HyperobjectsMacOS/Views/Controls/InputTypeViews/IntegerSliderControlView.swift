//
//  IntegerSliderControlView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 30/07/2025.
//

import SwiftUI

struct IntegerSliderControlView: View {
    @ObservedObject var input: SceneInput
    
    @State private var userValue: Double = 0.0
    @State private var add: Float = 0.0
    @State private var mul: Float = 1.0
    @State private var offset: Float = 0.0
    
    var body: some View {
        VStack {
            HStack {
                Text("\(input.value)")
                Slider(value: $userValue,
                       in: Double(input.range.lowerBound)...Double(input.range.upperBound),
                       step: 1.0
                ).onChange(of: userValue) { oldValue, newValue in
                    input.value = Int(newValue)
                }
            }
        }
    }
}
