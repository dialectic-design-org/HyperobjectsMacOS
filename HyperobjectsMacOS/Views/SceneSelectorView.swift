//
//  SceneSelectorView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 28/10/2024.
//

import SwiftUI

struct SceneSelectorView: View {
    @EnvironmentObject var currentScene: GeometriesSceneBase
    
    var body: some View {
        VStack {
            Text("Select scene")
            ForEach(allScenes) { scene in
                HStack {
                    Text(scene.name)
                    Button("Select") {
                    }
                }
                
            }
        }
    }
}
