//
//  FrameTimingManager.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 19/03/2025.
//

import Foundation
import SwiftUI

class FrameTimingManager: ObservableObject {
    private let maxFrameCount = 120
    private let captureQueue = DispatchQueue(label: "com.frametiming.captureQueue", qos: .utility)
    
    @Published var frameTimes: [Double] = []
    @Published var averageFrameTime: Double = 0
    @Published var framePerSecond: Double = 0
    
    private var lastFrameTimestamp: CFTimeInterval = 0
    private var tempFrameTimes: [Double] = []
    private let frameTimeBufferLock = NSLock()
    
    private let atomicLastFrameTimestamp = Atomic<CFTimeInterval>(value: 0)
    
    init() {
        frameTimes = Array(repeating: 0, count: maxFrameCount)
    }
    
    func captureFrameTime() {
        let currentTime = CACurrentMediaTime()
        let lastTime = atomicLastFrameTimestamp.get()
        
        if lastTime > 0 {
            let frameTime = (currentTime - lastTime) * 1000
            
            captureQueue.async { [weak self] in
                guard let self = self else { return }
                
                self.frameTimeBufferLock.lock()
                self.tempFrameTimes.append(frameTime)
                let shouldUpdate = self.tempFrameTimes.count >= 2
                let framesToUpdate = shouldUpdate ? self.tempFrameTimes : []
                if shouldUpdate {
                    self.tempFrameTimes.removeAll()
                }
                self.frameTimeBufferLock.unlock()
                
                if shouldUpdate {
                    DispatchQueue.main.async {
                        self.updateFrameTimes(with: framesToUpdate)
                    }
                }
            }
        }
        
        atomicLastFrameTimestamp.set(currentTime)
    }
    
    private func updateFrameTimes(with newFrames: [Double]) {
        frameTimes.append(contentsOf: newFrames)
        
        if frameTimes.count > maxFrameCount {
            frameTimes = Array(frameTimes.suffix(maxFrameCount))
        }
        
        averageFrameTime = frameTimes.reduce(0, +) / Double(frameTimes.count)
        
        if averageFrameTime > 0 {
            framePerSecond = min(1000.0 / averageFrameTime, 999.0)
        }
        print("Update frame times: \(framePerSecond)")
    }
}
