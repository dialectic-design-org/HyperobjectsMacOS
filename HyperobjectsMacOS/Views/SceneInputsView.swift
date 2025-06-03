//
//  SceneInputsView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 12/10/2024.
//

import SwiftUI

struct SceneInputsView: View {
    @EnvironmentObject var currentScene: GeometriesSceneBase
    var body: some View {
        VStack {
            Text("Scene inputs view")
            Text("Scene: \(currentScene.name)")
            Text("Inputs count: \(currentScene.inputs.count)")
            Text("TODO IMPLEMENT")
            List(currentScene.inputs) { input in
                Text("\(input.name) (value: \(input.value))")
                switch input.type {
                case .float:
                    let floatValue = (input.value as? Double) ?? 0.0 // Force input.value to be a Double, defaulting to 0.0 if not
                    HStack {
                        Text("Float")
//                        Slider(value: Binding(
//                            get: { floatValue },
//                            set: { newValue in
//                                print("newValue: \(newValue)")
//                                if let index = currentScene.inputs.firstIndex(where: { $0.id == input.id }) {
//                                    currentScene.inputs[index].value = newValue // Update the value in the array
//                                }
//                            }
//                        ), in: 0...100)
                        SliderControlView()
                    }
                default:
                    Text("Default")
                }
            }
        }.font(myFont)
    }
}
