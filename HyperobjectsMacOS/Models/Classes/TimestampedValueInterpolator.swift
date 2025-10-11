//
//  TimestampedValueInterpolator.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 20/09/2025.
//
import Foundation

/// High-throughput 1D linear interpolator over (t, v) samples.
/// Timestamps are Float (seconds, frames, ticks — you choose).
final class FloatInterpolator {
    // Structure-of-Arrays for locality
    private var ts: [Float] = []
    private var vs: [Float] = []
    
    // Logical start of valid window (for fast pruning)
    private var head: Int = 0
    
    // Optional preallocation to reduce reallocs
    init(reserve: Int = 0) {
        if reserve > 0 {
            ts.reserveCapacity(reserve)
            vs.reserveCapacity(reserve)
        }
    }
    
    @inline(__always)
    var count: Int { ts.count - head }
    
    /// Add a sample at time `t`.
    /// If `monotonic` and `t` is >= last t, we append (O(1)).
    /// Otherwise we binary-search and insert (O(n) shift, O(log n) find).
    func add(_ value: Float, at t: Float, monotonic: Bool = true) {
        if ts.isEmpty {
            ts.append(t)
            vs.append(value)
            return
        }
        // If all previous samples are pruned, ensure comparisons use valid tail
        let lastT = ts.last!
        if monotonic && t >= lastT {
            ts.append(t)
            vs.append(value)
            return
        }
        let idx = upperBound(t) // first index with ts[idx] > t
        ts.insert(t, at: idx)
        vs.insert(value, at: idx)
    }
    
    /// Linear interpolation at time `t`.
    /// Returns nil if empty.
    func value(at t: Float) -> Float? {
        let n = ts.count
        if head >= n { return nil }
        if head + 1 == n { return vs[head] } // single point
        
        // Find first index i with ts[i] >= t within [head, n)
        let i = lowerBound(t)
        if i <= head { return vs[head] }     // before earliest: clamp
        if i >= n { return vs[n - 1] }       // after latest:   clamp
        
        let t0 = ts[i - 1], t1 = ts[i]
        let v0 = vs[i - 1], v1 = vs[i]
        let dt = t1 - t0
        if dt == 0 { return v1 }             // identical timestamps: take latest
        let r = (t - t0) / dt
        return v0 + (v1 - v0) * r
    }
    
    /// Remove all samples with t < minT.
    /// Uses head advancement + occasional compaction (amortized O(1)).
    func removeOlderThan(_ minT: Float) {
        if ts.isEmpty || ts.last! < minT { // everything old
            clear()
            return
        }
        // Advance head to first index with ts[idx] >= minT
        head = lowerBound(minT)
        
        // Compact when wasted prefix is large (heuristic)
        // This avoids O(n) cost on every prune.
        let wasted = head
        if wasted > 4096 && wasted > (ts.count >> 1) {
            ts.removeFirst(wasted)
            vs.removeFirst(wasted)
            head = 0
        }
    }
    
    func range() -> (earliest: Float, latest: Float)? {
        let n = ts.count
        guard head < n else { return nil }
        return (ts[head], ts[n - 1])
    }
    
    // MARK: - Double convenience (optional)
    func add(_ value: Double, at t: Double, monotonic: Bool = true) {
        add(Float(value), at: Float(t), monotonic: monotonic)
    }
    func value(at t: Double) -> Double? {
        guard let v: Float = value(at: Float(t)) else { return nil }
        return Double(v)
    }
    func removeOlderThan(_ minT: Double) { removeOlderThan(Float(minT)) }
    
    // MARK: - Binary search utilities over [head, ts.count)
    /// First index i with ts[i] >= x
    @inline(__always)
    private func lowerBound(_ x: Float) -> Int {
        var lo = head
        var hi = ts.count
        while lo < hi {
            let mid = (lo + hi) >> 1
            if ts[mid] < x { lo = mid + 1 } else { hi = mid }
        }
        return lo
    }
    
    /// First index i with ts[i] > x
    @inline(__always)
    private func upperBound(_ x: Float) -> Int {
        var lo = head
        var hi = ts.count
        while lo < hi {
            let mid = (lo + hi) >> 1
            if ts[mid] <= x { lo = mid + 1 } else { hi = mid }
        }
        return lo
    }
    
    private var timeOrigin: Double? = nil

    // Absolute-time add/query (rebased to origin -> Float)
    func addAbs(_ value: Double, at tAbs: Double, monotonic: Bool = true) {
        if timeOrigin == nil { timeOrigin = tAbs }
        let tRel = Float(tAbs - timeOrigin!)
        add(Float(value), at: tRel, monotonic: monotonic)
    }

    func valueAbs(at tAbs: Double) -> Double? {
        guard let t0 = timeOrigin else { return nil }
        let tRel = Float(tAbs - t0)
        guard let v = value(at: tRel) else { return nil }
        return Double(v)
    }

    func removeOlderThanAbs(_ minAbs: Double) {
        guard let t0 = timeOrigin else { return }
        removeOlderThan(Float(minAbs - t0))
        // keep t0 stable; do NOT slide it each prune
    }

    // Reset also clears origin
    func clear() {
        ts.removeAll(keepingCapacity: true)
        vs.removeAll(keepingCapacity: true)
        head = 0
        timeOrigin = nil
    }
}
