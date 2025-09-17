//
//  GeometrySceneLorenz.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 21/06/2025.
//

import Foundation
import SwiftUI

func generateGeometrySceneLorenz() -> GeometriesSceneBase {
    return GeometriesSceneBase(
        name: "Lorenz Attractor Scene",
        inputs: [
            SceneInput(name: "Sigma", type: .float, value: 5.0, range: 0...20),
            SceneInput(name: "Rho", type: .float, value: 26.0, range: 0...40),
            SceneInput(name: "Beta", type: .float, value: 8.0/3.0, range: 0...10),
            SceneInput(name: "Steps", type: .integer, value: 500, range: 0...2000),
            
            SceneInput(name: "DT", type: .float, value: 0.01, range: 0...0.1,
                       audioAmplificationAddition: 0.0,
                       audioAmplificationAdditionRange: 0.0...0.1),
            
            SceneInput(name: "Scale", type: .float, value: 0.05, range: 0...0.1,
                       audioAmplificationAddition: 0.0,
                       audioAmplificationAdditionRange: 0.0...0.1),
            
            
            SceneInput(name: "Translation X", type: .float, value: 0.0, range: -10...10),
            SceneInput(name: "Translation Y", type: .float, value: 0.0, range: -10...10),
            SceneInput(name: "Translation Z", type: .float, value: 0.0, range: -10...10),
            
            SceneInput(name: "Rotation X", type: .float, value: 0.0, range: 0...2 * .pi),
            SceneInput(name: "Rotation Y", type: .float, value: 0.0, range: 0...2 * .pi),
            SceneInput(name: "Rotation Z", type: .float, value: 0.0, range: 0...2 * .pi),
            
            SceneInput(name:"Stateful Rotation X", type: .statefulFloat,
                       tickValueAdjustmentRange: 0.0...0.1,
                       tickValueAudioAdjustmentRange: 0.0...0.1),
            SceneInput(name:"Stateful Rotation Y", type: .statefulFloat,
                       tickValueAdjustmentRange: 0.0...0.1,
                       tickValueAudioAdjustmentRange: 0.0...0.1),
            SceneInput(name:"Stateful Rotation Z", type: .statefulFloat,
                       tickValueAdjustmentRange: 0.0...0.1,
                       tickValueAudioAdjustmentRange: 0.0...0.1),
            
            SceneInput(name: "Line width base", type: .float, inputGroupName: "Shading", value: 0.0, range: 0...20.0,
                       audioAmplificationAddition: 0.0,
                       audioAmplificationAdditionRange: 0.0...20.0),
            
            SceneInput(name: "Line width start", type: .float, inputGroupName: "Shading", value: 0.8, range: 0...20.0,
                       audioAmplificationAddition: 0.0,
                       audioAmplificationAdditionRange: 0.0...20.0),
            
            SceneInput(name: "Line width end", type: .float, inputGroupName: "Shading", value: 0.8, range: 0...20.0,
                       audioAmplificationAddition: 0.0,
                       audioAmplificationAdditionRange: 0.0...20.0),
            
            
            SceneInput(name: "Color start", type: .colorInput, inputGroupName: "Shading", value: Color.white),
            SceneInput(name: "Color end", type: .colorInput, inputGroupName: "Shading", value: Color.white),
            
            
        ],
        geometryGenerators: [
            LorenzGenerator()
        ]
    )
}
