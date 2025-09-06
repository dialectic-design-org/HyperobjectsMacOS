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
    @State private var steepness: Double = 10.0
    @Binding var selectedEnvelopeType: EnvelopeType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Sigmoid Envelope")
                    .font(.headline)
                    .fontDesign(.monospaced)
                Spacer()
                EnvelopePicker(selectedEnvelopeType: $selectedEnvelopeType)
            }
            HStack {
                VStack(spacing: 4) {
                    HStack {
                        Text("Steepness:")
                            .frame(width: 80, alignment: .leading)
                        Slider(value: $steepness, in: 0.1...200.0).onChange(of: steepness) { oldValue, newValue in
                            envelope.steepness = newValue
                        }.controlSize(.mini)
                        Text(String(format: "%.1f", envelope.steepness))
                            .frame(width: 40, alignment: .trailing)
                    }
                    
                    HStack {
                        Text("Threshold:")
                            .frame(width: 80, alignment: .leading)
                        Slider(value: $envelope.threshold, in: 0.0...2.0).controlSize(.mini)
                        Text(String(format: "%.2f", envelope.threshold))
                            .frame(width: 40, alignment: .trailing)
                    }
                    
                    HStack {
                        Text("Gain:")
                            .frame(width: 80, alignment: .leading)
                        Slider(value: $envelope.outputGain, in: 0.0...2.0).controlSize(.mini)
                        Text(String(format: "%.2f", envelope.outputGain))
                            .frame(width: 40, alignment: .trailing)
                    }
                    Spacer()
                }
                // Sigmoid curve visualization
                SigmoidCurveView(
                    envelope: envelope,
                    currentInput: currentInput,
                    currentOutput: currentOutput
                )
                .frame(height: 120)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
        .fontDesign(.monospaced)
    }
}

