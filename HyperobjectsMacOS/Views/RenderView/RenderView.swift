//
//  RenderView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 12/10/2024.
//

import SwiftUI

struct RenderView: View {
    @EnvironmentObject var currentScene: GeometriesSceneBase
    @StateObject private var rendererState = RendererState()
    @State private var resolutionMode: ResolutionMode = .fixed
    @State private var resolution: CGSize = CGSize(width: 1000, height: 1000) // Default resolution
    @State private var renderPoints: Bool = false
    @State private var renderLines: Bool = false
    
    @StateObject private var timingManager = FrameTimingManager()
    
    var body: some View {
        let geometries = currentScene.generateAllGeometries()
        ZStack(alignment: .topLeading) {
            MetalView(
                rendererState: rendererState,
                resolutionMode: $resolutionMode,
                resolution: $resolution,
                timingManager: timingManager
            )

            VStack(alignment: .leading) {
                Text("RENDER VIEW").fontWeight(.bold)
                HStack {
                    Text("Current scene:")
                    Text("\(currentScene.name)").fontWeight(.bold)
                }
                Text("geometries count: \(geometries.count)")
                
                Picker("Resolution mode", selection: $resolutionMode) {
                    Text("Fixed").tag(ResolutionMode.fixed)
                    Text("Dynamic").tag(ResolutionMode.dynamic)
                }.pickerStyle(SegmentedPickerStyle()).fixedSize()
                
                Picker("Resolution", selection: $resolution) {
                    Text("1000 x 1000").tag(CGSize(width: 1000, height: 1000))
                    Text("2000 x 2000").tag(CGSize(width: 2000, height: 2000))
                    Text("1920 x 1080").tag(CGSize(width: 1920, height: 1080))
                }.pickerStyle(SegmentedPickerStyle()).fixedSize()
                
                FrameTimeChart(data: timingManager.frameTimes)
                Text("Frame Time average: \(timingManager.averageFrameTime, specifier: "%.2f") ms - Max: \(timingManager.frameTimes.max() ?? 0, specifier: "%.2f") ms  (over \(timingManager.frameTimes.count) frames)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("FPS: \(1000 / max(0.1, timingManager.averageFrameTime), specifier: "%.1f")")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
            }.padding(8)
        }.font(myFont)
    }
}
//
//#Preview {
//    var currentScene = generateGeometrySceneCircle()
//    RenderView().environmentObject(currentScene)
//}
