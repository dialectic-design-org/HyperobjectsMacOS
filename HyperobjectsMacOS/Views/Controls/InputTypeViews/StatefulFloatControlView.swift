//
//  StatefulFloatControlView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 27/06/2025.
//

import SwiftUI

struct StatefulFloatControlView: View {
    @ObservedObject var input: SceneInput
    
    @State private var tickValueAdjustment: Double = 0.0
    @State private var tickValueAudioAdjustment: Double = 0.0
    @State private var tickValueAudioAdjustmentOffset: Double = 0.0
    
    @State private var displayValue: String = "0.00"   // local, cheap UI state

    var controlLabelWidth: CGFloat = 110
    var body: some View {
        VStack {
            HStack {
                HStack {
                    Text("Tick:")
                    Spacer()
                    Text("\(String(format: "%.3f", tickValueAdjustment))")
                }.frame(width: controlLabelWidth, alignment: .leading)
                Slider(value: $tickValueAdjustment, in: input.tickValueAdjustmentRange)
                    .controlSize(.mini)
                    .onChange(of: tickValueAdjustment) { oldValue, newValue in
                        input.tickValueAdjustment = newValue
                    }
            }
            HStack {
                HStack {
                    Text("Audio:")
                    Spacer()
                    Text("\(String(format: "%.3f", tickValueAudioAdjustment))")
                }.frame(width: controlLabelWidth, alignment: .leading)
                Slider(value: $tickValueAudioAdjustment, in: input.tickValueAudioAdjustmentRange)
                    .controlSize(.mini)
                    .onChange(of: tickValueAudioAdjustment) { oldValue, newValue in
                        input.tickValueAudioAdjustment = newValue
                    }
            }
            HStack {
                HStack {
                    Text("Offset:")
                    Spacer()
                    Text("\(String(format: "%.3f", tickValueAudioAdjustmentOffset))")
                }.frame(width: controlLabelWidth, alignment: .leading)
                Slider(value: $tickValueAudioAdjustmentOffset, in: input.tickValueAudioAdjustmentOffsetRange)
                    .controlSize(.mini)
                    .onChange(of: tickValueAudioAdjustmentOffset) { oldValue, newValue in
                        input.tickValueAudioAdjustmentOffset = newValue
                    }
                Button("Reset") {
                    input.tickValueAudioAdjustmentOffset = 0
                    tickValueAudioAdjustmentOffset = 0
                }.buttonStyle(PlainButtonStyle())
            }
            HStack {
                Text("Current value: \(displayValue)")
                Text("Value resets:")
                Button("0") {
                    input.value = Double(0)
                }
                Spacer()
            }
        }.onReceive(
            Timer.publish(every: 0.12, on: .main, in: .common).autoconnect()
                .map { _ in String(format: "%.2f", input.valueAsFloat()) }
                .removeDuplicates()
        ) { displayValue = $0 }
    }
}
