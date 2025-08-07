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
            SceneInput(name: "Points count", type: .integer,
                       value: 20,
                       range: 0...500
                      ),
            SceneInput(name:"Tolerance", type: .float, value: 0.5, range: 0.0...5.0),
            SceneInput(name: "Color start", type: .colorInput, value: Color.red),
            SceneInput(name: "Color end", type: .colorInput, value: Color.blue),
            SceneInput(name:"Stateful Rotation X", type: .statefulFloat, tickValueAdjustmentRange: 0.0...0.1),
            SceneInput(name:"Stateful Rotation Y", type: .statefulFloat, tickValueAdjustmentRange: 0.0...0.1),
            SceneInput(name:"Stateful Rotation Z", type: .statefulFloat, tickValueAdjustmentRange: 0.0...0.1)
        ],
        geometryGenerators: [
            SmoothedPathGenerator()
        ]
    )
}
