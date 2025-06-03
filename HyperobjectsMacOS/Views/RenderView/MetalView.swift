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
    @ObservedObject var timingManager: FrameTimingManager

    func makeNSView(context: Context) -> MTKView {
        print("MetalView makeNSView()")
        let mtkView = MTKView()
        mtkView.delegate = context.coordinator
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        if (resolutionMode == .dynamic) {
            mtkView.drawableSize = mtkView.frame.size
        } else if (resolutionMode == .fixed) {
            mtkView.drawableSize = resolution
        }
        mtkView.enableSetNeedsDisplay = true
        mtkView.framebufferOnly = false
        
        if let device = MTLCreateSystemDefaultDevice() {
            mtkView.device = device
            print("Calling context.coordinator.setup(device: device)")
            context.coordinator.setup(device: device)
            print("Finished calling context.coordinator.setup(device: device)")
        }
        mtkView.isPaused = false
        return mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        // print("MetalView updateNSView()")
        // context.coordinator.updateCurrentScene(currentScene)
        // nsView.setNeedsDisplay(nsView.bounds)
    }
    
    func makeCoordinator() -> MetalRenderer {
        print("makeCoordinator calling")
        let renderer = MetalRenderer(self, currentSceneFromParent: currentScene, rendererState: rendererState)
        return renderer
    }
}
