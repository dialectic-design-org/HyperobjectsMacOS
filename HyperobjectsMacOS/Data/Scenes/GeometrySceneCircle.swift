//
//  GeometrySceneCircle.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 12/10/2024.
//

import Foundation
import SwiftUI

func generateGeometrySceneCircle() -> GeometriesSceneBase {
    return GeometriesSceneBase(
        name: "Circle Scene",
        inputs: [
            

            SceneInput(name: "Segments count", type: .integer,
                       value: 256,
                       range: 0...512,
                      ),
            SceneInput(name: "Radius", type: .float,
                       value: 0.5,
                       range: 0...2,
                       audioAmplificationMultiplicationRange: 0...5
                      ),
            
            SceneInput(name:"Stateful Rotation X", type: .statefulFloat,
                       tickValueAdjustmentRange: 0.0...0.1,
                       tickValueAudioAdjustmentRange: 0.0...0.1),
            SceneInput(name:"Stateful Rotation Y", type: .statefulFloat,
                       tickValueAdjustmentRange: 0.0...0.1,
                       tickValueAudioAdjustmentRange: 0.0...0.1),
            SceneInput(name:"Stateful Rotation Z", type: .statefulFloat,
                       tickValueAdjustmentRange: 0.0...0.1,
                       tickValueAudioAdjustmentRange: 0.0...0.1),
            
            
            SceneInput(name: "Line Width Base", type: .float, inputGroupName: "Path", value: 1.0, range: 0...100),
            SceneInput(name: "Line Width Wave Amplification", type: .float, inputGroupName: "Path", value: 0.0, range: 0...100),
            SceneInput(name: "Line Width Wave Frequency", type: .float, inputGroupName: "Path", value: 0.0, range: 0...64),
            SceneInput(name: "Line Width Wave Frequency Shift", type: .float, inputGroupName: "Path", value: 0.0, range: 0...4 * .pi),
            SceneInput(name: "StartColor", type: .colorInput, inputGroupName: "Shading", value: Color.white),
            SceneInput(name: "EndColor", type: .colorInput, inputGroupName: "Shading", value: Color.white)
            
            
            // SceneInput(name: "Segments", type: .float, value: 100)
        ],
        inputGroups: [
            SceneInputGroup(name: "Path"),
            SceneInputGroup(name: "Shading")
        ],
        geometryGenerators: [
            CircleGenerator()
        ]
    )
}
