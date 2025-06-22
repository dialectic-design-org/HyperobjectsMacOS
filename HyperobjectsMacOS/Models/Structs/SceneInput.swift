//
//  SceneInput.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 11/10/2024.
//

import Foundation

struct SceneInput: Identifiable {
    var id: UUID = UUID()
    var name: String
    var type: InputType
    var value: Any
    var audioReactive: Bool = false
    var audioSignal: Float = 0.0
    var audioAmplification: Float = 1.0
    var range: ClosedRange<Float> = 0...1
    
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
    
    func combinedValueAsFloat() -> Float {
        return self.valueAsFloat() + self.audioAmplification * self.audioSignal
    }
}
