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



    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                CodeFileSelector()
                RealtimePanel(
                    currentScene: currentScene,
                    audioMonitor: audioMonitor,
                    selectedEnvelopeType: $currentScene.selectedEnvelopeType,
                    sigmoidEnvelope: currentScene.sigmoidEnvelope,
                    freeformEnvelope: currentScene.freeformEnvelope
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
