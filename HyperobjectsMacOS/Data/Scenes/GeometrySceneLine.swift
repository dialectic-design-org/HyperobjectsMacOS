//
//  GeometrySceneLine.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 16/07/2025.
//

import Foundation
import SwiftUI

func generateGeometrySceneLine() -> GeometriesSceneBase {
    return GeometriesSceneBase(
        name: "Line Scene",
        inputs: [
            SceneInput(name: "Length", type: .float,
                       value: 2.5,
                       range: 0...5,
                       audioAmplificationMultiplicationRange: 0...5
                      ),
            
            SceneInput(name: "Rotation", type: .statefulFloat,
                       value: 0.0,
                       range: 0...2,
                       audioAmplificationMultiplicationRange: 0...5
                      ),
            
            SceneInput(name: "Start line width", type: .float, value: 50.0, range: 0...800),
            SceneInput(name: "End line width", type: .float, value: 50.0, range: 0...800),
            SceneInput(name: "Start color inner", type: .colorInput, value: Color.white),
            SceneInput(name: "Start color outer left", type: .colorInput, value: Color.blue),
            SceneInput(name: "Start color outer right", type: .colorInput, value: Color.red),
            
            SceneInput(name: "Start sigmoid steepness", type: .float, value: 5.0, range: 0...1000.0),
            SceneInput(name: "Start sigmoid midpoint", type: .float, value: 0.5, range: 0...1),
            
            SceneInput(name: "End color inner", type: .colorInput, value: Color.white),
            SceneInput(name: "End color outer left", type: .colorInput, value: Color.blue),
            SceneInput(name: "End color outer right", type: .colorInput, value: Color.red),
            SceneInput(name: "End sigmoid steepness", type: .float, value: 5.0, range: 0...1000.0),
            SceneInput(name: "End sigmoid midpoint", type: .float, value: 0.5, range: 0...1),
        ],
        geometryGenerators: [
            LineGenerator()
        ]
    )
}
