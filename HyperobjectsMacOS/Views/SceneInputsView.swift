//
//  SceneInputsView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 12/10/2024.
//

import SwiftUI
var lastTickTime: Float = 0

struct SceneInputsView: View {
    @EnvironmentObject var currentScene: GeometriesSceneBase
    @StateObject private var audioMonitor = AudioInputMonitor()
    @StateObject private var sigmoidEnvelope = SigmoidEnvelope()
    @StateObject private var freeformEnvelope = FreeformEnvelope()
    @State private var showSliders: Bool = true
    
    @State private var selectedEnvelopeType: EnvelopeType = .sigmoid
    
    
    var currentProcessor: EnvelopeProcessor {
        switch selectedEnvelopeType {
        case .sigmoid:
            return sigmoidEnvelope
        case .freeform:
            return freeformEnvelope
        }
    }
    
    let smoothingSampleCountOptions = [
        2,
        5,
        10,
        20,
        50,
        100
    ]
    
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(
                            hue: Double(1.0 - audioMonitor.smoothedVolume),
                            saturation: Double(0.0 + audioMonitor.smoothedVolume),
                            brightness: Double(0.0 + audioMonitor.smoothedVolume)
                        ))
                        .frame(width: CGFloat(500 - (audioMonitor.smoothedVolume * 500)), height: 10)
                        .onAppear {
                            audioMonitor.startMonitoring()
                        }
                        .onDisappear() {
                            audioMonitor.stopMonitoring()
                        }
                    
                    
                    HStack {
                        ForEach(smoothingSampleCountOptions, id: \.self) { count in
                            Button("Smoothing \(count)") {
                                audioMonitor.smoothingSampleCount = count
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Audio Timeline")
                            .font(.headline)
                        
                        AudioTimelineChartView(historyData: currentScene.historyData)
                            .frame(height: 220)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        
                        // Legend
                        HStack(spacing: 20) {
                            LegendItem(color: .red, label: "Raw")
                            LegendItem(color: .orange, label: "Smoothed")
                            LegendItem(color: .green, label: "Processed")
                            
                            Spacer()
                            
                            Text("\(currentScene.historyData.count) samples")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                    
                    HStack {
                        VStack {
                            Text("Full")
                            AudioVisualizerView(
                                currentVolume: Double(currentScene.audioSignalRaw),
                                smoothedVolume: Double(currentScene.audioSignal),
                                processedVolume: currentScene.audioSignalProcessed
                            )
                        }
                        VStack {
                            Text("Lowpass")
                            AudioVisualizerView(
                                currentVolume: Double(currentScene.audioSignalLowpassRaw),
                                smoothedVolume: Double(currentScene.audioSignalLowpassSmoothed),
                                processedVolume: currentScene.audioSignalLowpassProcessed
                            )
                        }
                    }
                    
                    Picker("Envelope Type", selection: $selectedEnvelopeType) {
                        ForEach(EnvelopeType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }.pickerStyle(.segmented)
                        .frame(maxWidth: 500)
                    
                    Button(action: {
                        showSliders.toggle()
                    }) {
                        Text(showSliders ? "Hide Sliders" : "Show Sliders")
                    }
                    
                    VStack {
                        
                        switch selectedEnvelopeType {
                        case .sigmoid:
                            SigmoidEnvelopeView(
                                envelope: sigmoidEnvelope,
                                currentInput: Double(currentScene.audioSignal),
                                currentOutput: currentScene.audioSignalProcessed
                            )
                        case .freeform:
                            FreeformEnvelopeView(
                                envelope: freeformEnvelope,
                                currentInput: Double(currentScene.audioSignal),
                                currentOutput: currentScene.audioSignalProcessed
                            )
                        }
                    }
                    
                }
                if showSliders {
                    ForEach(currentScene.inputs) { input in
                        VStack(alignment: .leading) {
                            let formattedString = String(format: "%.2f", input.valueAsFloat())
                            Text("\(input.name) (value: \(formattedString)), type: \(input.type))")
                                .frame(maxWidth:.infinity, alignment: .leading)
                            switch input.type {
                            case .float:
                                HStack {
                                    SliderControlView(input: input)
                                }.frame(maxWidth:.infinity, alignment: .leading)
                            case .statefulFloat:
                                HStack {
                                    StatefulFloatControlView(input: input)
                                }.frame(maxWidth:.infinity, alignment: .leading)
                            default:
                                Text("Default")
                            }
                        }.padding()
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(5)
                            .id(input.id)
                        Text(" ")
                    }
                }
                Spacer()
                
            }.padding(5)
                .font(myFont)
                
        }.onChange(of: audioMonitor.smoothedVolume) { oldValue, newValue in
            // This block runs every time smoothedVolume changes
            // You can update your inputs here if needed
            let startTime = DispatchTime.now()
            
            lastTickTime = Float(startTime.rawValue)
            // print("startTime: \(startTime) Tick duration: \(tickDuration)")
            currentScene.audioSignal = newValue
            currentScene.audioSignalRaw = audioMonitor.volume
            currentScene.audioSignalProcessed = currentProcessor.process(Double(newValue))
            
            currentScene.audioSignalLowpassRaw = audioMonitor.lowpassVolume
            currentScene.audioSignalLowpassSmoothed = audioMonitor.lowpassVolumeSmoothed
            
            // Adjusting the stateful floats
            for i in 0..<currentScene.inputs.count {
                if currentScene.inputs[i].type == .statefulFloat {
                    if let floatValue = currentScene.inputs[i].value as? Double {
                        currentScene.inputs[i].value = floatValue + currentScene.inputs[i].tickValueAdjustment +
                        currentScene.inputs[i].tickValueAudioAdjustment * (currentScene.audioSignalProcessed + currentScene.inputs[i].tickValueAudioAdjustmentOffset)
                    } else {
                        print("Could not cast value to Float for \(currentScene.inputs[i].value), actual type: \(type(of: currentScene.inputs[i].value))")
                    }
                }
            }
            
            currentScene.updateFloatInputsWithAudio(newValue)
            currentScene.setWrappedGeometries()
            
            let endTime = DispatchTime.now()
            // print("Duration to update scene: \(Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000)ms")
        }
    }
}
