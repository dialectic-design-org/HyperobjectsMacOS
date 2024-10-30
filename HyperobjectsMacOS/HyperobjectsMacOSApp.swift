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
                .onAppear {
                    print("Content view appeared")
                    currentScene.setWrappedGeometries()
                }
        }
        
        Window(renderWindowConfig.title, id: renderWindowConfig.id) {
            renderWindowConfig.content.environmentObject(currentScene)
        }
        
        Window(sceneInputsWindowConfig.title, id: sceneInputsWindowConfig.id) {
            sceneInputsWindowConfig.content.environmentObject(currentScene)
        }
        
        Window(sceneGeometriesListWindowConfig.title, id: sceneGeometriesListWindowConfig.id) {
            sceneGeometriesListWindowConfig.content.environmentObject(currentScene)
        }
        
        Window(viewportFrontViewWindowConfig.title, id: viewportFrontViewWindowConfig.id) {
            viewportFrontViewWindowConfig.content.environmentObject(currentScene)
        }
        
        Window(sceneSelectorViewWindowConfig.title, id: sceneSelectorViewWindowConfig.id) {
            sceneSelectorViewWindowConfig.content.environmentObject(currentScene)
        }
    }
}
