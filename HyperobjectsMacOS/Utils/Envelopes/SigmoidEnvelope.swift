//
//  SigmoidEnvelope.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 28/06/2025.
//

import SwiftUI

class SigmoidEnvelope: EnvelopeProcessor, ObservableObject {
    @Published var steepness: Double = 5.0
    @Published var threshold: Double = 0.5
    @Published var outputGain: Double = 1.0
    
    func process(_ input: Double) -> Double {
        let clampedInput = max(0.0, min(1.0, input))
        let shifted = clampedInput - threshold
        let sigmoid = 1.0 / (1.0 + exp(-steepness * shifted))
        return sigmoid * outputGain
    }
}

func sigmoidFunction(input: Double, steepness: Double = 5.0, threshold: Double = 0.5, outputGain: Double = 1.0) -> Double {
    let clampedInput = max(0.0, min(1.0, input))
    let shifted = clampedInput - threshold
    let sigmoid = 1.0 / (1.0 + exp(-steepness * shifted))
    return sigmoid * outputGain
}
