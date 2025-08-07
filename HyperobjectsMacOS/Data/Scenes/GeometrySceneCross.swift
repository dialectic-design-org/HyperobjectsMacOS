//
//  GeometrySceneCross.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 28/10/2024.
//

import Foundation
import SwiftUI

func generateGeometrySceneCross() -> GeometriesSceneBase {
    return GeometriesSceneBase(
        name: "Cross Scene",
        inputs: [
            SceneInput(name: "Size", type: .float, value: 0.5, range: 0...2),
            SceneInput(name: "Rotation", type: .float, value: 0.0, range: 0...4 * .pi),
            SceneInput(name: "Line spacing", type: .float, value: 0.0, range: -2...2),
            SceneInput(name: "Line width", type: .float, value: 0.8, range: 0...30),
            SceneInput(name: "Rotation Y", type: .statefulFloat, value: 0.0, range: -1...1),
            SceneInput(name: "Line alpha multiplier", type: .float, value: 0.9, range: 0...1),
            SceneInput(name: "Color A", type: .colorInput, value: Color.white),
            SceneInput(name: "Color B", type: .colorInput, value: Color.white),
        ],
        geometryGenerators: [
            CrossGenerator()
        ]
    )
}
