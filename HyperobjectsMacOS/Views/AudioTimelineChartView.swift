//
//  AudioHistoryView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 28/06/2025.
//


import SwiftUI

struct AudioTimelineChartView: View {
    let historyData: [AudioDataPoint]
    
    @State private var timeWindowSeconds: Double = 30.0 // Fixed 30-second window
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
                }
            }.padding(8)
            GeometryReader { geometry in
                let drawingRect = CGRect(
                    x: padding,
                    y: padding,
                    width: geometry.size.width - padding * 2,
                    height: geometry.size.height - padding * 2
                )
                
                ZStack {
                    // Background grid
                    Path { path in
                        // Horizontal lines (volume levels)
                        for i in 0...4 {
                            let y = drawingRect.minY + CGFloat(i) * drawingRect.height / 4
                            path.move(to: CGPoint(x: drawingRect.minX, y: y))
                            path.addLine(to: CGPoint(x: drawingRect.maxX, y: y))
                        }
                        
                        // Vertical lines (time intervals)
                        for i in 0...6 {
                            let x = drawingRect.minX + CGFloat(i) * drawingRect.width / 6
                            path.move(to: CGPoint(x: x, y: drawingRect.minY))
                            path.addLine(to: CGPoint(x: x, y: drawingRect.maxY))
                        }
                    }
                    .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                    
                    if !historyData.isEmpty {
                        let filteredData = historyData.filter { $0.timestamp >= startTime }
                        
                        // Raw volume line
                        Path { path in
                            for (index, dataPoint) in filteredData.enumerated() {
                                let point = CGPoint(
                                    x: timeToX(dataPoint.timestamp, in: drawingRect),
                                    y: volumeToY(dataPoint.rawVolume, in: drawingRect)
                                )
                                
                                if index == 0 {
                                    path.move(to: point)
                                } else {
                                    path.addLine(to: point)
                                }
                            }
                        }
                        .stroke(Color.red.opacity(0.8), lineWidth: 1.5)
                        
                        // Smoothed volume line
                        Path { path in
                            for (index, dataPoint) in filteredData.enumerated() {
                                let point = CGPoint(
                                    x: timeToX(dataPoint.timestamp, in: drawingRect),
                                    y: volumeToY(dataPoint.smoothedVolume, in: drawingRect)
                                )
                                
                                if index == 0 {
                                    path.move(to: point)
                                } else {
                                    path.addLine(to: point)
                                }
                            }
                        }
                        .stroke(Color.orange.opacity(0.8), lineWidth: 1.5)
                        
                        // Processed volume line
                        Path { path in
                            for (index, dataPoint) in filteredData.enumerated() {
                                let point = CGPoint(
                                    x: timeToX(dataPoint.timestamp, in: drawingRect),
                                    y: volumeToY(dataPoint.processedVolume, in: drawingRect)
                                )
                                
                                if index == 0 {
                                    path.move(to: point)
                                } else {
                                    path.addLine(to: point)
                                }
                            }
                        }
                        .stroke(Color.green.opacity(0.8), lineWidth: 1.5)
                        
                        // Current time indicator
                        Path { path in
                            let currentX = timeToX(currentTime, in: drawingRect)
                            path.move(to: CGPoint(x: currentX, y: drawingRect.minY))
                            path.addLine(to: CGPoint(x: currentX, y: drawingRect.maxY))
                        }
                        .stroke(Color.blue.opacity(0.6), lineWidth: 2)
                    }
                }
            }
        }
    }
}
