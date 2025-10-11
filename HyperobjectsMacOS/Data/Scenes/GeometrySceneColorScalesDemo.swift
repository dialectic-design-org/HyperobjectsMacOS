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
            
            SceneInput(name: "Length", type: .float,
                       value: 1.0,
                       range: 0...10,
                       audioAmplificationMultiplicationRange: 0...5
                      ),
            
            SceneInput(name: "History delay (ms)", type: .float,
                       value: 0.0,
                       range: 0...100,
                       audioAmplificationMultiplicationRange: 0...5
                      ),
            
            SceneInput(name: "Rotation X", type: .float, value: 0.0, range: 0.0...2 * .pi),
            SceneInput(name: "Rotation Y", type: .float, value: 0.0, range: 0.0...2 * .pi),
            SceneInput(name: "Rotation Z", type: .float, value: 0.0, range: 0.0...2 * .pi),
            
            SceneInput(name:"Stateful Rotation X", type: .statefulFloat, tickValueAdjustmentRange: 0.0...0.1),
            SceneInput(name:"Stateful Rotation Y", type: .statefulFloat, tickValueAdjustmentRange: 0.0...0.1),
            SceneInput(name:"Stateful Rotation Z", type: .statefulFloat, tickValueAdjustmentRange: 0.0...0.1)
        ],
        geometryGenerators: [
            ColorScalesDemoGenerator()
        ]
    )
}
