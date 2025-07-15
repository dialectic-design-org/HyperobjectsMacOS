//
//  HyperobjectsMacOSApp.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 11/10/2024.
//

import SwiftUI

@main
struct HyperobjectsMacOSApp: App {
    @StateObject private var sceneManager = SceneManager(initialScene: generateGeometrySceneCircle())
    @StateObject private var renderConfigurations = RenderConfigurations()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sceneManager.currentScene)
                .environmentObject(renderConfigurations)
                .onAppear {
                    print("Main content view onappear")
                    sceneManager.currentScene.setWrappedGeometries()
                }
        }
        
        Window("\(windowsManagerWindowConfig.title) (scene: \(sceneManager.currentScene.name))", id: windowsManagerWindowConfig.id) {
            windowsManagerWindowConfig.content.environmentObject(sceneManager.currentScene)
        }
        
        Window("\(secondaryRenderWindowConfig.title) (scene: \(sceneManager.currentScene.name))", id: secondaryRenderWindowConfig.id) {
            secondaryRenderWindowConfig.content.environmentObject(sceneManager.currentScene)
                                               .environmentObject(renderConfigurations)
        }
        
        Window("\(sceneInputsWindowConfig.title) (scene: \(sceneManager.currentScene.name))", id: sceneInputsWindowConfig.id) {
            sceneInputsWindowConfig.content.environmentObject(sceneManager.currentScene)
        }

        Window("\(renderConfigurationsWindowConfig.title) (scene: \(sceneManager.currentScene.name))", id: renderConfigurationsWindowConfig.id) {
            renderConfigurationsWindowConfig.content.environmentObject(sceneManager.currentScene)
                                                    .environmentObject(renderConfigurations)
        }
        
        Window("\(sceneGeometriesListWindowConfig.title) (scene: \(sceneManager.currentScene.name))", id: sceneGeometriesListWindowConfig.id) {
            sceneGeometriesListWindowConfig.content.environmentObject(sceneManager.currentScene)
        }
        
        Window("\(viewportFrontViewWindowConfig.title) (scene: \(sceneManager.currentScene.name))", id: viewportFrontViewWindowConfig.id) {
            viewportFrontViewWindowConfig.content.environmentObject(sceneManager.currentScene)
        }
        
        Window("\(viewportSideViewWindowConfig.title) (scene: \(sceneManager.currentScene.name))", id: viewportSideViewWindowConfig.id) {
            viewportSideViewWindowConfig.content.environmentObject(sceneManager.currentScene)
        }
        
        Window("\(viewportTopViewWindowConfig.title) (scene: \(sceneManager.currentScene.name))", id: viewportTopViewWindowConfig.id) {
            viewportTopViewWindowConfig.content.environmentObject(sceneManager.currentScene)
        }
        
        Window(sceneSelectorViewWindowConfig.title, id: sceneSelectorViewWindowConfig.id) {
            sceneSelectorViewWindowConfig.content.environmentObject(sceneManager)
        }
    }
}
