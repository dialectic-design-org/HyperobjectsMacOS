//
//  FrameMetricsView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 13/06/2025.
//

import SwiftUI

struct FrameMetricsView: View {
    @ObservedObject var timingManager: FrameTimingManager
    
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Frame Time: ")
                    .font(.system(size: 12, weight: .medium))
                Text("\(String(format: "%.2f", timingManager.averageFrameTime)) ms")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(timingManager.averageFrameTime < 16.7 ? .green : .red)
            }
            HStack {
                Text("Max: ")
                    .font(.system(size: 12, weight: .medium))
                Text("\(String(format: "%.2f", timingManager.frameTimes.max() ?? 0.0)) ms")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(timingManager.frameTimes.max() ?? 0.0 < 16.7 ? .green : .red)
            }
            HStack {
                Text("FPS:")
                    .font(.system(size: 12, weight: .medium))
                Text("\(String(format: "%.1f", timingManager.framePerSecond))")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(timingManager.framePerSecond > 58 ? .green : .red)
            }
            FrameTimeChart(data: timingManager.frameTimes)

        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
        .frame(maxWidth: 250)
    }
}
