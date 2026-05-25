//
//  MIDIControlState.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 24/05/2026.
//

import Foundation
import CoreMIDI
import os

struct ADSR {
    var attack: TimeInterval
    var decay: TimeInterval
    var sustain: Double
    var release: TimeInterval
    
    static let `default` = ADSR(
        attack: 0.005,
        decay: 0.12,
        sustain: 0.7,
        release: 0.25
    )
}

final class MIDIControlState {
    static let defaultKnobControllers: [UInt8] = Array(1...8)
    static let defaultPadNotes: [UInt8] = Array(36...43)

    var defaultADSR: ADSR = .default
    var historyWindow: TimeInterval = 120
    var maxSamplesPerControl = 4096
    var maxSpansPerNote = 32
    
    private static let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()
    
    private static func machToSeconds(_ host: UInt64) -> TimeInterval {
        Double(host) * Double(timebase.numer) / Double(timebase.denom) / 1_000_000_000
    }
    
    func now() -> TimeInterval { Self.machToSeconds(mach_absolute_time()) }
    
    private struct CCKey: Hashable { let channel: UInt8; let controller: UInt8 }
    private struct NoteKey: Hashable { let channel: UInt8; let note: UInt8 }
    private struct Sample { let time: TimeInterval; let value: Double }
    private struct NoteSpan {
        let onTime: TimeInterval
        var offTime: TimeInterval?
        let velocity: Double
    }
    
