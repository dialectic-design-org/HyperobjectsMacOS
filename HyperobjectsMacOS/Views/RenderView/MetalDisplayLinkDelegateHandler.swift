//
//  MetalDisplayLinkDelegateHandler.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 21/03/2025.
//

import Foundation
import MetalKit

class MetalDisplayLinkDelegateHandler: NSObject, CAMetalDisplayLinkDelegate {
    let renderer: MetalRenderer
    weak var metalViewWrapper: MetalViewWrapper?
    
    init(renderer: MetalRenderer, metalViewWrapper: MetalViewWrapper?) {
        self.renderer = renderer
        self.metalViewWrapper = metalViewWrapper
        super.init()
    }
    
    func metalDisplayLink(_ link: CAMetalDisplayLink, needsUpdate update: CAMetalDisplayLink.Update) {
        // renderer.rendererState?.FrameTimingManager.captureFrameTime()
        renderer.render(drawable: update.drawable)
    }
}
