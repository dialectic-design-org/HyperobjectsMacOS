//
//  SceneInput.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 11/10/2024.
//

import Foundation

class SceneInput: ObservableObject, Identifiable {
    var id: UUID = UUID()
    var name: String
    var type: InputType
    var inputGroupName: String?
    var value: Any
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
}
