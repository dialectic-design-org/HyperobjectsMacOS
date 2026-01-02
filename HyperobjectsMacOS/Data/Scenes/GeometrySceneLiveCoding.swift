//
//  GeometrySceneLiveCoding.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 23/11/2025.
//

import Foundation
import SwiftUI

func generateGeometrySceneLiveCoding() -> GeometriesSceneBase {
    return GeometriesSceneBase(
        name: "Live Coding Scene",
        inputs: [
            SceneInput(name: "Lines", type: .lines, value: [Line(
                startPoint: SIMD3<Float>(-1.0, 0.0, 0.0),
                endPoint: SIMD3<Float>(1.0, 0.0, 0.0)
            )]),
            
            SceneInput(name: "Message", type: .string)
        ],
        inputGroups: [
        ],
        geometryGenerators: [
            LiveCodingGenerator()
        ]
    )
}
