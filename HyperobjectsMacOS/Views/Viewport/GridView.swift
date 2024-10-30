//
//  GridView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 15/10/2024.
//

import Foundation
import SwiftUI
import AppKit

struct GridView: View {
    @Binding var scale: CGFloat
    @Binding var offset: CGSize
    
    var body: some View {
        let xStart = -500
        let xEnd = 500
        let yStart = -500
        let yEnd = 500
        let spacing: Int = 50
        Canvas { context, size in
            context.translateBy(x: offset.width, y: offset.height)
            context.scaleBy(x: scale, y: scale)
            
            let testPath = Path { path in
                path.move(to: CGPoint(x: -1000, y: -1000))
                path.addLine(to: CGPoint(x: 1000, y: 1000))
            }
            context.stroke(testPath, with: .color(.green), lineWidth: 1 / scale)
            
            let textColor = Color.white.opacity(0.6)
            let fontSize = 10
            
            context.addFilter(.shadow(color: .black.opacity(0.5), radius: 1, x: 1, y: 1))
            
            for x in stride(from: xStart, through: xEnd, by: 100) {
                let text = "\(x)"
                let tickFont = NSFont.monospacedSystemFont(ofSize: CGFloat(fontSize) / scale, weight: .regular)
                let textSize = text.size(withAttributes:[ .font: tickFont])
                
                context.draw(Text(text).foregroundColor(textColor).font(.system(size: 12 / scale).monospaced()),
                             at: CGPoint(x: CGFloat(x) + textSize.width / 2,
                                         y: CGFloat(yStart) - 15 / scale))
            }
            
            for y in stride(from: yStart, through: yEnd, by: 100) {
                let text = "\(y)"
                let textWidth = Double(text.count) * 2.7
                
                context.draw(Text(text).foregroundColor(textColor).font(.system(size: 12 / scale).monospaced()),
                             at: CGPoint(x: CGFloat(xStart) - textWidth / scale - 12.0 / scale,
                                         y: CGFloat(y)))
            }
            
            let gridPath = Path { path in
                for x in stride(from: xStart, through: xEnd, by: spacing) {
                    path.move(to: CGPoint(x: CGFloat(x), y: CGFloat(yStart)))
                    path.addLine(to: CGPoint(x: CGFloat(x), y: CGFloat(yEnd)))
                }
                
                for y in stride(from: yStart, through: yEnd, by: spacing) {
                    path.move(to: CGPoint(x: CGFloat(xStart), y: CGFloat(y)))
                    path.addLine(to: CGPoint(x: CGFloat(xEnd), y: CGFloat(y)))
                }
                
                path.move(to: CGPoint(x: xStart, y: yStart))
                path.addLine(to: CGPoint(x: xEnd, y: yStart))
                path.addLine(to: CGPoint(x: xEnd, y: yEnd))
                path.addLine(to: CGPoint(x: xStart, y: yEnd))
                path.closeSubpath()
            }
            
            context.stroke(gridPath, with: .color(.white.opacity(0.5)), lineWidth: 0.5 / scale)
        }
    }
}
