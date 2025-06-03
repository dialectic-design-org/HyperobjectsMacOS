//
//  RenderConfigurations.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 08/02/2025.
//

import Foundation

class RenderConfigurations: ObservableObject {
    @Published var pipeline: String = "default"
    
    @Published var renderBoundingBoxes: Bool = false
    
    @Published var freeCameraControl: Bool = false
}

