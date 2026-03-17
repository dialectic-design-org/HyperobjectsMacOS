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
    

    
    var body: some View {
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
                    structuralSignature: currentScene.inputs.structuralSignature,
                    inputs: currentScene.inputs,
                    groups: $currentScene.inputGroups
                )
                .equatable()
                
            }.padding(5)
                .font(myFont)
                
        }
        
    }
}
