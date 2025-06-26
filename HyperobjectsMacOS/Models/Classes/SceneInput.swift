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
    var value: Any
    var range: ClosedRange<Float> = 0...1
    var audioReactive: Bool = false
    var audioAmplificationAddition: Float = 0.0
    var audioAmplificationAdditionRange: ClosedRange<Float> = 0...1
    var audioAmplificationMultiplication: Float = 0.0
    var audioAmplificationMultiplicationRange: ClosedRange<Float> = 0...1
    var audioAmplificationMultiplicationOffset: Float = 1.0
    var audioAmplificationMultiplicationOffsetRange: ClosedRange<Float> = -1...1
    
    init(name: String,
         type: InputType,
         value: Any = 0.0,
         range: ClosedRange<Float> = 0...1,
         audioReactive: Bool = false,
         audioAmplificationAddition: Float = 0.0,
         audioAmplificationAdditionRange: ClosedRange<Float> = 0...1,
         audioAmplificationMultiplication: Float = 0.0,
         audioAmplificationMultiplicationRange: ClosedRange<Float> = 0...1,
         audioAmplificationMultiplicationOffset: Float = 1.0,
         audioAmplificationMultiplicationOffsetRange: ClosedRange<Float> = -1...1
    ) {
        self.name = name
        self.type = type
        self.value = value
        self.range = range
        self.audioReactive = audioReactive
        self.audioAmplificationAddition = audioAmplificationAddition
        self.audioAmplificationAdditionRange = audioAmplificationAdditionRange
        self.audioAmplificationMultiplication = audioAmplificationMultiplication
        self.audioAmplificationMultiplicationRange = audioAmplificationMultiplicationRange
        self.audioAmplificationMultiplicationOffset = audioAmplificationMultiplicationOffset
        self.audioAmplificationMultiplicationOffsetRange = audioAmplificationMultiplicationOffsetRange
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
