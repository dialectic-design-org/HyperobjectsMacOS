//
//  AudioTimelineView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 06/09/2025.
//

import SwiftUI

struct AudioTimelineView: View {
    @ObservedObject var currentScene: GeometriesSceneBase
    var audioMonitor: AudioInputMonitor
    @StateObject private var viewModel = AudioTimelineViewModel()
    @State private var timeWindowSeconds: Double = 30.0
    
    let smoothingSampleCountOptions = [
        1,
        2,
        5,
        10,
        20,
        50,
        100
    ]
    
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Audio Timeline")
                    .font(.headline)
                    .fontDesign(.monospaced)
                Spacer()
                HStack {
                    Text("Smoothing: ")
                    ForEach(smoothingSampleCountOptions, id: \.self) { count in
                        Button("\(count)") {
                            audioMonitor.smoothingSampleCount = count
                        }
                    }
                }
            }
            
            // let cutoff = (currentScene.audioHistory.suffix(1).first?.timestamp ?? 0.0) - 30.0
            // let historySnapshot = currentScene.historyData(since: cutoff)

            AudioTimelineChartView(historyData: viewModel.historySnapshot)
                .frame(height: 220)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

            // Legend
            HStack(spacing: 20) {
                LegendItem(color: .red, label: "Raw")
                LegendItem(color: .orange, label: "Smoothed")
                LegendItem(color: .green, label: "Processed")

                Spacer()

                Text("\(viewModel.historySnapshot.count) samples")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
        .onAppear {
            viewModel.bind(to: currentScene, windowSeconds: timeWindowSeconds)
        }
        .onChange(of: ObjectIdentifier(currentScene)) { _, _ in
            viewModel.bind(to: currentScene, windowSeconds: timeWindowSeconds)
        }
    }
}
