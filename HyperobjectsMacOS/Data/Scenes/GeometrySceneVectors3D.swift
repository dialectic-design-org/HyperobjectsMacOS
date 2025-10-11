//
//  GeometrySceneVectors3D.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 08/10/2025.
//

import Foundation
import SwiftUI

func generateGeometrySceneVectors3D() -> GeometriesSceneBase {
    return GeometriesSceneBase(
        name: "Vectors3D",
        inputs: [
           SceneInput(
            name: "Vectors",
            type: .vectors3d
           )
        ],
        geometryGenerators: [
            RandomVecsGenerator()
        ]
    )
}
