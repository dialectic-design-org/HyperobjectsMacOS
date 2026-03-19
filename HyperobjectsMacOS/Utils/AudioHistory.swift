//
//  AudioHistory.swift
//  HyperobjectsMacOS
//

import Foundation

/// Thread-safe, fixed-capacity ring buffer for AudioDataPoint.
/// Overwrites oldest items when full — no shifting, no array copies on append.
final class AudioHistory {
    private var storage: [AudioDataPoint?]
    private var head: Int = 0       // next write position
    private var _count: Int = 0
    private let capacity: Int
    private let lock = NSLock()

    init(capacity: Int = 3600) {
        self.capacity = capacity
        self.storage = Array(repeating: nil, count: capacity)
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return _count
    }

    /// O(1) append — overwrites oldest item when full
    func append(_ point: AudioDataPoint) {
        lock.lock()
        storage[head] = point
        head = (head + 1) % capacity
        _count = min(_count + 1, capacity)
        lock.unlock()
    }

    /// Returns last `n` items in chronological order
    func suffix(_ n: Int) -> [AudioDataPoint] {
        lock.lock()
        defer { lock.unlock() }
        return _suffix(min(n, _count))
    }

    /// Returns all stored items in chronological order
    func snapshot() -> [AudioDataPoint] {
        lock.lock()
        defer { lock.unlock() }
        return _suffix(_count)
    }

    // Internal unlocked helper — caller must hold lock
    private func _suffix(_ n: Int) -> [AudioDataPoint] {
        guard n > 0 else { return [] }
        var result = [AudioDataPoint]()
        result.reserveCapacity(n)
        let start = (head - n + capacity) % capacity
        for i in 0..<n {
            result.append(storage[(start + i) % capacity]!)
        }
        return result
    }
}
