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
            SceneInput(name: "Size", type: .float, value: 20.0),
            SceneInput(name: "Rotation", type: .float, value: 0.0)
        ],
        geometryGenerators: [
            CubeGenerator()
        ]
    )
}
