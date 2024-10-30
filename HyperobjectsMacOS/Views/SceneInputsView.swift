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
        }.font(myFont)
    }
}
