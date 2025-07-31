//
//  GeometrySceneColorScalesDemo.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 31/07/2025.
//

import Foundation
import SwiftUI

func generateColorScalesGemoScene() -> GeometriesSceneBase {
    return GeometriesSceneBase(
        name: "Color Scales Demo",
        inputs: [
            SceneInput(name: "Color start", type: .colorInput, value: Color.white),
            SceneInput(name: "Color end", type: .colorInput, value: Color.blue),
            SceneInput(name: "Brightness", type: .float,
                       value: 1.0,
                       range: 0...10,
                       audioAmplificationMultiplicationRange: 0...5
                      ),
            SceneInput(name: "Saturation", type: .float,
                       value: 1.0,
                       range: 0...10,
                       audioAmplificationMultiplicationRange: 0...5
                      ),
            SceneInput(name: "Rotation", type: .statefulFloat,
                       value: 0.0,
                       range: 0...2,
                       audioAmplificationMultiplicationRange: 0...5
                      ),
        ],
        geometryGenerators: [
            ColorScalesDemoGenerator()
        ]
    )
}
