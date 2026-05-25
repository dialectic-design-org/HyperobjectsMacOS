//
//  RendererState.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 21/03/2025.
//

import Foundation
import SwiftUI
import Combine

class RendererState: ObservableObject {
    @Published var rotationSpeed: Float = 1.0
    @Published var showFrameMetrics: Bool = true
    @Published var bandPrepMs: Double = 0
    @Published var bandRenderEncoded: Bool = false
    @Published var renderEncodeMs: Double = 0
    @Published var frameWaitMs: Double = 0
    
    private let atomicRotationSpeed = Atomic<Float>(value: 1.0)
    private let atomicShowFrameMetrics = Atomic<Bool>(value: true)
    private let renderMetricsLock = NSLock()
    private var lastRenderMetricsPublish: CFAbsoluteTime = 0
    
    let frameTimingManager = FrameTimingManager()
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        $rotationSpeed.sink { [weak self] newValue in
            self?.atomicRotationSpeed.set(newValue)
        }.store(in: &cancellables)
        
        $showFrameMetrics.sink { [weak self] newValue in
            self?.atomicShowFrameMetrics.set(newValue)
        }.store(in: &cancellables)
    }
    
    func getRotationSpeed() -> Float {
        return atomicRotationSpeed.get()
    }
    
    func shouldShowFrameMetrics() -> Bool {
        return atomicShowFrameMetrics.get()
    }

    func publishRenderMetrics(bandPrepMs: Double, bandRenderEncoded: Bool, renderEncodeMs: Double, frameWaitMs: Double) {
        let now = CFAbsoluteTimeGetCurrent()
        renderMetricsLock.lock()
        guard now - lastRenderMetricsPublish >= 0.1 else {
            renderMetricsLock.unlock()
            return
        }
        lastRenderMetricsPublish = now
        renderMetricsLock.unlock()

        DispatchQueue.main.async {
            self.bandPrepMs = bandPrepMs
            self.bandRenderEncoded = bandRenderEncoded
            self.renderEncodeMs = renderEncodeMs
            self.frameWaitMs = frameWaitMs
        }
    }
}
