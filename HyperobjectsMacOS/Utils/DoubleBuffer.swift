//
//  DoubleBuffer.swift
//  HyperobjectsMacOS
//

import Foundation

struct RenderSnapshot {
    var geometries: [GeometryWrapped] = []
    var renderOverrides: RenderConfigurationOverrides = .none
}

final class DoubleBuffer<T> {
    private var front: T
    private var back: T
    private var pending = false
    private let lock = NSLock()

    init(_ initial: T) {
        front = initial
        back = initial
    }

    /// Producer (main thread): stage a new value
    func publish(_ value: T) {
        lock.lock()
        back = value
        pending = true
        lock.unlock()
    }

    /// Consumer (render thread): swap in pending value if any, return current front.
    /// Call once per frame; use the returned value throughout — no further locking needed.
    func consume() -> T {
        lock.lock()
        if pending {
            swap(&front, &back)
            pending = false
        }
        let result = front
        lock.unlock()
        return result
    }
}
