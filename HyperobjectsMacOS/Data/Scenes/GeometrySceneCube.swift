//
//  GeometrySceneCube.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 06/11/2024.
//

import Foundation

func generateGeometrySceneCube() -> GeometriesSceneBase {
    return GeometriesSceneBase(
        name: "Cube Scene",
        inputs: [
            SceneInput(name: "LineWidth", type: .float, value: 1.0, range: 0.0...40.0),
            
            SceneInput(name: "Size", type: .float, value: 0.5, range: 0.0...2.0),
            SceneInput(name: "Width", type: .float, value: 0.5, range: 0.0...3.0),
            SceneInput(name: "Height", type: .float, value: 0.5, range: 0.0...3.0),
            SceneInput(name: "Depth", type: .float, value: 0.5, range: 0.0...3.0),
            
            SceneInput(name:"Stateful Width", type: .statefulFloat),
            SceneInput(name:"Stateful Height", type: .statefulFloat),
            SceneInput(name:"Stateful Depth", type: .statefulFloat),
            
            
            SceneInput(name: "Rotation X", type: .float, value: 0.0, range: 0.0...2 * .pi),
            SceneInput(name: "Rotation Y", type: .float, value: 0.0, range: 0.0...2 * .pi),
            SceneInput(name: "Rotation Z", type: .float, value: 0.0, range: 0.0...2 * .pi),
            
            SceneInput(name:"Stateful Rotation X", type: .statefulFloat, tickValueAdjustmentRange: 0.0...0.1),
            SceneInput(name:"Stateful Rotation Y", type: .statefulFloat, tickValueAdjustmentRange: 0.0...0.1),
            SceneInput(name:"Stateful Rotation Z", type: .statefulFloat, tickValueAdjustmentRange: 0.0...0.1)
        ],
        geometryGenerators: [
            CubeGenerator()
        ]
    )
}
