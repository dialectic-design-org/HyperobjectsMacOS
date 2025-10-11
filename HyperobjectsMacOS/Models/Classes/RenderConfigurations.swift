//
//  RenderConfigurations.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 08/02/2025.
//

import Foundation
import SwiftUI

class RenderConfigurations: ObservableObject {
    @Published var pipeline: String = "default"
    
    @Published var renderBoundingBoxes: Bool = false
    
    @Published var freeCameraControl: Bool = false
    
    @Published var renderPoints: Bool = false
    
    @Published var renderSDFLines: Bool = true
    
    @Published var renderLinesOverlay: Bool = false
    
    @Published var showOverlay: Bool = true
    
    @Published var runScriptOnFrameChange: Bool = false
    
    @Published var cameraDistance: Float = 1.7320508075688772
    
    @Published var previousColorVisibility: Float = 0.0
    
    @Published var binVisibility: Float = 0.0
    
    @Published var binGridVisibility: Float = 0.0
    
    @Published var boundingBoxVisibility: Float = 0.0
    
    @Published var lineColorStrength: Float = 1.0
    
    @Published var lineTimeDebugGradientStrength: Float = 0.0
    
    @Published var blendRadius: Float = 0.0;
    
    @Published var blendIntensity: Float = 0.0;
    
    @Published var lineTimeDebugStartGradientColor: ColorInput = ColorInput(initialColor: Color.init(red: 1.0, green: 0.0, blue: 1.0))
    @Published var lineTimeDebugEndGradientColor: ColorInput = ColorInput(initialColor: Color.init(red: 0.0, green: 1.0, blue: 0.0))
    
    @Published var binDepth: Int = 16
    
    @Published var projectionMix: Float = 1.0
    
    @Published var FOVDivision: Float = 3.0
    
    @Published var orthographicProjectionHeight: Float = 2.0
    
    @Published var backgroundColor: ColorInput = ColorInput(initialColor: .black)
    
    
}

