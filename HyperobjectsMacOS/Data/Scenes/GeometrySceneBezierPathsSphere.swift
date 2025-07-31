//
//  GeometrySceneBezierPathsSphere.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 30/07/2025.
//

import Foundation
import SwiftUI

func geenrateGeometrySceneBezierPathsSphere() -> GeometriesSceneBase {
    return GeometriesSceneBase(
        name: "Bezier Paths Sphere",
        inputs: [
            SceneInput(name: "Segments", type: .integer, value: 16, range: 3...64),
            SceneInput(name: "Circles", type: .integer, value: 1, range: 1...32),
            SceneInput(name: "Initial Radius", type: .float, value: 1),
            SceneInput(name: "Additional Radius", type: .float, value: 0)
        ],
        geometryGenerators: [
            BezierPathsSphereGenerator()
        ]
    )
}
