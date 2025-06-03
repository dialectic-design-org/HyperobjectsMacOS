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
    @Published var someValue: Int = 0
    
    private let atomicSomeValue = Atomic<Int>(value: 0)
    
    let frameTimingManager = FrameTimingManager()
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        $someValue.sink { [weak self] newValue in
            self?.atomicSomeValue.set(newValue)
        }.store(in: &cancellables)
    }
    
    func getSomeValue() -> Int {
        return atomicSomeValue.get()
    }
}
