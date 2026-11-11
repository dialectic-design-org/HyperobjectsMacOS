//
//  ScriptInputApplier.swift
//  HyperobjectsMacOS
//
//  Applies one key of a script's outputState to a SceneInput. Shared by the flat scene path
//  (applyScriptOutput in the App) and by scripted objects (ScriptedObjectStore), so a key
//  means the same thing in both.
//

import SwiftUI
import AppKit

/// Prints each kind of script-output warning once per key instead of once per frame.
final class ScriptOutputWarningCache {
    private var boolTypeMismatchKeys: Set<String> = []
    private var intCoercionFailureKeys: Set<String> = []
    private var messageIDs: Set<String> = []
    private let lock = NSLock()

    func warnIntCoercionFailureOnce(key: String, output: StateValue) {
        lock.lock()
        let isNew = intCoercionFailureKeys.insert(key).inserted
        lock.unlock()
        if isNew {
            print("[State Change] Could not convert output for integer input \(key) to an Int: \(output)")
        }
    }

    func warnBoolTypeMismatchOnce(key: String, input: StateValue, output: StateValue) {
        lock.lock()
        let isNew = boolTypeMismatchKeys.insert(key).inserted
        lock.unlock()
        if isNew {
            print("[State Change] Ignoring bool output for numeric key \(key): \(input) -> \(output)")
        }
    }

    /// Generic once-per-id warning. Returns true when the message was printed.
    @discardableResult
    func warnOnce(id: String, _ message: @autoclosure () -> String) -> Bool {
        lock.lock()
        let isNew = messageIDs.insert(id).inserted
        lock.unlock()
        if isNew { print(message()) }
        return isNew
    }
}

func safeInt(_ value: Double) -> Int? {
    guard value.isFinite else { return nil }
    if value >= Double(Int.max) { return Int.max }
    if value <= Double(Int.min) { return Int.min }
    return Int(value)
}

/// Which field of a SceneInput a script key addresses.
enum ScriptKeyTarget: Equatable {
    case value
    case audioAdd
    case audioMultiply
    case audioMultiplyOffset
    case audioDelay
    case audioSmoothedSource
    case frameTick
}

enum ScriptInputApplier {
    /// The key prefixes a script can put in front of an input name. The order matters:
    /// "audio_multiply_offset_" has to be tried before "audio_multiply_".
    static let keyPrefixes: [(prefix: String, target: ScriptKeyTarget)] = [
        ("audio_add_", .audioAdd),
        ("audio_multiply_offset_", .audioMultiplyOffset),
        ("audio_multiply_", .audioMultiply),
        ("audio_delay_", .audioDelay),
        ("frame_tick_", .frameTick),
        ("audio_smoothed_source_", .audioSmoothedSource)
    ]

    /// "Width" -> (Width, .value); "audio_add_Width" -> (Width, .audioAdd); unknown -> nil.
    /// Prefixes are tried first, like `apply` does for numeric values.
    static func resolve(_ key: String, in inputsByName: [String: SceneInput]) -> (input: SceneInput, target: ScriptKeyTarget)? {
        for (prefix, target) in keyPrefixes where key.hasPrefix(prefix) {
            if let input = inputsByName[String(key.dropFirst(prefix.count))] {
                return (input, target)
            }
        }
        if let input = inputsByName[key] {
            return (input, .value)
        }
        return nil
    }

    /// The value a script sees in `inputState` for this key.
    static func currentValue(of input: SceneInput, target: ScriptKeyTarget) -> StateValue {
        switch target {
        case .value: return input.toStateValue()
        case .audioAdd: return StateValue(value: .float(Double(input.audioAmplificationAddition)))
        case .audioMultiply: return StateValue(value: .float(Double(input.audioAmplificationMultiplication)))
        case .audioMultiplyOffset: return StateValue(value: .float(Double(input.audioAmplificationMultiplicationOffset)))
        case .audioDelay: return StateValue(value: .float(Double(input.audioDelay)))
        case .audioSmoothedSource: return StateValue(value: .float(Double(input.audioSmoothedSource)))
        case .frameTick: return StateValue(value: .float(input.tickValueAdjustment))
        }
    }

    /// The value a script sees in `baseState` for this key: what the input was authored with.
    /// nil for the value of a stateful float, which accumulates and has no base to return to.
    static func baseValue(of input: SceneInput, target: ScriptKeyTarget) -> StateValue? {
        switch target {
        case .value: return input.type == .statefulFloat ? nil : input.initialStateValue()
        case .audioAdd: return StateValue(value: .float(Double(input.init_audioAmplificationAddition)))
        case .audioMultiply: return StateValue(value: .float(Double(input.init_audioAmplificationMultiplication)))
        case .audioMultiplyOffset: return StateValue(value: .float(Double(input.init_audioAmplificationMultiplicationOffset)))
        case .audioDelay: return StateValue(value: .float(Double(input.init_audioDelay)))
        case .audioSmoothedSource: return StateValue(value: .float(Double(input.init_audioSmoothedSource)))
        case .frameTick: return StateValue(value: .float(input.init_tickValueAdjustment))
        }
    }

