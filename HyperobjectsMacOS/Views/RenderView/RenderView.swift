//
//  RenderView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 12/10/2024.
//

import SwiftUI

struct RenderView: View {
    /// Which live-code overlay this render view shows (editable in the main window, a
    /// read-only mirror in the secondary window).
    var codeOverlayRole: CodeOverlayRole = .none
    @EnvironmentObject var currentScene: GeometriesSceneBase
    @EnvironmentObject var renderConfigs: RenderConfigurations
    @EnvironmentObject var videoStreamManager: VideoStreamManager
    @EnvironmentObject var bandFieldManager: BandFieldManager
    // Plain environment reference (not @EnvironmentObject), so keystrokes in the editor don't
    // re-run RenderView.body; only LiveCodeOverlay observes the session. nil = no overlay.
    @Environment(\.liveCodeSession) private var liveCodeSession
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
                liveCodeOverlayState: liveCodeSession?.overlayState,
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

            if renderConfigs.showOverlay && !(renderConfigs.showCodeOverlay && codeOverlayRole == .editor) {
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

            // In burned-in mode the mirror's own renderer draws the code, so no SwiftUI layer.
            if let liveCodeSession, renderConfigs.showCodeOverlay && codeOverlayRole != .none
                && !(renderConfigs.codeOverlayOutput == .burnedIn && codeOverlayRole == .mirror) {
                LiveCodeOverlay(
                    session: liveCodeSession,
                    role: codeOverlayRole,
                    output: renderConfigs.codeOverlayOutput,
                    features: LiveCodeOverlayFeatures(
                        lineNumbers: renderConfigs.showCodeLineNumbers,
                        console: renderConfigs.showCodeConsole,
                        inputReadout: renderConfigs.showCodeInputReadout
                    )
                )
            }

            // Audio envelope preview, top right. Main window only: the mirror window is what
            // the audience sees. Drawn by layers on a timer, so it adds no SwiftUI updates.
            if renderConfigs.showAudioEnvelopePreview && codeOverlayRole != .mirror {
                AudioEnvelopePreview(scene: currentScene)
                    .frame(width: AudioEnvelopePreviewView.preferredSize.width,
                           height: AudioEnvelopePreviewView.preferredSize.height)
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .allowsHitTesting(false)
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
