//
//  InputControlView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 05/09/2025.
//

import SwiftUI

struct InputControlView: View {
    let input: SceneInput
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(.init("**\(input.name)**"))
                    .frame(alignment: .leading)
                Spacer()
                Text(.init("_\(input.type)_"))
                    .frame(alignment: .trailing)
            }

            switch input.type {
            case .float:
                HStack { FloatSliderControlView(input: input) }
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .integer:
                HStack { IntegerSliderControlView(input: input) }
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .statefulFloat:
                HStack { StatefulFloatControlView(input: input) }
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .colorInput:
                HStack {
                    ColorPickerControlWrapperView(input: input)
                }
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .string:
                HStack { StringInputControlView(input: input) }
                    .frame(maxWidth: .infinity, alignment: .leading)
            default:
                Text("Default")
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.2))
        .cornerRadius(5)
        .id(input.id)
    }
}
