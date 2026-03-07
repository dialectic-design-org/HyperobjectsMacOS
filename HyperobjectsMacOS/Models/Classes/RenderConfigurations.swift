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

    @Published var showSquareBounds: Bool = false
    
    @Published var runScriptOnFrameChange: Bool = false
    
    @Published var showAudioControls: Bool = false
    
    @Published var cameraDistance: Float = 1.7320508075688772
    
    @Published var previousColorVisibility: Float = 0.0
    
    @Published var binVisibility: Float = 0.0
    
    @Published var binGridVisibility: Float = 0.0
    
    @Published var boundingBoxVisibility: Float = 0.0
    
    @Published var lineColorStrength: Float = 1.0
    
    @Published var lineTimeDebugGradientStrength: Float = 0.0
    
    @Published var blendRadius: Float = 0.0;

    @Published var blendIntensity: Float = 0.0;

    // Chromatic Aberration
    @Published var chromaticAberrationEnabled: Bool = false
    @Published var chromaticAberrationIntensity: Float = 0.5
    @Published var chromaticAberrationRedOffset: Float = -2.0
    @Published var chromaticAberrationGreenOffset: Float = 0.0
    @Published var chromaticAberrationBlueOffset: Float = 2.0
    @Published var chromaticAberrationRadialPower: Float = 2.0
    @Published var chromaticAberrationUseRadialMode: Bool = true
    @Published var chromaticAberrationAngle: Float = 0.0  // Radians, for uniform mode
    @Published var chromaticAberrationUseSpectralMode: Bool = true  // Physically-based spectral dispersion
    @Published var chromaticAberrationDispersionStrength: Float = 5.0  // Pixels at 400nm
    @Published var chromaticAberrationReferenceWavelength: Float = 550.0  // nm, no shift at this wavelength
    
    @Published var lineTimeDebugStartGradientColor: ColorInput = ColorInput(initialColor: Color.init(red: 1.0, green: 0.0, blue: 1.0))
    @Published var lineTimeDebugEndGradientColor: ColorInput = ColorInput(initialColor: Color.init(red: 0.0, green: 1.0, blue: 0.0))
    
    @Published var binDepth: Int = 16
    
    @Published var projectionMix: Float = 1.0
    
    @Published var FOVDivision: Float = 3.0
    
    @Published var orthographicProjectionHeight: Float = 2.0
    
    @Published var backgroundColor: ColorInput = ColorInput(initialColor: .black)


}

/// Context passed to override closures
struct RenderOverrideContext {
    let frameStamp: Int
    let audioSignal: Float
    let audioSignalProcessed: Double
    let inputs: [String: Any]
}

/// Optional overrides for render configuration properties.
/// nil = use UI value, non-nil = override
struct RenderConfigurationOverrides {
    // Chromatic Aberration
    var chromaticAberrationEnabled: Bool?
    var chromaticAberrationIntensity: Float?
    var chromaticAberrationRedOffset: Float?
    var chromaticAberrationGreenOffset: Float?
    var chromaticAberrationBlueOffset: Float?
    var chromaticAberrationRadialPower: Float?
    var chromaticAberrationUseRadialMode: Bool?
    var chromaticAberrationAngle: Float?
    var chromaticAberrationUseSpectralMode: Bool?
    var chromaticAberrationDispersionStrength: Float?
    var chromaticAberrationReferenceWavelength: Float?

    // Background & Blending
    var backgroundColor: SIMD3<Float>?  // Use SIMD for thread safety
    var blendRadius: Float?
    var blendIntensity: Float?
    var previousColorVisibility: Float?
    var lineColorStrength: Float?

    static let none = RenderConfigurationOverrides()

    /// Merges with another, preferring values from `other` when non-nil
    func merged(with other: RenderConfigurationOverrides) -> RenderConfigurationOverrides {
        var result = self
        result.chromaticAberrationEnabled = other.chromaticAberrationEnabled ?? self.chromaticAberrationEnabled
        result.chromaticAberrationIntensity = other.chromaticAberrationIntensity ?? self.chromaticAberrationIntensity
        result.chromaticAberrationRedOffset = other.chromaticAberrationRedOffset ?? self.chromaticAberrationRedOffset
        result.chromaticAberrationGreenOffset = other.chromaticAberrationGreenOffset ?? self.chromaticAberrationGreenOffset
        result.chromaticAberrationBlueOffset = other.chromaticAberrationBlueOffset ?? self.chromaticAberrationBlueOffset
        result.chromaticAberrationRadialPower = other.chromaticAberrationRadialPower ?? self.chromaticAberrationRadialPower
        result.chromaticAberrationUseRadialMode = other.chromaticAberrationUseRadialMode ?? self.chromaticAberrationUseRadialMode
        result.chromaticAberrationAngle = other.chromaticAberrationAngle ?? self.chromaticAberrationAngle
        result.chromaticAberrationUseSpectralMode = other.chromaticAberrationUseSpectralMode ?? self.chromaticAberrationUseSpectralMode
        result.chromaticAberrationDispersionStrength = other.chromaticAberrationDispersionStrength ?? self.chromaticAberrationDispersionStrength
        result.chromaticAberrationReferenceWavelength = other.chromaticAberrationReferenceWavelength ?? self.chromaticAberrationReferenceWavelength
        result.backgroundColor = other.backgroundColor ?? self.backgroundColor
        result.blendRadius = other.blendRadius ?? self.blendRadius
        result.blendIntensity = other.blendIntensity ?? self.blendIntensity
        result.previousColorVisibility = other.previousColorVisibility ?? self.previousColorVisibility
        result.lineColorStrength = other.lineColorStrength ?? self.lineColorStrength
        return result
    }
}
