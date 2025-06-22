//
//  FrameTimeChart.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 19/03/2025.
//

import SwiftUI

struct FrameTimeChart: View {
    var data: [Double]
    var maxBarHeight: CGFloat
    var barWidth: CGFloat
    var spacing: CGFloat
    
    init(data: [Double], maxBarHeight: CGFloat = 50, barWidth: CGFloat = 2, spacing: CGFloat = 0) {
        self.data = data
        self.maxBarHeight = maxBarHeight
        self.barWidth = barWidth
        self.spacing = spacing
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: spacing) {
            ForEach(data.indices, id: \.self) { index in
                let value = data[index]
                let maxValue = data.max() ?? 1
                let height = calculateHeight(value: value, maxValue: maxValue)
                Rectangle()
                    .fill(frameTimeColor(value))
                    .stroke(Color.clear, lineWidth: 0.0)
                    .frame(width: barWidth, height: height)
            }
        }.frame(
            width: CGFloat(data.count) * (barWidth + spacing),
            height: maxBarHeight
        )
    }
    
    func calculateHeight(value: Double, maxValue: Double) -> CGFloat {
        var height = CGFloat(value / maxValue) * maxBarHeight
        // Protect for invalid frame dimension, negative or non-finite
        height = max(0, height.isFinite ? height: 0)
        return height
    }
    
    private func frameTimeColor(_ frameTime: Double) -> Color {
        switch frameTime {
        case 0..<16.7:
            return .green
        case 16.7..<33.3:
            return .yellow
        default:
            return .red
        }
    }
}
