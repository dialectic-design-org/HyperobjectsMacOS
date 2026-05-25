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
