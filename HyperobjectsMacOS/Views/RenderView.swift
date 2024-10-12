//
//  RenderView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 12/10/2024.
//

import SwiftUI

struct RenderView: View {
    @EnvironmentObject var currentScene: GeometriesSceneBase
    var body: some View {
        VStack {
            Text("Current scene:")
            Text("\(currentScene.name)")
        }
    }
}
