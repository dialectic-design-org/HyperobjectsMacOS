//
//  EnvelopePicker.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 06/09/2025.
//

import SwiftUI

struct EnvelopePicker: View {
    @Binding var selectedEnvelopeType: EnvelopeType
    var body: some View {
        Picker("Envelope Type", selection: $selectedEnvelopeType) {
            ForEach(EnvelopeType.allCases, id: \.self) { type in
                Text(type.rawValue).tag(type)
                    .fontDesign(.monospaced)
            }
        }.pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.mini)
            .frame(maxWidth: 200)
    }
}
