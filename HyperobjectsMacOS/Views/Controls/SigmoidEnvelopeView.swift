//
//  SigmoidEnvelopeView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 28/06/2025.
//

import SwiftUI

struct SigmoidEnvelopeView: View {
    @ObservedObject var envelope: SigmoidEnvelope
    let currentInput: Double
    let currentOutput: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sigmoid Envelope")
                .font(.headline)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Steepness:")
                        .frame(width: 80, alignment: .leading)
                    Slider(value: $envelope.steepness, in: 0.1...200.0)
                    Text(String(format: "%.1f", envelope.steepness))
                        .frame(width: 40, alignment: .trailing)
                }
                
                HStack {
                    Text("Threshold:")
                        .frame(width: 80, alignment: .leading)
                    Slider(value: $envelope.threshold, in: 0.0...2.0)
                    Text(String(format: "%.2f", envelope.threshold))
                        .frame(width: 40, alignment: .trailing)
                }
                
                HStack {
                    Text("Gain:")
                        .frame(width: 80, alignment: .leading)
                    Slider(value: $envelope.outputGain, in: 0.0...2.0)
                    Text(String(format: "%.2f", envelope.outputGain))
                        .frame(width: 40, alignment: .trailing)
                }
            }
            // Sigmoid curve visualization
            SigmoidCurveView(
                envelope: envelope,
                currentInput: currentInput,
                currentOutput: currentOutput
            )
            .frame(height: 150)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

