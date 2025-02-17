//
//  SceneSelectorView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 28/10/2024.
//

import SwiftUI

struct SceneSelectorView: View {
    @EnvironmentObject var sceneManager: SceneManager
    
    var body: some View {
        VStack {
            Text("Select scene").font(myFont.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
            Divider()
            ForEach(allScenes) { scene in
                HStack {
                    Text(scene.name).font(myFont)
                    Spacer()
                    Button("Select") {
                        print("select scene: \(scene.name)")
                        DispatchQueue.main.async {
                            sceneManager.replaceScene(with: scene)
                            scene.setWrappedGeometries() // Ensure geometries are initialized
                        }
                    }.font(myFont)
                }
            }
            Spacer()
        }.padding(10)
    }
}
