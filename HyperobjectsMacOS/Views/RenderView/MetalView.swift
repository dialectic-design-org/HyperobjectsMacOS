//
//  MetalView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 01/01/2025.
//

import Foundation
import SwiftUI
import MetalKit

struct MetalView: NSViewRepresentable {
    @ObservedObject var rendererState: RendererState
    @EnvironmentObject var currentScene: GeometriesSceneBase
    @Binding var resolutionMode: ResolutionMode
    @Binding var resolution: CGSize // Bind the resolution to a parent view
    
    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        
        guard let renderer = MetalRenderer(rendererState: rendererState, currentScene: currentScene) else {
            fatalError("Failed to create Metal renderer")
        }
        
        view.device = renderer.device
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        view.enableSetNeedsDisplay = false
        
        let wrapper = MetalViewWrapper(metalView: view, renderer: renderer)
        context.coordinator.wrapper = wrapper
        context.coordinator.renderer = renderer
        
        print("Start render loop")
        wrapper.startRenderLoop()
        
        return view
    }
    
    func updateNSView(_ view: MTKView, context: Context) {
        // print("metalView updateNSView current scene: \(currentScene.name)")
        context.coordinator.renderer?.updateCurrentScene(currentScene)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var wrapper: MetalViewWrapper?
        var renderer: MetalRenderer?
    }
}
