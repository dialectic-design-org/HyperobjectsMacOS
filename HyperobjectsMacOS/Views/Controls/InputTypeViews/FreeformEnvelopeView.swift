//
//  FreeformEnvelopeView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 28/06/2025.
//

import SwiftUI

struct FreeformEnvelopeView: View {
    @ObservedObject var envelope: FreeformEnvelope
    let currentInput: Double
    let currentOutput: Double
    @Binding var selectedEnvelopeType: EnvelopeType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Free Form Envelope")
                    .font(.headline)
                    .fontDesign(.monospaced)
                Spacer()
                EnvelopePicker(selectedEnvelopeType: $selectedEnvelopeType)
            }
            
            FreeformCurveEditor(
                envelope: envelope,
                currentInput: currentInput,
                currentOutput: currentOutput
            )
                .frame(height: 200)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            
            HStack {
                Button("Reset") {
                    envelope.controlPoints = [
                        ControlPoint(x: 0.0, y: 0.0),
                        ControlPoint(x: 0.5, y: 0.3),
                        ControlPoint(x: 1.0, y: 1.0)
                    ]
                }.buttonStyle(.bordered)
                
                Spacer()
                Text("Drag points to adjust curve")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}
