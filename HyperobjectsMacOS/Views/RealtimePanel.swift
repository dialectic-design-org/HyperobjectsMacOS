//
//  RealtimePanel.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 17/09/2025.
//

import SwiftUI

struct RealtimePanel: View {
    @ObservedObject var currentScene: GeometriesSceneBase
    @StateObject var audioMonitor: AudioInputMonitor
    @Binding var selectedEnvelopeType: EnvelopeType
    var sigmoidEnvelope: SigmoidEnvelope
    var freeformEnvelope: FreeformEnvelope
    
    var currentProcessor: EnvelopeProcessor {
        selectedEnvelopeType == .sigmoid ? sigmoidEnvelope : freeformEnvelope
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            // visualizers; bind only to values they need
            Rectangle()
                .fill(Color(
                    hue: Double(1.0 - audioMonitor.smoothedVolume),
                    saturation: Double(audioMonitor.smoothedVolume),
                    brightness: Double(audioMonitor.smoothedVolume)
                ))
                .frame(width: CGFloat(500 - (audioMonitor.smoothedVolume * 500)), height: 10)
                .cornerRadius(5)
                .onAppear { audioMonitor.startMonitoring() }
                .onDisappear { audioMonitor.stopMonitoring() }

            AudioTimelineView(currentScene: currentScene, audioMonitor: audioMonitor)

            HStack {
                AudioVisualizerView(
                    currentVolume: Double(audioMonitor.volume),
                    smoothedVolume: Double(audioMonitor.smoothedVolume),
                    processedVolume: currentScene.audioSignalProcessed,
                    title: "Full"
                )
                AudioVisualizerView(
                    currentVolume: Double(currentScene.audioSignalLowpassRaw),
                    smoothedVolume: Double(currentScene.audioSignalLowpassSmoothed),
                    processedVolume: currentScene.audioSignalLowpassProcessed,
                    title: "Lowpass"
                )
            }

            EnvelopeSwitcher(
                selectedEnvelopeType: $selectedEnvelopeType,
                sigmoidEnvelope: sigmoidEnvelope,
                freeformEnvelope: freeformEnvelope,
                input: Double(audioMonitor.smoothedVolume),
                output: currentScene.audioSignalProcessed
            )
        }
        .onChange(of: audioMonitor.smoothedVolume) { _, _ in
            let snap = AudioSnapshot(
                raw: audioMonitor.volume,
                smoothed: audioMonitor.smoothedVolume,
                smoothedPerStep: audioMonitor.smoothedVolumes,
                lowpassRaw: Float(audioMonitor.lowpassVolume),
                lowpassSmoothed: Float(audioMonitor.lowpassVolume)
            )
            currentScene.applyAudioTick(snap, using: currentProcessor)
        }
    }
}

struct EnvelopeSwitcher: View {
    @Binding var selectedEnvelopeType: EnvelopeType
    let sigmoidEnvelope: SigmoidEnvelope
    let freeformEnvelope: FreeformEnvelope
    let input: Double
    let output: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Envelope", selection: $selectedEnvelopeType) {
                Text("Sigmoid").tag(EnvelopeType.sigmoid)
                Text("Freeform").tag(EnvelopeType.freeform)
            }
            .pickerStyle(.segmented)

            Group {
                switch selectedEnvelopeType {
                case .sigmoid:
                    SigmoidEnvelopeView(
                        envelope: sigmoidEnvelope,
                        currentInput: input,
                        currentOutput: output,
                        selectedEnvelopeType: $selectedEnvelopeType
                    )
                case .freeform:
                    FreeformEnvelopeView(
                        envelope: freeformEnvelope,
                        currentInput: input,
                        currentOutput: output,
                        selectedEnvelopeType: $selectedEnvelopeType
                    )
                }
            }
            .id(selectedEnvelopeType) // stable subtree per mode
        }
        .transaction { $0.disablesAnimations = true } // avoid tick-time layout churn
    }
}
