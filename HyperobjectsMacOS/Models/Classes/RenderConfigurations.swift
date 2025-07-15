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
    
    @Published var renderPoints: Bool = false
    
    @Published var renderSDFLines: Bool = true
    
    @Published var renderLinesOverlay: Bool = false
    
    @Published var showOverlay: Bool = true
    
    @Published var cameraDistance: Float = 5.0
}

