//
//  SceneInput.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 11/10/2024.
//

import Foundation
import SwiftUI
import AppKit
import QuartzCore

final class SceneInput: ObservableObject, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var type: InputType
    var inputGroupName: String?
    
    private struct HistoryEntry {
        let t: CFTimeInterval
        let value: Any
    }
    
    private var history: [HistoryEntry] = []
    private let historyWindow: CFTimeInterval = 30.0
    
    
    var value: Any {
        didSet {
            if SceneInput.valueKey(oldValue) != SceneInput.valueKey(value) {
                recordValueChange()
            }
        }
    }
    var audioDelay: Float = 0.0
    var presetValues: [String: Any] = [:]
    var range: ClosedRange<Float> = 0...1
    var audioReactive: Bool = false
    var audioAmplificationAddition: Float = 0.0
    var audioAmplificationAdditionRange: ClosedRange<Float> = 0...1
    var audioAmplificationMultiplication: Float = 0.0
    var audioAmplificationMultiplicationRange: ClosedRange<Float> = 0...1
    var audioAmplificationMultiplicationOffset: Float = 1.0
    var audioAmplificationMultiplicationOffsetRange: ClosedRange<Float> = -1...1
    
    var tickValueAdjustment: Double = 0.0
    var tickValueAdjustmentRange: ClosedRange<Double> = 0...1
    var tickValueAudioAdjustment: Double = 0.0
    var tickValueAudioAdjustmentRange: ClosedRange<Double> = 0...1
    var tickValueAudioAdjustmentOffset: Double = 0.0
    var tickValueAudioAdjustmentOffsetRange: ClosedRange<Double> = -1...1
    
    private enum ValueKey: Equatable {
        case num(Float), bool(Bool), str(String)
        case color(r: Float, g: Float, b: Float, a: Float)
        case none
    }
    
    private static func valueKey(_ any: Any) -> ValueKey {
        switch any {
        case let v as Float: return .num(v)
        case let v as Double: return .num(Float(v))
        case let v as Int: return .num(Float(v))
        case let v as Bool: return .bool(v)
        case let v as String: return .str(v)
        case let v as Color: let ns = NSColor(v).usingColorSpace(.sRGB) ?? NSColor.black
            return .color(r: Float(ns.redComponent), g: Float(ns.greenComponent), b: Float(ns.blueComponent), a: Float(ns.alphaComponent))
        default:
            return .str(String(describing: any))
        }
    }
    
    
    static func == (l: SceneInput, r: SceneInput) -> Bool {
        l.id == r.id &&
        l.name == r.name &&
        l.type == r.type &&
        l.inputGroupName == r.inputGroupName &&
        l.range == r.range &&
        l.audioReactive == r.audioReactive &&
        l.audioAmplificationAddition == r.audioAmplificationAddition &&
        l.audioAmplificationMultiplication == r.audioAmplificationMultiplication &&
        l.audioAmplificationMultiplicationOffset == r.audioAmplificationMultiplicationOffset &&
        l.tickValueAdjustment == r.tickValueAdjustment &&
        l.tickValueAudioAdjustment == r.tickValueAudioAdjustment &&
        l.tickValueAudioAdjustmentOffset == r.tickValueAudioAdjustmentOffset &&
        SceneInput.valueKey(l.value) == SceneInput.valueKey(r.value)
    }
    
    
    
    init(name: String,
         type: InputType,
         inputGroupName: String? = nil,
         value: Any = 0.0,
         presetValues: [String: Any] = [:],
         range: ClosedRange<Float> = 0...1,
         audioReactive: Bool = false,
         audioAmplificationAddition: Float = 0.0,
         audioAmplificationAdditionRange: ClosedRange<Float> = 0...1,
         audioAmplificationMultiplication: Float = 0.0,
         audioAmplificationMultiplicationRange: ClosedRange<Float> = 0...1,
         audioAmplificationMultiplicationOffset: Float = 1.0,
         audioAmplificationMultiplicationOffsetRange: ClosedRange<Float> = -1...1,
         tickValueAdjustment: Double = 0.0,
         tickValueAdjustmentRange: ClosedRange<Double> = 0...1,
         tickValueAudioAdjustment: Double = 0.0,
         tickValueAudioAdjustmentRange: ClosedRange<Double> = 0...1,
         tickValueAudioAdjustmentOffset: Double = 0.0
    ) {
        self.name = name
        self.type = type
        self.inputGroupName = inputGroupName
        self.value = value
        self.presetValues = presetValues
        self.range = range
        self.audioReactive = audioReactive
        self.audioAmplificationAddition = audioAmplificationAddition
        self.audioAmplificationAdditionRange = audioAmplificationAdditionRange
        self.audioAmplificationMultiplication = audioAmplificationMultiplication
        self.audioAmplificationMultiplicationRange = audioAmplificationMultiplicationRange
        self.audioAmplificationMultiplicationOffset = audioAmplificationMultiplicationOffset
        self.audioAmplificationMultiplicationOffsetRange = audioAmplificationMultiplicationOffsetRange
        
        self.tickValueAdjustment = tickValueAdjustment
        self.tickValueAdjustmentRange = tickValueAdjustmentRange
        self.tickValueAudioAdjustment = tickValueAudioAdjustment
        self.tickValueAudioAdjustmentRange = tickValueAudioAdjustmentRange
        self.tickValueAudioAdjustmentOffset = tickValueAudioAdjustmentOffset
        
        recordValueChange(force: true)
    }
    
    func getHistoryValue(millisecondsAgo ms: Double) -> Any {
        let target = CACurrentMediaTime() - (ms / 1000.0)
        guard let idx = indexOfClosestTimestamp(to: target) else {
            return value
        }
        return history[idx].value
    }
    
    private func recordValueChange(force: Bool = false) {
        let t = CACurrentMediaTime()
        if !force, let last = history.last, SceneInput.valueKey(last.value) == SceneInput.valueKey(value) {
            return
        }
        history.append(HistoryEntry(t: t, value: value))
        trimHistory(olderThan: t - historyWindow)
    }
    
    func addValueChange(value: Any) {
        let t = CACurrentMediaTime()
        history.append(HistoryEntry(t: t, value: value))
    }
    
    private func trimHistory(olderThan cutoff: TimeInterval) {
        if let firstKeep = history.firstIndex(where: { $0.t >= cutoff }) {
            if firstKeep > 0 { history.removeFirst(firstKeep) }
        } else {
            history.removeAll(keepingCapacity: true)
        }
    }
    
    private func indexOfClosestTimestamp(to target: CFTimeInterval) -> Int? {
        guard !history.isEmpty else { return nil }
        
        var lo = 0
        var hi = history.count
        while lo < hi {
            let mid = (lo + hi) >> 1
            if history[mid].t < target {
                lo = mid + 1
            } else {
                hi = mid
            }
        }
        
        if lo == 0 { return 0 }
        if lo == history.count { return history.count - 1 }
        
        let prev = history[lo - 1].t
        let next = history[lo].t
        return (target - prev) <= (next - target) ? (lo - 1) : lo
    }
    
    
    func valueAsFloat() -> Float {
        if self.value is Float {
            return self.value as! Float
        } else if self.value is Double {
            return Float(self.value as! Double)
        } else if self.value is Int {
            return Float(self.value as! Int)
        }
        return Float(0.0)
    }
    
    func combinedValueAsFloat(audioSignal: Float = 0.0) -> Float {
        return self.valueAsFloat()
            * (audioAmplificationMultiplicationOffset + self.audioAmplificationMultiplication * audioSignal)
            + self.audioAmplificationAddition * audioSignal
    }
    
    
    func toStateValue() -> StateValue {
        if self.type == .float {
            if let floatValue = self.value as? Double {
                return StateValue(value: .float(floatValue as! Double))
            }
            if let floatValue = self.value as? Float {
                return StateValue(value: .float(Double(floatValue)))
            }
        } else if self.type == .colorInput {
            let color = self.value as! Color
            let colorVec = color.asSIMD4()
            return StateValue(value: .vector4(colorVec))
        }
        return StateValue(value: .float(0.0))
    }
}


extension Color {
    /// Converts a SwiftUI Color to a SIMD4<Double> [r, g, b, a] vector on macOS.
    func asSIMD4() -> SIMD4<Double> {
        // Convert SwiftUI Color → NSColor in a calibrated RGB color space
        let nsColor = NSColor(self).usingColorSpace(.deviceRGB) ?? .black
        
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        nsColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return SIMD4<Double>(
            Double(red),
            Double(green),
            Double(blue),
            Double(alpha)
        )
    }
}
