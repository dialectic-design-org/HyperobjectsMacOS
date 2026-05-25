//
//  RenderView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 12/10/2024.
//

import SwiftUI

struct RenderView: View {
    @EnvironmentObject var currentScene: GeometriesSceneBase
    @EnvironmentObject var renderConfigs: RenderConfigurations
    @EnvironmentObject var videoStreamManager: VideoStreamManager
    @EnvironmentObject var bandFieldManager: BandFieldManager
    @StateObject private var rendererState = RendererState()
    @StateObject private var geometryVM = SceneGeometryViewModel()
    @State private var resolutionMode: ResolutionMode = .fixed
    @State private var resolution: CGSize = CGSize(width: 1000, height: 1000) // Default resolution
    @State private var renderPoints: Bool = false
    @State private var renderLines: Bool = false
    var body: some View {
        ZStack(alignment: .topLeading) {
            MetalView(
                rendererState: rendererState,
                currentScene: currentScene,
                renderConfigs: renderConfigs,
                videoStreamManager: videoStreamManager,
                bandFieldManager: bandFieldManager,
                resolutionMode: $resolutionMode,
                resolution: $resolution
            ).frame(minWidth: 300, minHeight: 300)


            if renderConfigs.showSquareBounds {
                GeometryReader { geometry in
                    let size = min(geometry.size.width, geometry.size.height)
                    Rectangle()
                        .stroke(Color.yellow, lineWidth: 1)
                        .frame(width: size, height: size)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
            }

            if renderConfigs.showOverlay {
                VStack(alignment: .leading) {
                    Text("RENDER VIEW").fontWeight(.bold)
                    HStack {
                        Text("Current scene:")
                        Text("\(currentScene.name)").fontWeight(.bold)
                    }
                    Text("geometries count: \(geometryVM.geometries.count)")


                    FrameMetricsView(
                        timingManager: rendererState.frameTimingManager
                    )
                    RenderStageMetricsView(rendererState: rendererState)

                }.padding(8)
            }
        }
        .font(myFont)
        .onAppear { geometryVM.bind(to: currentScene) }
        .onChange(of: ObjectIdentifier(currentScene)) { _, _ in
            geometryVM.bind(to: currentScene)
        }
    }
}
//
//#Preview {
//    var currentScene = generateGeometrySceneCircle()
//    RenderView().environmentObject(currentScene)
//}
