//
//  GeometrySceneCircle.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 12/10/2024.
//

import Foundation

func generateGeometrySceneCircle() -> GeometriesSceneBase {
    return GeometriesSceneBase(
        name: "Circle Scene",
        inputs: [
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
                       tickValueAudioAdjustmentRange: 0.0...0.1)
            
            // SceneInput(name: "Segments", type: .float, value: 100)
        ],
        geometryGenerators: [
            CircleGenerator()
        ]
    )
}
