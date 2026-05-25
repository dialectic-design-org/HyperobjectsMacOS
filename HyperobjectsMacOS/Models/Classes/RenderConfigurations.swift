//
//  RenderConfigurations.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 08/02/2025.
//

import Foundation
import SwiftUI

enum GeometryTriggerMode: Equatable {
    case onRenderRequest        // existing: render thread drives the queue
    case fixedClock(hz: Double) // independent DispatchSourceTimer on the geometry queue
    case onInputChange          // only when refreshSceneInputSnapshot is called
}

class RenderConfigurations: ObservableObject {
    @Published var pipeline: String = "default"

    @Published var geometryTriggerMode: GeometryTriggerMode = .onRenderRequest
    
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

    @Published var bandFieldDisplacementEnabled: Bool = true
    @Published var bandFieldExtraBinOverlapPx: Float = 0.0


}

enum BandFieldPreviewMode: String, CaseIterable, Identifiable {
    case rawRGB = "Raw RGB"
    case displacement = "Displacement"

    var id: String { rawValue }
}

struct BandFieldBand {
    var center: Float
    var halfWidth: Float
    var featherW: Float
    var centerL: Float
    var halfLength: Float
    var featherL: Float
    var alpha: Float
    var colorStart: SIMD4<Float>
    var colorEnd: SIMD4<Float>
    var gradMode: UInt32
}

struct BandFieldLayer {
    var axis: UInt32
    var blendMode: UInt32
    var opacity: Float
    var bands: [BandFieldBand]
}

struct BandFieldState {
    var enabled: Bool = false
    var xAmplitudePx: Float = 0
    var yAmplitudePx: Float = 0
    var layers: [BandFieldLayer] = []

    var maxOffsetPx: Float {
        enabled ? max(abs(xAmplitudePx), abs(yAmplitudePx)) : 0
    }
}

struct ShaderBandFieldBand {
    var center: Float
    var halfWidth: Float
    var featherW: Float
    var centerL: Float
    var halfLength: Float
    var featherL: Float
    var alpha: Float
    var colorStart: SIMD4<Float>
    var colorEnd: SIMD4<Float>
    var axis: UInt32
    var gradMode: UInt32
    var _padding0: UInt32 = 0
    var _padding1: UInt32 = 0
}

struct BandFieldUniforms {
    var bandCount: UInt32 = 0
    var enabled: UInt32 = 0
    var xAmplitudePx: Float = 0
    var yAmplitudePx: Float = 0
    var previewMode: UInt32 = 0
    var _padding0: UInt32 = 0
    var _padding1: UInt32 = 0
    var _padding2: UInt32 = 0
}

final class BandFieldManager: ObservableObject {
    @Published private(set) var state = BandFieldState()
    @Published var previewMode: BandFieldPreviewMode = .rawRGB
    @Published private(set) var warningMessage: String?

    let maxBands = 256

    func apply(_ value: StateValue) {
        do {
            state = try Self.parse(value, maxBands: maxBands)
            warningMessage = nil
        } catch {
            state = BandFieldState()
            warningMessage = "Invalid bands output: \(error)"
        }
    }

    func disable() {
        state = BandFieldState()
        warningMessage = nil
    }

    func shaderBands() -> [ShaderBandFieldBand] {
        var output: [ShaderBandFieldBand] = []
        output.reserveCapacity(min(maxBands, state.layers.reduce(0) { $0 + $1.bands.count }))
        for layer in state.layers {
            for band in layer.bands {
                guard output.count < maxBands else { return output }
                output.append(ShaderBandFieldBand(
                    center: band.center,
                    halfWidth: band.halfWidth,
                    featherW: band.featherW,
                    centerL: band.centerL,
                    halfLength: band.halfLength,
                    featherL: band.featherL,
                    alpha: band.alpha * layer.opacity,
                    colorStart: band.colorStart,
                    colorEnd: band.colorEnd,
                    axis: layer.axis,
                    gradMode: band.gradMode
                ))
            }
        }
        return output
    }

    func uniforms(previewMode: BandFieldPreviewMode? = nil) -> BandFieldUniforms {
        let mode = previewMode ?? self.previewMode
        return BandFieldUniforms(
            bandCount: UInt32(shaderBands().count),
            enabled: state.enabled ? 1 : 0,
            xAmplitudePx: state.xAmplitudePx,
            yAmplitudePx: state.yAmplitudePx,
            previewMode: mode == .rawRGB ? 0 : 1
        )
    }