    private let lock = OSAllocatedUnfairLock()
    private var ccHistory: [CCKey: [Sample]] = [:]
    private var noteSpans: [NoteKey: [NoteSpan]] = [:]
    private var pitchBend: [UInt8: [Sample]] = [:]
    private var emittedSnapshotWarnings: Set<String> = []
    
    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock(); defer { lock.unlock() }
        return body()
    }
    
    func ingest(bytes: [UInt8], timeStamp: MIDITimeStamp) {
        let t = timeStamp == 0 ? now() : Self.machToSeconds(timeStamp)
        withLock {
            for msg in Self.channelVoiceMessages(in: bytes) { record(msg, at: t) }
        }
    }

    func ingest(bytes: [UInt8], atSeconds time: TimeInterval) {
        withLock {
            for msg in Self.channelVoiceMessages(in: bytes) { record(msg, at: time) }
        }
    }
    
    private func record(_ m: ChannelMessage, at t: TimeInterval) {
        switch m.type {
        case 0x90 where m.d2 > 0:                       // note on
            startNote(channel: m.channel, note: m.d1, velocity: m.d2, at: t)
        case 0x80, 0x90:                                // note off (incl. on-vel-0)
            endNote(channel: m.channel, note: m.d1, at: t)
        case 0xB0:                                      // control change
            append(&ccHistory, CCKey(channel: m.channel, controller: m.d1),
                   Sample(time: t, value: Double(m.d2)))
        case 0xE0:                                      // pitch bend
            let v = (Int(m.d1) | (Int(m.d2) << 7)) - 8192
            append(&pitchBend, m.channel, Sample(time: t, value: Double(v)))
        default:
            break
        }
    }
    
    private func startNote(channel: UInt8, note: UInt8, velocity: UInt8, at t: TimeInterval) {
        let key = NoteKey(channel: channel, note: note)
        var spans = noteSpans[key] ?? []
        for i in spans.indices where spans[i].offTime == nil { spans[i].offTime = t } // retrigger
        spans.append(NoteSpan(onTime: t, offTime: nil, velocity: Double(velocity)))
        if spans.count > maxSpansPerNote { spans.removeFirst(spans.count - maxSpansPerNote) }
        noteSpans[key] = spans
    }

    private func endNote(channel: UInt8, note: UInt8, at t: TimeInterval) {
        let key = NoteKey(channel: channel, note: note)
        guard var spans = noteSpans[key] else { return }
        for i in spans.indices.reversed() where spans[i].offTime == nil {
            spans[i].offTime = t; break
        }
        noteSpans[key] = spans
    }

    private func append<K: Hashable>(_ store: inout [K: [Sample]], _ key: K, _ s: Sample) {
        var arr = store[key] ?? []
        arr.append(s)
        let cutoff = s.time - historyWindow
        if arr.count > 1 {
            var drop = 0
            while drop < arr.count - 1 && arr[drop].time < cutoff { drop += 1 }
            if drop > 0 { arr.removeFirst(drop) }
        }
        if arr.count > maxSamplesPerControl { arr.removeFirst(arr.count - maxSamplesPerControl) }
        store[key] = arr
    }
    
    // MARK: Query — knobs (CC)

    /// Raw 0...127 knob value at `time` (default now). `nil` if never seen.
    func ccRaw(controller: UInt8, channel: UInt8 = 1,
               at time: TimeInterval? = nil, interpolate: Bool = false) -> Double? {
        let t = time ?? now()
        return withLock {
            guard let s = ccHistory[CCKey(channel: channel, controller: controller)],
                  !s.isEmpty else { return nil }
            return Self.sample(s, at: t, interpolate: interpolate)
        }
    }

    /// Normalized 0...1 knob value, or `fallback` if never seen.
    /// `interpolate: true` smooths between received steps — nice for visuals.
    func ccValue(controller: UInt8, channel: UInt8 = 1,
                 at time: TimeInterval? = nil, interpolate: Bool = false,
                 fallback: Double = 0) -> Double {
        (ccRaw(controller: controller, channel: channel,
               at: time, interpolate: interpolate).map { $0 / 127.0 }) ?? fallback
    }

    /// Pitch bend as -1...1 at `time`.
    func pitchBendValue(channel: UInt8 = 1, at time: TimeInterval? = nil,
                        interpolate: Bool = true) -> Double {
        let t = time ?? now()
        return withLock {
            guard let s = pitchBend[channel], !s.isEmpty else { return 0 }
            return Self.sample(s, at: t, interpolate: interpolate) / 8192.0
        }
    }

    // MARK: Query — notes

    /// Square gate: amplitude while the note is held at `time`, 0 otherwise.
    func noteGate(_ note: UInt8, channel: UInt8 = 1,
                  velocitySensitive: Bool = false,
                  at time: TimeInterval? = nil) -> Double {
        let t = time ?? now()
        return withLock {
            guard let span = activeSpan(channel: channel, note: note, at: t),
                  span.offTime == nil || t < span.offTime!
            else { return 0 }
            return velocitySensitive ? span.velocity / 127.0 : 1.0
        }
    }

    /// ADSR envelope value (0...1, or 0...velocity) for the note at `time`.
    /// Any nil parameter falls back to `defaultADSR`'s component.
    func noteEnvelope(_ note: UInt8, channel: UInt8 = 1,
                      attack: TimeInterval? = nil,
                      decay: TimeInterval? = nil,
                      sustain: Double? = nil,
                      release: TimeInterval? = nil,
                      velocitySensitive: Bool = true,
                      at time: TimeInterval? = nil) -> Double {
        let adsr = ADSR(attack:  attack  ?? defaultADSR.attack,
                        decay:   decay   ?? defaultADSR.decay,
                        sustain: sustain ?? defaultADSR.sustain,
                        release: release ?? defaultADSR.release)
        let t = time ?? now()
        return withLock {
            guard let span = activeSpan(channel: channel, note: note, at: t) else { return 0 }
            let peak = velocitySensitive ? span.velocity / 127.0 : 1.0
            return Self.adsrLevel(at: t, span: span, adsr: adsr, peak: peak)
        }
    }

    /// Convenience overload taking a full ADSR struct.
    func noteEnvelope(_ note: UInt8, channel: UInt8 = 1, adsr: ADSR,
                      velocitySensitive: Bool = true,
                      at time: TimeInterval? = nil) -> Double {
        noteEnvelope(note, channel: channel, attack: adsr.attack, decay: adsr.decay,
                     sustain: adsr.sustain, release: adsr.release,
                     velocitySensitive: velocitySensitive, at: time)
    }

    func isNoteOn(_ note: UInt8, channel: UInt8 = 1, at time: TimeInterval? = nil) -> Bool {
        let t = time ?? now()
        return withLock {
            guard let s = activeSpan(channel: channel, note: note, at: t) else { return false }
            return s.offTime == nil || t < s.offTime!
        }
    }

    // MARK: JavaScript snapshot

    /// Stable nested object exposed to scene scripts as `inputState.midi`.
    /// Values are sampled at one timestamp so knobs, gates, and envelopes are frame-consistent.
    func javascriptStateValue(
        channel requestedChannel: UInt8 = 1,
        knobControllers requestedKnobControllers: [UInt8] = MIDIControlState.defaultKnobControllers,
        padNotes requestedPadNotes: [UInt8] = MIDIControlState.defaultPadNotes,
        adsr requestedADSR: ADSR? = nil,
        at time: TimeInterval? = nil
    ) -> StateValue {
        let t = time ?? now()
        let object = withLock {
            let channel = sanitizedChannel(requestedChannel)
            let knobControllers = sanitizedMIDINumbers(
                requestedKnobControllers,
                fallback: Self.defaultKnobControllers,
                warningKey: "knobControllers"
            )
            let padNotes = sanitizedMIDINumbers(
                requestedPadNotes,
                fallback: Self.defaultPadNotes,
                warningKey: "padNotes"
            )
            let adsr = sanitizedADSR(requestedADSR ?? defaultADSR)

            return buildMIDIObject(
                channel: channel,
                knobControllers: knobControllers,
                padNotes: padNotes,
                adsr: adsr,
                at: t
            )
        }
        return StateValue(value: .object(object))
    }

    // MARK: Internal helpers

    private func buildMIDIObject(
        channel: UInt8,
        knobControllers: [UInt8],
        padNotes: [UInt8],
        adsr: ADSR,
        at t: TimeInterval
    ) -> [String: StateValue.Value] {
        var knobs: [String: StateValue.Value] = [:]
        knobs.reserveCapacity(knobControllers.count)
        for (index, controller) in knobControllers.enumerated() {
            let raw = ccHistory[CCKey(channel: channel, controller: controller)].flatMap {
                $0.isEmpty ? nil : Self.sample($0, at: t, interpolate: true)
            } ?? 0
            let value = Self.clampedFinite(raw / 127.0, min: 0, max: 1, fallback: 0)
            knobs["k\(index + 1)"] = .object([
                "cc": .float(Double(controller)),
                "channel": .float(Double(channel)),
                "raw": .float(Self.clampedFinite(raw, min: 0, max: 127, fallback: 0)),
                "value": .float(value)
            ])
        }

        var pads: [String: StateValue.Value] = [:]
        pads.reserveCapacity(padNotes.count)
        for (index, note) in padNotes.enumerated() {
            let span = activeSpan(channel: channel, note: note, at: t)
            let gate: Double
            if let span, span.offTime == nil || span.offTime.map({ t < $0 }) == true {
                gate = 1
            } else {
                gate = 0
            }
            let adsrValue = span.map {
                Self.clampedFinite(Self.adsrLevel(at: t, span: $0, adsr: adsr, peak: $0.velocity / 127.0), min: 0, max: 1, fallback: 0)
            } ?? 0
            let velocity = adsrValue > 0 ? Self.clampedFinite((span?.velocity ?? 0) / 127.0, min: 0, max: 1, fallback: 0) : 0
            pads["p\(index + 1)"] = .object([
                "note": .float(Double(note)),
                "channel": .float(Double(channel)),
                "gate": .float(gate),
                "adsr": .float(adsrValue),
                "velocity": .float(velocity)
            ])
        }

        return [
            "knobs": .object(knobs),
            "pads": .object(pads)
        ]
    }

    private func sanitizedChannel(_ channel: UInt8) -> UInt8 {
        if channel >= 1 && channel <= 16 { return channel }
        emitSnapshotWarningOnce("channel", message: "MIDI snapshot channel \(channel) is invalid; falling back to channel 1")
        return 1
    }

    private func sanitizedMIDINumbers(_ values: [UInt8], fallback: [UInt8], warningKey: String) -> [UInt8] {
        let valid = values.filter { $0 <= 127 }
        if valid.isEmpty {
            emitSnapshotWarningOnce(warningKey, message: "MIDI snapshot \(warningKey) is empty; falling back to defaults")
            return fallback
        }
        return valid
    }

    private func sanitizedADSR(_ adsr: ADSR) -> ADSR {
        func duration(_ value: TimeInterval, fallback: TimeInterval, key: String) -> TimeInterval {
            guard value.isFinite, value >= 0 else {
                emitSnapshotWarningOnce("adsr.\(key)", message: "MIDI ADSR \(key) is invalid; falling back to \(fallback)")
                return fallback
            }
            return value
        }

        let sustain: Double
        if adsr.sustain.isFinite {
            sustain = min(max(adsr.sustain, 0), 1)
        } else {
            emitSnapshotWarningOnce("adsr.sustain", message: "MIDI ADSR sustain is invalid; falling back to \(ADSR.default.sustain)")
            sustain = ADSR.default.sustain
        }

        return ADSR(
            attack: duration(adsr.attack, fallback: ADSR.default.attack, key: "attack"),
            decay: duration(adsr.decay, fallback: ADSR.default.decay, key: "decay"),
            sustain: sustain,
            release: duration(adsr.release, fallback: ADSR.default.release, key: "release")
        )
    }

    private func emitSnapshotWarningOnce(_ key: String, message: String) {
        guard !emittedSnapshotWarnings.contains(key) else { return }
        emittedSnapshotWarnings.insert(key)
        os_log(.error, "%{public}@", message)
    }

    private func activeSpan(channel: UInt8, note: UInt8, at t: TimeInterval) -> NoteSpan? {
        guard let spans = noteSpans[NoteKey(channel: channel, note: note)] else { return nil }
        for span in spans.reversed() where span.onTime <= t { return span }   // newest wins
        return nil
    }

    private static func clampedFinite(_ value: Double, min lower: Double, max upper: Double, fallback: Double) -> Double {
        guard value.isFinite else { return fallback }
        return Swift.min(Swift.max(value, lower), upper)
    }

    /// Last value at/before `t` (held), optionally linearly interpolated to the next.
    private static func sample(_ s: [Sample], at t: TimeInterval, interpolate: Bool) -> Double {
        if t <= s[0].time { return s[0].value }
        if t >= s[s.count - 1].time { return s[s.count - 1].value }
        var lo = 0, hi = s.count - 1
        while lo < hi {                                  // largest index with time <= t
            let mid = (lo + hi + 1) / 2
            if s[mid].time <= t { lo = mid } else { hi = mid - 1 }
        }
        guard interpolate else { return s[lo].value }
        let a = s[lo], b = s[lo + 1]
        let span = b.time - a.time
        return span > 0 ? a.value + (b.value - a.value) * (t - a.time) / span : a.value
    }

    /// Analytic ADSR. Releasing mid-attack/decay correctly releases from the *current* level.
    private static func adsrLevel(at t: TimeInterval, span: NoteSpan,
                                  adsr: ADSR, peak: Double) -> Double {
        guard t >= span.onTime else { return 0 }
        let sustainLevel = adsr.sustain * peak

        func preRelease(_ dt: TimeInterval) -> Double {
            if dt < adsr.attack { return adsr.attack > 0 ? peak * dt / adsr.attack : peak }
            let ad = dt - adsr.attack
            if ad < adsr.decay {
                let f = adsr.decay > 0 ? ad / adsr.decay : 1
                return peak + (sustainLevel - peak) * f
            }
            return sustainLevel
        }

        if let off = span.offTime, t >= off {
            let levelAtRelease = preRelease(off - span.onTime)
            let dr = t - off
            if adsr.release <= 0 || dr >= adsr.release { return 0 }
            return levelAtRelease * (1 - dr / adsr.release)
        }
        return preRelease(t - span.onTime)
    }
    
    struct ChannelMessage { let type: UInt8; let channel: UInt8; let d1: UInt8; let d2: UInt8 }
    
    static func channelVoiceMessages(in bytes: [UInt8]) -> [ChannelMessage] {
        var out: [ChannelMessage] = []
        var i = 0
        var runningStatus: UInt8?
        while i < bytes.count {
            let b = bytes[i]
            if b >= 0xF8 { i += 1; continue }            // real-time: 1 byte, may interleave
            if b >= 0xF0 { break }                       // system common / SysEx: stop
            let status: UInt8
            if b >= 0x80 { status = b; runningStatus = b; i += 1 }
            else if let rs = runningStatus { status = rs }   // running status
            else { i += 1; continue }                        // stray data byte
            let type = status & 0xF0
            let needed = (type == 0xC0 || type == 0xD0) ? 1 : 2
            guard i + needed <= bytes.count else { break }
            let d1 = bytes[i]
            let d2 = needed == 2 ? bytes[i + 1] : 0
            i += needed
            out.append(ChannelMessage(type: type, channel: (status & 0x0F) + 1, d1: d1, d2: d2))
        }
        return out
    }
}
