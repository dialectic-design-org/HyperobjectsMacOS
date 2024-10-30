//
//  GeometrySceneCross.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 28/10/2024.
//

import Foundation

func generateGeometrySceneCross() -> GeometriesSceneBase {
    return GeometriesSceneBase(
        name: "Cross Scene",
        inputs: [
            SceneInput(name: "Size", value: 20.0),
            SceneInput(name: "Rotation", value: 0.0)
        ],
        geometryGenerators: [
            CrossGenerator()
        ]
    )
}
