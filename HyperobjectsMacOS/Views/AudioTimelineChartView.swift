//
//  AudioHistoryView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 28/06/2025.
//


import SwiftUI

struct AudioTimelineChartView: View {
    let historyData: [AudioDataPoint]
    
    @State private var timeWindowSeconds: Double = 10.0 // Fixed 30-second window
    private let padding: CGFloat = 8
    
    let timeWindowSecondsOptions: [Double] = [5, 10, 30]
    
    // Computed properties for coordinate conversion
    private var currentTime: Double {
        historyData.last?.timestamp ?? 0
    }
    
    private var startTime: Double {
        currentTime - timeWindowSeconds
    }
    
    private func timeToX(_ timestamp: Double, in rect: CGRect) -> CGFloat {
        let normalizedTime = (timestamp - startTime) / timeWindowSeconds
        return rect.minX + CGFloat(normalizedTime) * rect.width
    }
    
    private func volumeToY(_ volume: Double, in rect: CGRect) -> CGFloat {
        return rect.maxY - CGFloat(volume) * rect.height
    }
    
    var body: some View {
        VStack(alignment: .trailing) {
            HStack {
                ForEach(timeWindowSecondsOptions, id: \.self) { option in
                    Button("seconds: \(Int(option))") {
                        timeWindowSeconds = option
                    }.controlSize(.small)
                        .fontDesign(.monospaced)
                }
            }.padding(8)
            Canvas { context, size in
                let drawingRect = CGRect(
                    x: padding,
                    y: padding,
                    width: size.width - padding * 2,
                    height: size.height - padding * 2
                )

                // Background grid
                var gridPath = Path()
                // Horizontal lines (volume levels)
                for i in 0...4 {
                    let y = drawingRect.minY + CGFloat(i) * drawingRect.height / 4
                    gridPath.move(to: CGPoint(x: drawingRect.minX, y: y))
                    gridPath.addLine(to: CGPoint(x: drawingRect.maxX, y: y))
                }
                // Vertical lines (time intervals)
                for i in 0...6 {
                    let x = drawingRect.minX + CGFloat(i) * drawingRect.width / 6
                    gridPath.move(to: CGPoint(x: x, y: drawingRect.minY))
                    gridPath.addLine(to: CGPoint(x: x, y: drawingRect.maxY))
                }
                context.stroke(gridPath, with: .color(.gray.opacity(0.3)), lineWidth: 0.5)

                if !historyData.isEmpty {
                    let filteredData = historyData.filter { $0.timestamp >= startTime }

                    // Pixel-aware downsampling
                    let maxPoints = max(1, Int(drawingRect.width))
                    let sampleStride = max(1, filteredData.count / maxPoints)
                    let sampledData: [AudioDataPoint]
                    if sampleStride > 1 {
                        sampledData = stride(from: 0, to: filteredData.count, by: sampleStride).map { filteredData[$0] }
                    } else {
                        sampledData = filteredData
                    }

                    // Single-pass path construction for all 3 lines
                    var rawPath = Path()
                    var smoothedPath = Path()
                    var processedPath = Path()

                    for (i, dp) in sampledData.enumerated() {
                        let x = timeToX(dp.timestamp, in: drawingRect)
                        let rawY = volumeToY(dp.rawVolume, in: drawingRect)
                        let smoothedY = volumeToY(dp.smoothedVolume, in: drawingRect)
                        let processedY = volumeToY(dp.processedVolume, in: drawingRect)

                        if i == 0 {
                            rawPath.move(to: CGPoint(x: x, y: rawY))
                            smoothedPath.move(to: CGPoint(x: x, y: smoothedY))
                            processedPath.move(to: CGPoint(x: x, y: processedY))
                        } else {
                            rawPath.addLine(to: CGPoint(x: x, y: rawY))
                            smoothedPath.addLine(to: CGPoint(x: x, y: smoothedY))
                            processedPath.addLine(to: CGPoint(x: x, y: processedY))
                        }
                    }

                    context.stroke(rawPath, with: .color(.red.opacity(0.8)), lineWidth: 1.5)
                    context.stroke(smoothedPath, with: .color(.orange.opacity(0.8)), lineWidth: 1.5)
                    context.stroke(processedPath, with: .color(.green.opacity(0.8)), lineWidth: 1.5)

                    // Current time indicator
                    var indicatorPath = Path()
                    let currentX = timeToX(currentTime, in: drawingRect)
                    indicatorPath.move(to: CGPoint(x: currentX, y: drawingRect.minY))
                    indicatorPath.addLine(to: CGPoint(x: currentX, y: drawingRect.maxY))
                    context.stroke(indicatorPath, with: .color(.blue.opacity(0.6)), lineWidth: 2)
                }
            }
        }
    }
}
