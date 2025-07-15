//
//  RencerConfigurationsView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 28/10/2024.
//

import SwiftUI

struct RenderConfigurationsView: View {
    @EnvironmentObject var sceneManager: SceneManager
    @EnvironmentObject var renderConfigurations: RenderConfigurations
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Render Configurations view")
            Toggle(
                "Render Points",
                isOn: $renderConfigurations.renderPoints
            )
            
            Toggle(
                "Render SDF Lines",
                isOn: $renderConfigurations.renderSDFLines
            )
            
            Toggle(
                "Render Lines Overlay",
                isOn: $renderConfigurations.renderLinesOverlay
            )
            
            Toggle(
                "Show overlay",
                isOn: $renderConfigurations.showOverlay
            )
        }
    }
}

