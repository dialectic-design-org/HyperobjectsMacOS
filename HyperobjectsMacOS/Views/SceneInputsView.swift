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
    

    
    private var groupedInputs: [String: [SceneInput]] {
        Dictionary(grouping: currentScene.inputs,
                   by: { ($0.inputGroupName ?? "").trimmingCharacters(in: .whitespaces) })
    }
    
    private func bindingForGroup(named name: String) -> Binding<SceneInputGroup> {
        if let index = currentScene.inputGroups.firstIndex(where: { $0.name == name }) {
            return $currentScene.inputGroups[index]
        }
        DispatchQueue.main.async {
            if !currentScene.inputGroups.contains(where: {$0.name == name }) {
                currentScene.inputGroups.insert(SceneInputGroup(name: name.isEmpty ? "" : name,
                                                                note: name.isEmpty ? "Ungrouped inputs" : nil,
                                                                background: .secondary,
                                                                isVisible: true,
                                                                isExpanded: true
                                                               ), at: 0)
            }
        }
        return .constant(SceneInputGroup(name: name, isVisible: true, isExpanded: true))
    }
    
    
    var body: some View {
        let generalInputs = groupedInputs[""] ?? []
        let declaredGroups = currentScene.inputGroups.filter { !$0.name.isEmpty }
        
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
                        .cornerRadius(5.0)
                        .onAppear {
                            audioMonitor.startMonitoring()
                        }
                        .onDisappear() {
                            audioMonitor.stopMonitoring()
                        }
                    
                    AudioTimelineView(currentScene: currentScene, audioMonitor: audioMonitor)
                    
                    
                    
                    
                    HStack {
                        VStack {
                            AudioVisualizerView(
                                currentVolume: Double(currentScene.audioSignalRaw),
                                smoothedVolume: Double(currentScene.audioSignal),
                                processedVolume: currentScene.audioSignalProcessed,
                                title: "Full"
                            )
                        }
                        VStack {
                            AudioVisualizerView(
                                currentVolume: Double(currentScene.audioSignalLowpassRaw),
                                smoothedVolume: Double(currentScene.audioSignalLowpassSmoothed),
                                processedVolume: currentScene.audioSignalLowpassProcessed,
                                title: "Lowpass"
                            )
                        }
                    }
                    
                    
                    
//                    Button(action: {
//                        showSliders.toggle()
//                    }) {
//                        Text(showSliders ? "Hide Sliders" : "Show Sliders")
//                    }
                    
                    VStack {
                        
                        switch selectedEnvelopeType {
                        case .sigmoid:
                            SigmoidEnvelopeView(
                                envelope: sigmoidEnvelope,
                                currentInput: Double(currentScene.audioSignal),
                                currentOutput: currentScene.audioSignalProcessed,
                                selectedEnvelopeType: $selectedEnvelopeType
                            )
                        case .freeform:
                            FreeformEnvelopeView(
                                envelope: freeformEnvelope,
                                currentInput: Double(currentScene.audioSignal),
                                currentOutput: currentScene.audioSignalProcessed,
                                selectedEnvelopeType: $selectedEnvelopeType
                            )
                        }
                    }
                    
                }
                HStack(alignment: .top, spacing: 4) {
                    if !generalInputs.isEmpty || true {
                        let gBinding = bindingForGroup(named: "")
                        InputGroupColumn(group: gBinding,
                                         inputs: generalInputs,
                                         titleOverride: "General")
                    }
                
                    ForEach($currentScene.inputGroups.indices.filter { currentScene.inputGroups[$0].name != ""}, id: \.self) { idx in
                        let g = $currentScene.inputGroups[idx]
                        let name = g.wrappedValue.name
                        let inputs = groupedInputs[name] ?? []
                        InputGroupColumn(
                            group: g,
                            inputs: inputs,
                            titleOverride: nil
                        )
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
