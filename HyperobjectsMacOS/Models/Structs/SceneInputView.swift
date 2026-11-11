//
//  SceneInputView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 25/05/2026.
//

import Foundation
import SwiftUI

struct SceneInputView {
    let id: UUID
    let name: String
    let type: InputType
    let value: SceneInputValue
    let audioDelay: Float
    let audioSmoothedSource: Int
    let audioAmplificationMultiplication: Float
    let audioAmplificationAddition: Float
    let audioAmplificationMultiplicationOffset: Float
}

enum SceneInputValue {
    case float(Double)
    case integer(Int)
    case bool(Bool)
    case string(String)
    case color(Color)
    case lines([Line])
    case unsupported

    func asAny() -> Any {
        switch self {
        case .float(let v):   return v
        case .integer(let v): return v
        case .bool(let v):    return v
        case .string(let v):  return v
        case .color(let v):   return v
        case .lines(let v):   return v
        case .unsupported:    return 0.0
        }
    }
}

extension SceneInputValue {
    /// Captures a SceneInput's `value` into a Sendable-friendly enum for the geometry queue.
    static func capture(_ any: Any, type: InputType) -> SceneInputValue {
        // For .integer-typed inputs we must preserve Int identity — `intFromInputs`
        // does `as? Int` and would fail against a Double.
        // For .float / .statefulFloat we collapse Int/Float/Double to .float(Double).
        if type == .integer {
            if let v = any as? Int    { return .integer(v) }
            if let v = any as? Double { return .integer(Int(v)) }
            if let v = any as? Float  { return .integer(Int(v)) }
        }
        switch any {
        case let v as Float:  return .float(Double(v))
        case let v as Double: return .float(v)
        case let v as Int:    return .float(Double(v))
        case let v as Bool:   return .bool(v)
        case let v as String: return .string(v)
        case let v as Color:  return .color(v)
        case let v as [Line]: return .lines(v)
        default:              return .unsupported
        }
    }
}

extension SceneInputView {
    /// Main-thread capture of a live input (a scene's or a scripted object's).
    init(capturing input: SceneInput) {
        self.init(
            id: input.id,
            name: input.name,
            type: input.type,
            value: SceneInputValue.capture(input.value, type: input.type),
            audioDelay: input.audioDelay,
            audioSmoothedSource: input.audioSmoothedSource,
            audioAmplificationMultiplication: input.audioAmplificationMultiplication,
            audioAmplificationAddition: input.audioAmplificationAddition,
            audioAmplificationMultiplicationOffset: input.audioAmplificationMultiplicationOffset
        )
    }
}
