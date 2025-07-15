//
//  MetalViewWrapper.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 21/03/2025.
//

import SwiftUI
import MetalKit

class MetalViewWrapper: NSObject {
    let metalView: MTKView
    let metalLayer: CAMetalLayer
    let displayLink: CAMetalDisplayLink?
    var displayLinkDelegate: MetalDisplayLinkDelegateHandler?
    var preferredFPS: Float = 240
    
    init(metalView: MTKView, renderer: MetalRenderer) {
        self.metalView = metalView
        
        guard let layer = metalView.layer as? CAMetalLayer else {
            fatalError("MTKView layer is not a CAMetalLayer")
        }
        
        self.metalLayer = layer
        self.displayLink = CAMetalDisplayLink(metalLayer: metalLayer)
        
        super.init()
        
        if let displayLink = self.displayLink {
            displayLink.preferredFrameRateRange = CAFrameRateRange(minimum: self.preferredFPS, maximum: self.preferredFPS, preferred: self.preferredFPS)
            self.displayLinkDelegate = MetalDisplayLinkDelegateHandler(renderer: renderer, metalViewWrapper: self)
            displayLink.delegate = self.displayLinkDelegate
        }
    }
    
    func startRenderLoop() {
        Thread {
            if let displayLink = self.displayLink {
                displayLink.add(to: .current, forMode: .default)
                RunLoop.current.run()
            }
        }.start()
    }
}
