//
//  AudioVisualizerView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 28/06/2025.
//

import SwiftUI

struct AudioVisualizerView: View {
    let currentVolume: Double
    let smoothedVolume: Double
    let processedVolume: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Audio Levels")
                .font(.headline)
            
            VStack(spacing: 8) {
                AudioLevelBar(label: "Raw", value: currentVolume, color: .red)
                AudioLevelBar(label: "Smoothed", value: smoothedVolume, color: .orange)
                AudioLevelBar(label: "Processed", value: processedVolume, color: .green)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}
