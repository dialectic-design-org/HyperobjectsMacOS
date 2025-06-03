//
//  Atomic.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 21/03/2025.
//

import Foundation

class Atomic<T> {
    private var value: T
    private let lock = NSLock()
    
    init(value: T) {
        self.value = value
    }
    
    func get() -> T {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
    
    func set(_ newValue: T) {
        lock.lock()
        value = newValue
        lock.unlock()
    }
}
