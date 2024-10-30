//
//  ViewportView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 14/10/2024.
//

import Foundation
import SwiftUI
import AppKit
import simd

struct ViewportView: View {
    @EnvironmentObject var currentScene: GeometriesSceneBase
    
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    @State private var dragStartLocation: CGPoint?
    @State private var geometryBounds: CGRect = .zero
    @State private var cursorPosition: CGPoint = .zero
    @State private var mappedCursorPosition: CGPoint = .zero
    
    var direction: String = "z"
    
    var xStart = -500
    var xEnd = 500
    var yStart = -500
    var yEnd = 500
    
    var body: some View {
        ZStack {
            // Top information overlays
            VStack(alignment: .leading) {
                Text("Viewport view (direction: \(direction), scene name: \(currentScene.name), scene lines count: \(currentScene.cachedGeometries.count))")
                Text("cursorPosition(\(String(format: "%.0f", cursorPosition.x)), \(String(format: "%.0f", cursorPosition.y)))")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("mappedCursorPosition(\(String(format: "%.0f", mappedCursorPosition.x)), \(String(format: "%.0f", mappedCursorPosition.y)))")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("scale(\(String(format: "%.2f", scale)))")
                Text("offset(\(String(format: "%.0f", offset.width)), \(String(format: "%.0f", offset.height)))")
                Spacer()
            }.font(myFont)
                .padding(8)
            
            
            // Viewport contents
            GeometryReader { geometry in
                ZStack {
                    GridView(scale: $scale, offset: $offset)
                    
                    Group {
                        Rectangle()
                            .stroke(.blue, lineWidth: 1.0 / scale)
                            .frame(width: geometry.size.width - 50, height: geometry.size.height - 50)
                            .position(x: (geometry.size.width - 50) / 2, y: (geometry.size.height - 50) / 2)
                        
                        ForEach(currentScene.cachedGeometries) { wrapped in
                            GeometryElement(gWrapped: wrapped, direction: direction, scale: scale)
                        }
                        

                    }.scaleEffect(scale, anchor: .topLeading)
                        .offset(offset)
                    
                    GestureHandlerView(
                        scale: $scale,
                        offset: $offset,
                        cursorPosition: $cursorPosition,
                        mappedCursorPosition: $mappedCursorPosition,
                        size: geometry.size
                    )
                    
                }.frame(width: geometry.size.width, height: geometry.size.height)
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        self.cursorPosition = location
                        self.mappedCursorPosition = CGPoint(
                            x: (self.cursorPosition.x - offset.width) / scale,
                            y: (self.cursorPosition.y - offset.height) / scale
                        )
                    case .ended:
                        break
                    }
                }
                .onAppear() {
                    centerOnMiddle(geometry: geometry)
                }
                
                VStack(alignment: .trailing) {
                    Text("Viewport controls")
                    Button("Center view") {
                        print("Center view pressed")
                        centerOnMiddle(geometry: geometry)
                        
                    }.font(myFont)
                    Button("View geometry") {
                        fitViewport(in: geometry.size)
                    }
                    Spacer()
                }.frame(maxWidth: .infinity, alignment: .topTrailing)
                    .font(myFont)
                    .padding(8)
            }
            
            
        }
    }
    
    func resetViewport() {
        withAnimation(.spring()) {
            scale = 1.0
            offset = .zero
        }
    }
    
    func fitViewport(in size: CGSize) {
        print("fit Viewport")
        guard geometryBounds.width > 0 && geometryBounds.height > 0 else { print("no geometry bounds"); return }
        let xScale = size.width / geometryBounds.width
        let yScale = size.height / geometryBounds.height
        let newScale = min(xScale, yScale) * 0.9
        
        let centerX = geometryBounds.midX
        let centerY = geometryBounds.midY
        
        withAnimation(.spring()) {
            scale = newScale
            offset = CGSize(
                width: (size.width / 2 - centerX * newScale),
                height: (size.height / 2 - centerY * newScale)
            )
        }
    }
    
    func centerOnMiddle(geometry: GeometryProxy) {
        print("Center on middle")
        scale = 1.0
        offset = CGSize(width: geometry.size.width / 2, height: geometry.size.height / 2)
    }
}
