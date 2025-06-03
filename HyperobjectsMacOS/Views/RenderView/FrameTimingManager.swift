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
    
    private var lastFrameTimestamp: CFTimeInterval = 0
    private var tempFrameTimes: [Double] = []
    
    init() {
        frameTimes = Array(repeating: 0, count: maxFrameCount)
    }
    
    func captureFrameTime() {
        let currentTime = CACurrentMediaTime()
        
        if lastFrameTimestamp > 0 {
            let frameTime = (currentTime - lastFrameTimestamp) * 1000
            
            captureQueue.async { [weak self] in
                guard let self = self else { return }
                
                self.tempFrameTimes.append(frameTime)
                
                if self.tempFrameTimes.count >= 3 {
                    DispatchQueue.main.async {
                        self.updateFrameTimes(with: self.tempFrameTimes)
                        self.tempFrameTimes.removeAll()
                    }
                }
            }
        }
        
        lastFrameTimestamp = currentTime
    }
    
    private func updateFrameTimes(with newFrames: [Double]) {
        frameTimes.append(contentsOf: newFrames)
        
        if frameTimes.count > maxFrameCount {
            frameTimes = Array(frameTimes.suffix(maxFrameCount))
        }
        
        averageFrameTime = frameTimes.reduce(0, +) / Double(frameTimes.count)
    }
}
