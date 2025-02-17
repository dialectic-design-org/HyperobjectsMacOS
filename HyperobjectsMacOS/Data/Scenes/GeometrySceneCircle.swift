//
//  GeometrySceneCircle.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 12/10/2024.
//

import Foundation

func generateGeometrySceneCircle() -> GeometriesSceneBase {
    return GeometriesSceneBase(
        name: "Circle Scene",
        inputs: [
            SceneInput(name: "Radius", type: .float, value: 100),
            SceneInput(name: "Segments", type: .float, value: 100)
        ],
        geometryGenerators: [
            CircleGenerator()
        ]
    )
}
