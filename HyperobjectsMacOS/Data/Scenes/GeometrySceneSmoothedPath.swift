//
//  GeometrySceneSmoothedPath.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 02/08/2025.
//

import Foundation
import SwiftUI

func generateGeometrySceneSmoothedPath() -> GeometriesSceneBase {
    return GeometriesSceneBase(
        name: "Smoothed Path Scene",
        inputs: [
            SceneInput(name: "Length", type: .integer,
                       value: 20,
                       range: 0...100
                      ),
            SceneInput(name:"Tolerance", type: .float, tickValueAdjustmentRange: 0.0...0.4),
            SceneInput(name:"Stateful Rotation X", type: .statefulFloat, tickValueAdjustmentRange: 0.0...0.1),
            SceneInput(name:"Stateful Rotation Y", type: .statefulFloat, tickValueAdjustmentRange: 0.0...0.1),
            SceneInput(name:"Stateful Rotation Z", type: .statefulFloat, tickValueAdjustmentRange: 0.0...0.1)
        ],
        geometryGenerators: [
            SmoothedPathGenerator()
        ]
    )
}
