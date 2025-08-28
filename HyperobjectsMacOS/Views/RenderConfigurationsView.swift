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
    
    @State private var camDistance: Float = 5.0
    
    @State private var binDepth: Float = 16
    
    var body: some View {
        VStack(alignment: .leading) {
            ScrollView {
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
                
                Text("Projection mix")
                Slider(value: $renderConfigurations.projectionMix, in: 0...1.0)
                
                Text("Camera Distance: \(String(format: "%.1f", renderConfigurations.cameraDistance))")
                Slider(value: $renderConfigurations.cameraDistance, in: 0...50.0)
                
                Text("Orthographic projection height: \(String(format: "%.1f", renderConfigurations.orthographicProjectionHeight))")
                Slider(value: $renderConfigurations.orthographicProjectionHeight, in: 0...10.0)
                
                Text("FOV Division: \(String(format: "%.1f", renderConfigurations.FOVDivision))")
                Slider(value: $renderConfigurations.FOVDivision, in: 0...10.0)
                
                
                Text("Bin visibility")
                Slider(value: $renderConfigurations.binVisibility, in: 0...10.0)
                
                Text("Bin grid visibility")
                Slider(value: $renderConfigurations.binGridVisibility, in: 0...1.0)
                
                Text("Bounding box visibility")
                Slider(value: $renderConfigurations.boundingBoxVisibility, in: 0...1.0)
                
                Text("Line color strength")
                Slider(value: $renderConfigurations.lineColorStrength, in: 0...1.0)
                
                Text("Line debug gradient strength")
                Slider(value: $renderConfigurations.lineTimeDebugGradientStrength, in: 0...1.0)
                
                Text("Line Time Debug Gradient Color Start")
                ColorPickerControlView(colorInput: renderConfigurations.lineTimeDebugStartGradientColor)
                
                Text("Line Time Debug Gradient Color End")
                ColorPickerControlView(colorInput: renderConfigurations.lineTimeDebugEndGradientColor)
                
                
                Text("Bin depth rendering")
                Slider(value: $binDepth,
                       in: 1.0...32.0,
                       step: 1
                ).onChange(of: binDepth) { oldValue, newValue in
                    renderConfigurations.binDepth = Int(newValue)
                }
                
                Text("Background color")
                ColorPickerControlView(colorInput: renderConfigurations.backgroundColor)
            }
        }.padding()
    }
}

