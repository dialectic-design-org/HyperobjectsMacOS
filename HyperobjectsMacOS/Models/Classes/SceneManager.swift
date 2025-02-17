//
//  SceneManager.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 30/10/2024.
//

import Foundation

class SceneManager: ObservableObject {
    @Published var currentScene: GeometriesSceneBase
    init(initialScene: GeometriesSceneBase) {
        self.currentScene = initialScene
    }
    
    func replaceScene(with newScene: GeometriesSceneBase) {
        self.currentScene = newScene
    }
}
