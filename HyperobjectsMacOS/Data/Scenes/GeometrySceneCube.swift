//
//  GeometrySceneCube.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 06/11/2024.
//

import Foundation

func generateGeometrySceneCube() -> GeometriesSceneBase {
    return GeometriesSceneBase(
        name: "Cube Scene",
        inputs: [
            SceneInput(name: "Size", type: .float, value: 0.5, range: 0.0...2.0),
            SceneInput(name: "Width", type: .float, value: 0.5, range: 0.0...3.0),
            SceneInput(name: "Height", type: .float, value: 0.5, range: 0.0...3.0),
            SceneInput(name: "Depth", type: .float, value: 0.5, range: 0.0...3.0),
            
            
            SceneInput(name: "Rotation X", type: .float, value: 0.0, range: 0.0...2 * .pi),
            SceneInput(name: "Rotation Y", type: .float, value: 0.0, range: 0.0...2 * .pi),
            SceneInput(name: "Rotation Z", type: .float, value: 0.0, range: 0.0...2 * .pi),
        ],
        geometryGenerators: [
            CubeGenerator()
        ]
    )
}
