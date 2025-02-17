//
//  RenderView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 12/10/2024.
//

import SwiftUI

struct RenderView: View {
    @EnvironmentObject var currentScene: GeometriesSceneBase
    @State private var resolutionMode: ResolutionMode = .fixed
    @State private var resolution: CGSize = CGSize(width: 1000, height: 1000) // Default resolution
    @State private var renderPoints: Bool = false
    @State private var renderLines: Bool = false
    
    var body: some View {
        let geometries = currentScene.generateAllGeometries()
        ZStack(alignment: .topLeading) {
            MetalView(resolutionMode: $resolutionMode, resolution: $resolution)

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
                
            }.padding(8)
        }.font(myFont)
    }
}
//
//#Preview {
//    var currentScene = generateGeometrySceneCircle()
//    RenderView().environmentObject(currentScene)
//}
