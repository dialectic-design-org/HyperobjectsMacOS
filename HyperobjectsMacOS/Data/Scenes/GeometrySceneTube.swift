//
//  GeometrySceneTube.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 08/07/2025.
//

import Foundation
import SwiftUI

func generateGeometrySceneTube() -> GeometriesSceneBase {
    return GeometriesSceneBase(
        name: "Tube",
        inputs: [
           
        ],
        geometryGenerators: [
            TubeGenerator()
        ]
    )
}