    /// Writes `outVal` for `key` into the matching input. `inVal` is the key's current value
    /// (`currentValue`), which decides how the output is interpreted.
    static func apply(key: String, value outVal: StateValue, current inVal: StateValue, inputsByName: [String: SceneInput], warningCache: ScriptOutputWarningCache) {
        // Integer scene inputs accept any output that can reasonably be read as an Int.
        if let input = inputsByName[key], input.type == .integer {
            if let intVal = outVal.coercedToInt() {
                input.value = intVal
            } else {
                warningCache.warnIntCoercionFailureOnce(key: key, output: outVal)
            }
            return
        }

        switch (inVal.value, outVal.value) {
        case (.float, .bool):
            warningCache.warnBoolTypeMismatchOnce(key: key, input: inVal, output: outVal)
            return
        case (.float, .float(let b)):
            if key.isEmpty == false, key.hasPrefix("audio_add_") {
                let audioKey = String(key.dropFirst("audio_add_".count))
                if let input = inputsByName[audioKey] {
                    input.audioAmplificationAddition = Float(b)
                }
            } else if key.isEmpty == false, key.hasPrefix("audio_multiply_offset_") {
                let audioKey = String(key.dropFirst("audio_multiply_offset_".count))
                if let input = inputsByName[audioKey] {
                    input.audioAmplificationMultiplicationOffset = Float(b)
                }
            } else if key.isEmpty == false, key.hasPrefix("audio_multiply_") {
                let audioKey = String(key.dropFirst("audio_multiply_".count))
                if let input = inputsByName[audioKey] {
                    input.audioAmplificationMultiplication = Float(b)
                }
            } else if key.isEmpty == false, key.hasPrefix("audio_delay_") {
                let audioKey = String(key.dropFirst("audio_delay_".count))
                if let input = inputsByName[audioKey] {
                    input.audioDelay = Float(b)
                }
            } else if key.isEmpty == false, key.hasPrefix("frame_tick_") {
                let audioKey = String(key.dropFirst("frame_tick_".count))
                if let input = inputsByName[audioKey] {
                    input.tickValueAdjustment = Double(b)
                }
            } else if key.isEmpty == false, key.hasPrefix("audio_smoothed_source_") {
                let audioKey = String(key.dropFirst("audio_smoothed_source_".count))
                if let input = inputsByName[audioKey] {
                    if let intVal = safeInt(b) {
                        input.audioSmoothedSource = intVal
                    } else {
                        print("[Script Output] Ignoring non-finite value for \(key): \(b)")
                    }
                }
            } else {
                // Update the matching input safely by name, avoiding optional-call and enum ambiguity
                if let input = inputsByName[key] {
                    if input.type == .float {
                        input.value = Double(b)
                    } else if input.type == .statefulFloat {
                        input.value = Double(b)
                    }
                }
            }
        case (.vector4, .vector4(let b)):
            if let input = inputsByName[key] {
                if input.type == .colorInput {
                    let nsColor = NSColor(deviceRed: b[0], green: b[1], blue: b[2], alpha: b[3])
                    input.value = Color(nsColor: nsColor)
                }
            }
        case (.string, .string(let b)):
            if let input = inputsByName[key] {
                if input.type == .string {
                    input.value = b
                }
            }
        case (.lineSegments, .lineSegments(let b)):
            if let input = inputsByName[key] {
                var newLines: [Line] = []
                for scriptLine in b {
                    let start = SIMD3<Float>(Float(scriptLine.start.x), Float(scriptLine.start.y), Float(scriptLine.start.z))
                    let end = SIMD3<Float>(Float(scriptLine.end.x), Float(scriptLine.end.y), Float(scriptLine.end.z))
                    var newLine = Line(
                        startPoint: start,
                        endPoint: end,
                        lineWidthStart: Float(scriptLine.lineWidthStart),
                        lineWidthEnd: Float(scriptLine.lineWidthEnd)
                    )
                    newLine = newLine.setBasicEndPointColors(
                        startColor: SIMD4<Float>(
                            Float(scriptLine.colorStart.x),
                            Float(scriptLine.colorStart.y),
                            Float(scriptLine.colorStart.z),
                            Float(scriptLine.colorStart.w)
                        ),
                        endColor: SIMD4<Float>(
                            Float(scriptLine.colorEnd.x),
                            Float(scriptLine.colorEnd.y),
                            Float(scriptLine.colorEnd.z),
                            Float(scriptLine.colorEnd.w)
                        )
                    )
                    newLines.append(newLine)
                }
                input.value = newLines
            }
        default:
            // Different types or unhandled types
            print("[State Change] Type or value changed unhandled for key \(key): \(inVal) -> \(outVal)")
        }
    }
}
