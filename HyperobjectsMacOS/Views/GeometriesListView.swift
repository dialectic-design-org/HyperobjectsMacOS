//
//  GeometriesListView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 14/10/2024.
//

import SwiftUI

struct GeometriesListView: View {
    @EnvironmentObject var currentScene: GeometriesSceneBase
    @StateObject private var geometryVM = SceneGeometryViewModel()

    var body: some View {
        VStack {
            List(geometryVM.geometries) { geometry in
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
        .onAppear { geometryVM.bind(to: currentScene) }
        .onChange(of: ObjectIdentifier(currentScene)) { _, _ in
            geometryVM.bind(to: currentScene)
        }
    }
}
