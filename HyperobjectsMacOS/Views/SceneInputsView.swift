//
//  SceneInputsView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 12/10/2024.
//

import SwiftUI
import UniformTypeIdentifiers


var lastTickTime: Float = 0

struct SceneInputsView: View {
    @EnvironmentObject var currentScene: GeometriesSceneBase
    @EnvironmentObject var audioMonitor: AudioInputMonitor
    @StateObject private var sigmoidEnvelope = SigmoidEnvelope()
    @StateObject private var freeformEnvelope = FreeformEnvelope()    
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
                                                                isExpanded: false
                                                               ), at: 0)
            }
        }
        return .constant(SceneInputGroup(name: name, isVisible: true, isExpanded: false))
    }
    
    
    var body: some View {
        let generalInputs = groupedInputs[""] ?? []
        let declaredGroups = currentScene.inputGroups.filter { !$0.name.isEmpty }
        
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                CodeFileSelector()
                RealtimePanel(
                    currentScene: currentScene,
                    audioMonitor: audioMonitor,
                    selectedEnvelopeType: $selectedEnvelopeType,
                    sigmoidEnvelope: sigmoidEnvelope,
                    freeformEnvelope: freeformEnvelope
                )
                InputsGrid(
                    inputs: currentScene.inputs,
                    groups: $currentScene.inputGroups
                )
                .equatable()
                
            }.padding(5)
                .font(myFont)
                
        }.onChange(of: audioMonitor.smoothedVolume) { oldValue, newValue in
            // This block runs every time smoothedVolume changes
            // You can update your inputs here if needed
            let startTime = DispatchTime.now()
            
            lastTickTime = Float(startTime.rawValue)

            for i in 0..<currentScene.inputs.count {
                if currentScene.inputs[i].type == .statefulFloat {
                    // Extract history audio signal from audioSignalProcessedHistory based on inputs[i].audioDelay range from 0 to 1
                    let audioDelay = currentScene.inputs[i].audioDelay
                    
                    let historyLength = currentScene.audioSignalProcessedHistory.count
                    let maxHistoryIndex = max(0, historyLength - 1)
                    
                    // Map audioDelay (0-1) to history array index (0 to current length - 1)
                    // audioDelay of 0 = most recent (last element), audioDelay of 1 = oldest available
                    let delayIndex = Int(audioDelay * Float(maxHistoryIndex))
                    let clampedIndex = min(max(0, delayIndex), maxHistoryIndex)
                    
                    // Get the historical audio signal value (index from end of array)
                    let historicalAudioSignal: Double
                    if historyLength > 0 {
                        let arrayIndex = max(0, historyLength - 1 - clampedIndex)
                        historicalAudioSignal = currentScene.audioSignalProcessedHistory[arrayIndex]
                    } else {
                        // Fallback to current signal if no history available
                        historicalAudioSignal = currentScene.audioSignalProcessed
                    }
                    
                    // print(currentScene.inputs[i].name, audioDelay, delayIndex, clampedIndex, historicalAudioSignal)
                    
                    if let floatValue = currentScene.inputs[i].value as? Double {
                        currentScene.inputs[i].value = floatValue + currentScene.inputs[i].tickValueAdjustment +
                        currentScene.inputs[i].tickValueAudioAdjustment * (historicalAudioSignal + currentScene.inputs[i].tickValueAudioAdjustmentOffset)
                    } else {
                        print("Could not cast value to Float for \(currentScene.inputs[i].value), actual type: \(type(of: currentScene.inputs[i].value))")
                    }
                }
            }

            currentScene.updateFloatInputsWithAudio(newValue, audioMonitor: audioMonitor)
            currentScene.setWrappedGeometries()

            let endTime = DispatchTime.now()
            // print("Duration to update scene: \(Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000)ms")
        }
        
    }
}

/**
 
 .onChange(of: audioMonitor.smoothedVolume) { oldValue, newValue in
     // This block runs every time smoothedVolume changes
     // You can update your inputs here if needed
     let startTime = DispatchTime.now()
     
     lastTickTime = Float(startTime.rawValue)

     for i in 0..<currentScene.inputs.count {
         if currentScene.inputs[i].type == .statefulFloat {
             // Extract history audio signal from audioSignalProcessedHistory based on inputs[i].audioDelay range from 0 to 1
             let audioDelay = currentScene.inputs[i].audioDelay
             
             let historyLength = currentScene.audioSignalProcessedHistory.count
             let maxHistoryIndex = max(0, historyLength - 1)
             
             // Map audioDelay (0-1) to history array index (0 to current length - 1)
             // audioDelay of 0 = most recent (last element), audioDelay of 1 = oldest available
             let delayIndex = Int(audioDelay * Float(maxHistoryIndex))
             let clampedIndex = min(max(0, delayIndex), maxHistoryIndex)
             
             // Get the historical audio signal value (index from end of array)
             let historicalAudioSignal: Double
             if historyLength > 0 {
                 let arrayIndex = max(0, historyLength - 1 - clampedIndex)
                 historicalAudioSignal = currentScene.audioSignalProcessedHistory[arrayIndex]
             } else {
                 // Fallback to current signal if no history available
                 historicalAudioSignal = currentScene.audioSignalProcessed
             }
             
             // print(currentScene.inputs[i].name, audioDelay, delayIndex, clampedIndex, historicalAudioSignal)
             
             if let floatValue = currentScene.inputs[i].value as? Double {
                 currentScene.inputs[i].value = floatValue + currentScene.inputs[i].tickValueAdjustment +
                 currentScene.inputs[i].tickValueAudioAdjustment * (historicalAudioSignal + currentScene.inputs[i].tickValueAudioAdjustmentOffset)
             } else {
                 print("Could not cast value to Float for \(currentScene.inputs[i].value), actual type: \(type(of: currentScene.inputs[i].value))")
             }
         }
     }

     currentScene.updateFloatInputsWithAudio(newValue, audioMonitor: audioMonitor)
     currentScene.setWrappedGeometries()

     let endTime = DispatchTime.now()
     // print("Duration to update scene: \(Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000)ms")
 }
 
 
 */
