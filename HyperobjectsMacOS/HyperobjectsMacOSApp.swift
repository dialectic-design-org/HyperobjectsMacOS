//
//  HyperobjectsMacOSApp.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 11/10/2024.
//

import SwiftUI

@main
struct HyperobjectsMacOSApp: App {
    @StateObject private var currentScene = generateGeometrySceneCircle()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(currentScene)
        }
        
        Window(renderWindowConfig.title, id: renderWindowConfig.id) {
            renderWindowConfig.content.environmentObject(currentScene)
        }
        
        Window(sceneInputsWindowConfig.title, id: sceneInputsWindowConfig.id) {
            sceneInputsWindowConfig.content.environmentObject(currentScene)
        }
    }
}
