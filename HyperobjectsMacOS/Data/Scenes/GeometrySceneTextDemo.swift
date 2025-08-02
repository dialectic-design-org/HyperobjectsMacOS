//
//  GeometrySceneTextDemo.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 02/08/2025.
//


import Foundation
import SwiftUI

func generateGeometrySceneTextDemo() -> GeometriesSceneBase {
    return GeometriesSceneBase(
        name: "Text Demo Scene",
        inputs: [
            SceneInput(name: "Start color", type: .colorInput, value: Color.white),
            SceneInput(name: "End color", type: .colorInput, value: Color.white),
            
            SceneInput(name: "Spacing", type: .float,
                       value: 0.0,
                       range: 0...2,
                       audioAmplificationMultiplicationRange: 0...5
                      ),
            
            SceneInput(name: "Replacement probability", type: .float,
                       value: 0.02,
                       range: 0...1,
                       audioAmplificationMultiplicationRange: 0...1
                      ),
            
            SceneInput(name: "Restore probability", type: .float,
                       value: 0.1,
                       range: 0...1,
                       audioAmplificationMultiplicationRange: 0...1
                      )
        ],
        geometryGenerators: [
            TextDemoGenerator()
        ]
    )
}
