//
//  GeometriesListView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 14/10/2024.
//

import SwiftUI

struct GeometriesListView: View {
    @EnvironmentObject var currentScene: GeometriesSceneBase
    var body: some View {
        VStack {
            List(currentScene.cachedGeometries) { geometry in
                HStack {
                    Text(geometry.id.uuidString)
                    Text("Type")
                    switch geometry.geometry.type {
                    case .line:
                        Text("Line")
                    default:
                        Text("Unspecified type")
                    }
                }.font(myFont)
            }
        }
    }
}
