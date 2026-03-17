//
//  SceneInputsView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 12/10/2024.
//

import SwiftUI
import UniformTypeIdentifiers


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
                
        }
        
    }
}
