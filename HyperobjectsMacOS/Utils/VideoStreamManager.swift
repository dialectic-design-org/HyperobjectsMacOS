//
//  VideoStreamManager.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 18/03/2026.
//

import Foundation
import Metal
import Syphon

class VideoStreamManager: ObservableObject {
    @Published var syphonEnabled: Bool = false
    @Published var ndiEnabled: Bool = false

    private var syphonServer: SyphonMetalServer?
    private let device: MTLDevice

    init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        self.device = device
    }

    // MARK: - Syphon

    func startSyphon() {
        guard syphonServer == nil else { return }
        syphonServer = SyphonMetalServer(name: "HyperobjectsMacOS", device: device)
        print("[VideoStreamManager] Syphon server started")
    }

    func stopSyphon() {
        syphonServer?.stop()
        syphonServer = nil
        print("[VideoStreamManager] Syphon server stopped")
    }

    /// Call from the render loop after renderEncoder.endEncoding(), before commandBuffer.commit()
    func publishFrame(commandBuffer: MTLCommandBuffer, sourceTexture: MTLTexture) {
        if syphonEnabled, let server = syphonServer {
            let region = NSRect(
                x: 0, y: 0,
                width: sourceTexture.width,
                height: sourceTexture.height
            )
            server.publishFrameTexture(
                sourceTexture,
                on: commandBuffer,
                imageRegion: region,
                flipped: false
            )
        }
    }
}
