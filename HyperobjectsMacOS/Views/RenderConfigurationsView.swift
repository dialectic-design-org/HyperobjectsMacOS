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
        VStack {
            Text("Render Configurations view")
        }
    }
}

