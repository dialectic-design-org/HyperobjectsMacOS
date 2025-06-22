//
//  SceneInputsView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 12/10/2024.
//

import SwiftUI

struct SceneInputsView: View {
    @EnvironmentObject var currentScene: GeometriesSceneBase
    @StateObject private var audioMonitor = AudioInputMonitor()
    
    var body: some View {
        VStack {
            Text("Scene inputs view")
            Text("Scene: \(currentScene.name)")
            Text("Inputs count: \(currentScene.inputs.count)")
            Text("TODO IMPLEMENT")
            List(currentScene.inputs) { input in
                let formattedString = String(format: "%.2f", input.valueAsFloat())
                Text("\(input.name) (value: \(formattedString)), type: \(input.type))")
                switch input.type {
                case .float:
                    HStack {
                        SliderControlView(input: input)
                    }
                default:
                    Text("Default")
                }
            }
            Rectangle()
                .fill(Color(
                    hue: Double(1.0 - audioMonitor.smoothedVolume),
                    saturation: Double(0.0 + audioMonitor.smoothedVolume),
                    brightness: Double(0.0 + audioMonitor.smoothedVolume)
                ))
                .frame(width: CGFloat(500 - (audioMonitor.smoothedVolume * 500)), height: 20)
                .onAppear {
                    audioMonitor.startMonitoring()
                }
                .onDisappear() {
                    audioMonitor.stopMonitoring()
                }
        }.font(myFont)
        .onChange(of: audioMonitor.smoothedVolume) { oldValue, newValue in
            // This block runs every time smoothedVolume changes
            print("smoothedVolume changed from \(oldValue) to \(newValue)")
            // You can update your inputs here if needed
            for (index, input) in currentScene.inputs.enumerated() {
                // update audioSignal per input if of type float
                if input.type == .float {
                    // currentScene.inputs[index].value = newValue
                    currentScene.inputs[index].audioSignal = newValue
                    currentScene.setChangedInput(name: input.name)
                    currentScene.setWrappedGeometries()
                }
            }
        }
    }
}
