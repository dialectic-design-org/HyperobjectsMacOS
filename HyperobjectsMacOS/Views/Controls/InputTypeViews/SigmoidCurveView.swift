//
//  SigmoidCurveView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 28/06/2025.
//

import SwiftUI

struct SigmoidCurveView: View {
    @ObservedObject var envelope: SigmoidEnvelope
    let currentInput: Double
    let currentOutput: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Grid lines
                Path { path in
                    // Horizontal lines
                    for i in 0...4 {
                        let y = CGFloat(i) * geometry.size.height / 4
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                    
                    // Vertical lines
                    for i in 0...4 {
                        let x = CGFloat(i) * geometry.size.width / 4
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                    }
                }
                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                
                // Live audio indicators
                // Vertical line for input level
                Path { path in
                    let inputX = CGFloat(currentInput) * geometry.size.width
                    path.move(to: CGPoint(x: inputX, y: 0))
                    path.addLine(to: CGPoint(x: inputX, y: geometry.size.height))
                }
                .stroke(Color.orange.opacity(0.7), lineWidth: 2)
                
                // Horizontal line for output level
                Path { path in
                    let outputY = geometry.size.height - (CGFloat(currentOutput) * geometry.size.height)
                    path.move(to: CGPoint(x: 0, y: outputY))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: outputY))
                }
                .stroke(Color.purple.opacity(0.7), lineWidth: 2)
                
                // Sigmoid curve
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let steps = 200
                    
                    for i in 0...steps {
                        let x = Double(i) / Double(steps)
                        let y = envelope.process(x)
                        
                        let point = CGPoint(
                            x: x * width,
                            y: height - (y * height)
                        )
                        
                        if i == 0 {
                            path.move(to: point)
                        } else {
                            path.addLine(to: point)
                        }
                    }
                }
                .stroke(Color.blue, lineWidth: 2)
                
                // Current audio position indicator (intersection point)
                let currentInputX = CGFloat(currentInput) * geometry.size.width
                let currentOutputY = geometry.size.height - (CGFloat(currentOutput) * geometry.size.height)
                
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .position(x: currentInputX, y: currentOutputY)
                    .opacity(0.9)
            }
        }
    }
}
