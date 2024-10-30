//
//  GestureHandlerView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 15/10/2024.
//

import Foundation
import SwiftUI

struct GestureHandlerView: NSViewRepresentable {
    @Binding var scale: CGFloat
    @Binding var offset: CGSize
    @Binding var cursorPosition: CGPoint
    @Binding var mappedCursorPosition: CGPoint
    let size: CGSize
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let panGesture = NSPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        panGesture.numberOfTouchesRequired = 2
        view.addGestureRecognizer(panGesture)
        
        let magnificationGesture = NSMagnificationGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMagnification(_:)))
        view.addGestureRecognizer(magnificationGesture)
                
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.size = size
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(scale: $scale, offset: $offset, cursorPosition: $cursorPosition, mappedCursorPosition: $mappedCursorPosition, size: size)
    }
    
    class Coordinator: NSObject {
        @Binding var scale: CGFloat
        @Binding var offset: CGSize
        @Binding var cursorPosition: CGPoint
        @Binding var mappedCursorPosition: CGPoint
        var size: CGSize
        private var lastMagnification: CGFloat = 1.0
        
        
        init(scale: Binding<CGFloat>, offset: Binding<CGSize>, cursorPosition: Binding<CGPoint>, mappedCursorPosition: Binding<CGPoint>, size: CGSize) {
            _scale = scale
            _offset = offset
            _cursorPosition = cursorPosition
            _mappedCursorPosition = mappedCursorPosition
            self.size = size
        }
        
        @objc func handlePan(_ gesture: NSPanGestureRecognizer) {
            let translation = gesture.translation(in: gesture.view)
            offset = CGSize(
                width: offset.width + translation.x,
                height: offset.height - translation.y
            )
            gesture.setTranslation(.zero, in: gesture.view)
        }
        
        @objc func handleMagnification(_ gesture: NSMagnificationGestureRecognizer) {
            guard let view = gesture.view else { return }
            
            switch gesture.state {
            case .began:
                lastMagnification = 1.0
            case .changed:
                let newScale = max(0.1, min(scale * (1 + gesture.magnification), 10))
                gesture.magnification = 0
                
                let scaleDelta = newScale - scale
                
                let newOffset = CGSize(
                    width: offset.width - mappedCursorPosition.x * scaleDelta,
                    height: offset.height - mappedCursorPosition.y * scaleDelta
                )
                
                scale = newScale
                offset = newOffset
                mappedCursorPosition = CGPoint(
                    x: (cursorPosition.x - offset.width) / scale,
                    y: (cursorPosition.y - offset.height) / scale
                )
                
            case .ended:
                lastMagnification = 1.0
                
            default:
                break
            }
        }
    }
}
