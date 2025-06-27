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
    
    var body: some View {
        VStack {
            Text("Stateful Float Control View").fontWeight(.bold)
            Text("Value adjustment per tick")
            Slider(value: $tickValueAdjustment, in: input.tickValueAdjustmentRange)
                .onChange(of: tickValueAdjustment) { oldValue, newValue in
                    input.tickValueAdjustment = newValue
                }
            Text("Audio adjustment per tick")
            Slider(value: $tickValueAudioAdjustment, in: input.tickValueAudioAdjustmentRange)
                .onChange(of: tickValueAudioAdjustment) { oldValue, newValue in
                    input.tickValueAudioAdjustment = newValue
                }
            Text("Audio offset adjustment")
            Slider(value: $tickValueAudioAdjustmentOffset, in: input.tickValueAudioAdjustmentOffsetRange)
                .onChange(of: tickValueAudioAdjustmentOffset) { oldValue, newValue in
                    input.tickValueAudioAdjustmentOffset = newValue
                }
        }
    }
}
