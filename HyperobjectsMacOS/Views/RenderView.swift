//
//  RenderView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 12/10/2024.
//

import SwiftUI

struct RenderView: View {
    @EnvironmentObject var currentScene: GeometriesSceneBase
    var body: some View {
        let geometries = currentScene.generateAllGeometries()
        VStack {
            Text("RENDER VIEW").fontWeight(.bold)
            Text("Current scene:")
            Text("\(currentScene.name)")
            Text("geometries count: \(geometries.count)")
        }.font(myFont)
    }
}

#Preview {
    var currentScene = generateGeometrySceneCircle()
    RenderView().environmentObject(currentScene)
}