    func samplePreviewColor(x: Double, y: Double, mode: BandFieldPreviewMode) -> Color {
        guard state.enabled else { return Color.black.opacity(0.2) }
        let ndc = SIMD2<Float>(Float(x) * 2 - 1, 1 - Float(y) * 2)
        var premul = SIMD4<Float>(0, 0, 0, 0)
        for layer in state.layers {
            var layerColor = SIMD4<Float>(0, 0, 0, 0)
            for band in layer.bands {
                let c = Self.evaluate(band, layerAxis: layer.axis, ndc: ndc)
                layerColor = c + layerColor * (1 - c.w)
            }
            layerColor *= layer.opacity
            premul = layerColor + premul * (1 - layerColor.w)
        }
        if mode == .displacement {
            let dx = (premul.x - 0.5) * state.xAmplitudePx
            let dy = (premul.y - 0.5) * state.yAmplitudePx
            let scale = max(state.maxOffsetPx, 1)
            return Color(red: Double(0.5 + dx / (2 * scale)), green: Double(0.5 + dy / (2 * scale)), blue: Double(premul.z))
        }
        return Color(red: Double(min(max(premul.x, 0), 1)), green: Double(min(max(premul.y, 0), 1)), blue: Double(min(max(premul.z, 0), 1)), opacity: 1)
    }

    private static func evaluate(_ band: BandFieldBand, layerAxis: UInt32, ndc: SIMD2<Float>) -> SIMD4<Float> {
        let vertical = layerAxis == 0
        let across = vertical ? ndc.x : ndc.y
        let along = vertical ? ndc.y : ndc.x
        let covA = boxCoverage(across, center: band.center, half: band.halfWidth, aa: band.featherW)
        let covL = boxCoverage(along, center: band.centerL, half: band.halfLength, aa: band.featherL)
        let cov = covA * covL
        guard cov > 0 else { return SIMD4<Float>(0, 0, 0, 0) }
        let t: Float
        if band.gradMode == 0 {
            t = min(max((across - (band.center - band.halfWidth)) / max(2 * band.halfWidth, 0.000001), 0), 1)
        } else {
            t = min(max((along - (band.centerL - band.halfLength)) / max(2 * band.halfLength, 0.000001), 0), 1)
        }
        let color = band.colorStart + (band.colorEnd - band.colorStart) * t
        let alpha = color.w * band.alpha * cov
        return SIMD4<Float>(color.x * alpha, color.y * alpha, color.z * alpha, alpha)
    }

    private static func boxCoverage(_ p: Float, center: Float, half: Float, aa: Float) -> Float {
        let d = half - abs(p - center)
        return min(max(d / max(aa, 0.000001) + 0.5, 0), 1)
    }
}

private enum BandFieldParseError: Error, CustomStringConvertible {
    case notObject

    var description: String {
        switch self {
        case .notObject: return "bands must be an object"
        }
    }
}

extension BandFieldManager {
    static func parse(_ value: StateValue, maxBands: Int) throws -> BandFieldState {
        guard case .object(let root) = value.value else { throw BandFieldParseError.notObject }
        let enabled = bool(root["enabled"], default: true)
        let xAmplitude = float(root["xAmplitudePx"], default: 0)
        let yAmplitude = float(root["yAmplitudePx"], default: 0)
        guard enabled else { return BandFieldState() }

        let layerValues: [StateValue.Value]
        if case .array(let layers)? = root["layers"] {
            layerValues = layers
        } else {
            layerValues = []
        }

        var layers: [BandFieldLayer] = []
        var totalBands = 0
        for layerValue in layerValues {
            guard case .object(let layerObject) = layerValue else { continue }
            let axis = axisValue(layerObject["axis"])
            let blendMode = blendModeValue(layerObject["blendMode"])
            let opacity = clamped(float(layerObject["opacity"], default: 1), 0, 1)
            guard case .array(let bandValues)? = layerObject["bands"] else { continue }
            var bands: [BandFieldBand] = []
            for bandValue in bandValues {
                guard totalBands < maxBands, case .object(let bandObject) = bandValue else { continue }
                bands.append(parseBand(bandObject))
                totalBands += 1
            }
            if !bands.isEmpty {
                layers.append(BandFieldLayer(axis: axis, blendMode: blendMode, opacity: opacity, bands: bands))
            }
        }

        return BandFieldState(
            enabled: enabled && !layers.isEmpty,
            xAmplitudePx: clamped(xAmplitude, -256, 256),
            yAmplitudePx: clamped(yAmplitude, -256, 256),
            layers: layers
        )
    }

