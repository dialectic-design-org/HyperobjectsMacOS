//
//  GeometrySceneThreeBody.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 23/09/2025.
//

import Foundation
import SwiftUI

func generateGeometrySceneThreeBody() -> GeometriesSceneBase {
    return GeometriesSceneBase(
        name: "Three Body Problem",
        inputs: [
            SceneInput(name: "Trail length", type: .float, value: 10.0)
        ],
        geometryGenerators: [
            ThreeBodyGenerator()
        ]
    )
}
