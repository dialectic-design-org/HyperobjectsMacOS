//
//  SliderControlView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 18/03/2025.
//

import SwiftUI


struct SliderControlView: View {
    var input: SceneInput
    @EnvironmentObject var currentScene: GeometriesSceneBase
    
    var body: some View {
        let floatValue = input.valueAsFloat()
        Slider(value: Binding(
            get: { floatValue },
            set: { newValue in
                if let index = currentScene.inputs.firstIndex(where: { $0.id == input.id }) {
                    currentScene.inputs[index].value = newValue // Update the value in the array
                }
                currentScene.setChangedInput(name: input.name)
                currentScene.setWrappedGeometries()
            }
        ), in: input.range)
    }
}
