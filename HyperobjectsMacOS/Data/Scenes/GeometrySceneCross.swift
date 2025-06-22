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
            SceneInput(name: "Size", type: .float, value: 0.5, range: 0...2),
            SceneInput(name: "Rotation", type: .float, value: 0.0, range: 0...4 * .pi)
        ],
        geometryGenerators: [
            CrossGenerator()
        ]
    )
}