    private static func parseBand(_ object: [String: StateValue.Value]) -> BandFieldBand {
        let colors = gradientEndpoints(object["gradient"])
        return BandFieldBand(
            center: clamped(float(object["center"], default: 0), -2, 2),
            halfWidth: max(0.0001, clamped(float(object["halfWidth"], default: 0.1), 0, 4)),
            featherW: max(0, clamped(float(object["featherW"], default: 0.001), 0, 2)),
            centerL: clamped(float(object["centerL"], default: 0), -2, 2),
            halfLength: max(0.0001, clamped(float(object["halfLength"], default: 1.2), 0, 4)),
            featherL: max(0, clamped(float(object["featherL"], default: 0.001), 0, 2)),
            alpha: clamped(float(object["alpha"], default: 1), 0, 1),
            colorStart: colors.0,
            colorEnd: colors.1,
            gradMode: gradModeValue(object["gradMode"])
        )
    }

    private static func gradientEndpoints(_ value: StateValue.Value?) -> (SIMD4<Float>, SIMD4<Float>) {
        guard case .array(let stops)? = value, !stops.isEmpty else {
            return (SIMD4<Float>(1, 1, 1, 1), SIMD4<Float>(1, 1, 1, 1))
        }
        let first = colorFromStop(stops.first) ?? SIMD4<Float>(1, 1, 1, 1)
        let last = colorFromStop(stops.last) ?? first
        return (first, last)
    }

    private static func colorFromStop(_ value: StateValue.Value?) -> SIMD4<Float>? {
        guard case .array(let parts)? = value else { return nil }
        if parts.count >= 2, case .floatArray(let color) = parts[1], color.count >= 4 {
            return SIMD4<Float>(
                clamped(Float(color[0]), 0, 1),
                clamped(Float(color[1]), 0, 1),
                clamped(Float(color[2]), 0, 1),
                clamped(Float(color[3]), 0, 1)
            )
        }
        if parts.count >= 4 {
            return SIMD4<Float>(
                clamped(float(parts[0], default: 1), 0, 1),
                clamped(float(parts[1], default: 1), 0, 1),
                clamped(float(parts[2], default: 1), 0, 1),
                clamped(float(parts[3], default: 1), 0, 1)
            )
        }
        return nil
    }

    private static func axisValue(_ value: StateValue.Value?) -> UInt32 {
        if case .string(let raw)? = value, raw.lowercased() == "horizontal" { return 1 }
        return UInt32(clamped(float(value, default: 0), 0, 1))
    }

    private static func blendModeValue(_ value: StateValue.Value?) -> UInt32 {
        if case .string(let raw)? = value {
            switch raw.lowercased() {
            case "add": return 1
            case "subtract": return 2
            case "mix": return 3
            case "multiply": return 4
            case "screen": return 5
            default: return 0
            }
        }
        return UInt32(clamped(float(value, default: 0), 0, 5))
    }

    private static func gradModeValue(_ value: StateValue.Value?) -> UInt32 {
        if case .string(let raw)? = value, raw.lowercased() == "length" { return 1 }
        return UInt32(clamped(float(value, default: 0), 0, 1))
    }

    private static func bool(_ value: StateValue.Value?, default fallback: Bool) -> Bool {
        if case .bool(let bool)? = value { return bool }
        if case .float(let number)? = value { return number != 0 }
        if case .string(let string)? = value { return string.lowercased() != "false" }
        return fallback
    }

    private static func float(_ value: StateValue.Value?, default fallback: Float) -> Float {
        guard let value else { return fallback }
        return float(value, default: fallback)
    }

    private static func float(_ value: StateValue.Value, default fallback: Float) -> Float {
        if case .float(let number) = value, number.isFinite { return Float(number) }
        return fallback
    }

    private static func clamped(_ value: Float, _ lower: Float, _ upper: Float) -> Float {
        min(max(value, lower), upper)
    }
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
