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
    @State private var showSliders: Bool = true
    
    var body: some View {
        VStack {
            Rectangle()
                .fill(Color(
                    hue: Double(1.0 - audioMonitor.smoothedVolume),
                    saturation: Double(0.0 + audioMonitor.smoothedVolume),
                    brightness: Double(0.0 + audioMonitor.smoothedVolume)
                ))
                .frame(width: CGFloat(500 - (audioMonitor.smoothedVolume * 500)), height: 10)
                .onAppear {
                    audioMonitor.startMonitoring()
                }
                .onDisappear() {
                    audioMonitor.stopMonitoring()
                }
            Button(action: {
                showSliders.toggle()
            }) {
                Text(showSliders ? "Hide Sliders" : "Show Sliders")
            }
            .padding()
            if showSliders {
                List(currentScene.inputs) { input in
                    VStack {
                        let formattedString = String(format: "%.2f", input.valueAsFloat())
                        Text("\(input.name) (value: \(formattedString)), type: \(input.type))")
                            .frame(maxWidth:.infinity, alignment: .leading)
                        switch input.type {
                        case .float:
                            HStack {
                                SliderControlView(input: input)
                            }.frame(maxWidth:.infinity, alignment: .leading)
                        default:
                            Text("Default")
                        }
                    }.padding(EdgeInsets(
                        top: 0,
                        leading: 0,
                        bottom: 30,
                        trailing: 0
                    ))
                    .id(input.id)
                }
            }
            
        }.font(myFont)
        .onChange(of: audioMonitor.smoothedVolume) { oldValue, newValue in
            // This block runs every time smoothedVolume changes
            // You can update your inputs here if needed
            let startTime = DispatchTime.now()
            currentScene.audioSignal = newValue
            currentScene.updateFloatInputsWithAudio(newValue)
            currentScene.setWrappedGeometries()
            let endTime = DispatchTime.now()
            // print("Duration to update scene: \(Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000)ms")
        }
    }
}
