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
    
    private let atomicRotationSpeed = Atomic<Float>(value: 1.0)
    private let atomicShowFrameMetrics = Atomic<Bool>(value: true)
    
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
}
