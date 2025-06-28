//
//  FreeformCurveEditor.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 28/06/2025.
//

import SwiftUI

struct FreeformCurveEditor: View {
    @ObservedObject var envelope: FreeformEnvelope
    let currentInput: Double
    let currentOutput: Double
    @State private var draggedPointId: UUID?
    @State private var dragOffset: CGSize = .zero
    
    private let padding: CGFloat = 16
    
    var body: some View {
        GeometryReader { geometry in
            let drawingRect = CGRect(
                x: padding,
                y: padding,
                width: geometry.size.width - padding * 2,
                height: geometry.size.height - padding * 2
            )
            
            ZStack {
                // Grid
                Path { path in
                    for i in 0...4 {
                        let y = drawingRect.minY + CGFloat(i) * drawingRect.height / 4
                        path.move(to: CGPoint(x: drawingRect.minX, y: y))
                        path.addLine(to: CGPoint(x: drawingRect.maxX, y: y))
                    }
                    
                    for i in 0...4 {
                        let x = drawingRect.minX + CGFloat(i) * drawingRect.width / 4
                        path.move(to: CGPoint(x: x, y: drawingRect.minY))
                        path.addLine(to: CGPoint(x: x, y: drawingRect.maxY))
                    }
                }
                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                
                // Live audio indicators
                // Vertical line for input level
                Path { path in
                    let inputX = drawingRect.minX + CGFloat(currentInput) * drawingRect.width
                    path.move(to: CGPoint(x: inputX, y: drawingRect.minY))
                    path.addLine(to: CGPoint(x: inputX, y: drawingRect.maxY))
                }
                .stroke(Color.orange.opacity(0.7), lineWidth: 2)
                
                // Horizontal line for output level
                Path { path in
                    let outputY = drawingRect.minY + CGFloat(1.0 - currentOutput) * drawingRect.height
                    path.move(to: CGPoint(x: drawingRect.minX, y: outputY))
                    path.addLine(to: CGPoint(x: drawingRect.maxX, y: outputY))
                }
                .stroke(Color.purple.opacity(0.7), lineWidth: 2)
                
                // Envelope curve
                Path { path in
                    let sortedPoints = envelope.controlPoints.sorted { $0.x < $1.x }
                    
                    for (index, point) in sortedPoints.enumerated() {
                        let cgPoint = CGPoint(
                            x: drawingRect.minX + point.x * drawingRect.width,
                            y: drawingRect.minY + (1.0 - point.y) * drawingRect.height
                        )
                        
                        if index == 0 {
                            path.move(to: cgPoint)
                        } else {
                            path.addLine(to: cgPoint)
                        }
                    }
                }
                .stroke(Color.green, lineWidth: 2)
                
                // Current audio position indicator (intersection point)
                let currentInputX = drawingRect.minX + CGFloat(currentInput) * drawingRect.width
                let currentOutputY = drawingRect.minY + CGFloat(1.0 - currentOutput) * drawingRect.height
                
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .position(x: currentInputX, y: currentOutputY)
                    .opacity(0.9)
                
                // Control points
                ForEach(envelope.controlPoints) { point in
                    let isBeingDragged = draggedPointId == point.id
                    let basePosition = CGPoint(
                        x: drawingRect.minX + point.x * drawingRect.width,
                        y: drawingRect.minY + (1.0 - point.y) * drawingRect.height
                    )
                    let currentPosition = isBeingDragged
                        ? CGPoint(x: basePosition.x + dragOffset.width, y: basePosition.y + dragOffset.height)
                        : basePosition
                    
                    Circle()
                        .fill(isBeingDragged ? Color.blue : Color.green)
                        .frame(width: isBeingDragged ? 16 : 12, height: isBeingDragged ? 16 : 12)
                        .position(currentPosition)
                        .gesture(
                            DragGesture(coordinateSpace: .local)
                                .onChanged { value in
                                    if draggedPointId == nil {
                                        draggedPointId = point.id
                                        dragOffset = .zero
                                    }
                                    
                                    if draggedPointId == point.id {
                                        dragOffset = value.translation
                                    }
                                }
                                .onEnded { value in
                                    if draggedPointId == point.id {
                                        let finalPosition = CGPoint(
                                            x: basePosition.x + value.translation.width,
                                            y: basePosition.y + value.translation.height
                                        )
                                        
                                        // Convert to normalized coordinates relative to the drawing rect
                                        let normalizedX = max(0.0, min(1.0, (finalPosition.x - drawingRect.minX) / drawingRect.width))
                                        let normalizedY = max(0.0, min(1.0, 1.0 - (finalPosition.y - drawingRect.minY) / drawingRect.height))
                                        
                                        if let index = envelope.controlPoints.firstIndex(where: { $0.id == point.id }) {
                                            envelope.controlPoints[index] = ControlPoint(x: normalizedX, y: normalizedY)
                                        }
                                        
                                        draggedPointId = nil
                                        dragOffset = .zero
                                    }
                                }
                        )
                }
            }
        }
    }
}
