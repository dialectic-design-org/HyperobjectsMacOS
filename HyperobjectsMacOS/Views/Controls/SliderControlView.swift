//
//  SliderControlView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 18/03/2025.
//

import SwiftUI

struct SliderControlView: View {
    @ObservedObject var input: SceneInput
    
    // Local state mirrors
    @State private var userValue: Float = 0.0
    @State private var add: Float = 0.0
    @State private var mul: Float = 1.0
    @State private var offset: Float = 0.0

    var body: some View {
        VStack {
            Slider(value: $userValue, in: input.range)
                .onChange(of: userValue) { oldValue, newValue in
                    input.value = newValue
                }

            HStack {
                VStack {
                    Text("+")
                    Slider(value: $add, in: input.audioAmplificationAdditionRange)
                        .onChange(of: add) { oldValue, newValue in
                            input.audioAmplificationAddition = newValue
                        }
                }
                
                VStack {
                    Text("x")
                    Slider(value: $mul, in: input.audioAmplificationMultiplicationRange)
                        .controlSize(.mini)
                        .onChange(of: mul) { oldValue, newValue in
                            input.audioAmplificationMultiplication = newValue
                        }
                }
                
                VStack {
                    Text("offset")
                    Slider(value: $offset, in: input.audioAmplificationMultiplicationOffsetRange)
                        .controlSize(.mini)
                        .onChange(of: offset) { oldValue, newValue in
                            input.audioAmplificationMultiplicationOffset = newValue
                        }
                }
            }
        }
        .onAppear {
            // Initialize local state once
            userValue = input.value as? Float ?? 0.0
            add = input.audioAmplificationAddition
            mul = input.audioAmplificationMultiplication
            offset = input.audioAmplificationMultiplicationOffset
        }
    }
}


struct InstrumentedSlider: View {
    @Binding var value: Float
    var range: ClosedRange<Float>
    var onUpdateDuration: ((Double) -> Void)?

    var body: some View {
        Slider(value: Binding<Float>(
            get: { value },
            set: { newValue in
                let startTime = DispatchTime.now()
                value = newValue
                DispatchQueue.main.async {
                    let endTime = DispatchTime.now()
                    let duration = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000
                    onUpdateDuration?(duration)
                }
            }
        ), in: range)
    }
}

