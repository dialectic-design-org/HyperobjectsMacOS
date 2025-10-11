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
            SceneInput(name:"Line Width Start", type: .float, value: 25.0, range: 0.0...200.0),
            SceneInput(name:"Line Width End", type: .float, value: 25.0, range: 0.0...200.0),
            
            SceneInput(name:"Points Reset Chance", type: .float, value: 0.0, range: 0.0...1.0),
            SceneInput(name: "Color start", type: .colorInput, inputGroupName: "Shading", value: Color.red),
            SceneInput(name: "Color end", type: .colorInput, inputGroupName: "Shading", value: Color.blue),
            SceneInput(name:"Stateful Rotation X", type: .statefulFloat, inputGroupName: "Rotation", tickValueAdjustmentRange: 0.0...0.1),
            SceneInput(name:"Stateful Rotation Y", type: .statefulFloat, inputGroupName: "Rotation", tickValueAdjustmentRange: 0.0...0.1),
            SceneInput(name:"Stateful Rotation Z", type: .statefulFloat, inputGroupName: "Rotation", tickValueAdjustmentRange: 0.0...0.1)
        ],
        geometryGenerators: [
            SmoothedPathGenerator()
        ]
    )
}
