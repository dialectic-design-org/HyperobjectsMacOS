//
//  HyperobjectsMacOSTests.swift
//  HyperobjectsMacOSTests
//
//  Created by Erwin Hoogerwoord on 11/10/2024.
//

import Testing
@testable import HyperobjectsMacOS

struct HyperobjectsMacOSTests {

    @Test func midiSnapshotDefaultsExposeKnobsAndPads() throws {
        let state = MIDIControlState()
        let midi = try object(from: state.javascriptStateValue(at: 10).value)
        let knobs = try object(from: try required(midi["knobs"]))
        let pads = try object(from: try required(midi["pads"]))

        #expect(knobs.count == 8)
        #expect(pads.count == 8)
        #expect(try float(try required(try object(from: try required(knobs["k1"]))["cc"])) == 1)
        #expect(try float(try required(try object(from: try required(knobs["k8"]))["cc"])) == 8)
        #expect(try float(try required(try object(from: try required(pads["p1"]))["note"])) == 36)
        #expect(try float(try required(try object(from: try required(pads["p8"]))["note"])) == 43)
        #expect(try float(try required(try object(from: try required(knobs["k1"]))["value"])) == 0)
        #expect(try float(try required(try object(from: try required(pads["p1"]))["gate"])) == 0)
        #expect(try float(try required(try object(from: try required(pads["p1"]))["adsr"])) == 0)
    }

    @Test func midiSnapshotMapsKnobsAndPadsOnChannelOne() throws {
        let state = MIDIControlState()
        state.defaultADSR = ADSR(attack: 0, decay: 0, sustain: 1, release: 0.5)
        state.ingest(bytes: [0xB0, 0x01, 64], atSeconds: 1)
        state.ingest(bytes: [0xB0, 0x08, 127], atSeconds: 1)
        state.ingest(bytes: [0x90, 36, 100], atSeconds: 1)

        let midi = try object(from: state.javascriptStateValue(at: 1.1).value)
        let knobs = try object(from: try required(midi["knobs"]))
        let pads = try object(from: try required(midi["pads"]))
        let k1 = try object(from: try required(knobs["k1"]))
        let k8 = try object(from: try required(knobs["k8"]))
        let p1 = try object(from: try required(pads["p1"]))

        #expect(try float(try required(k1["raw"])) == 64)
        #expect(abs(try float(try required(k1["value"])) - (64.0 / 127.0)) < 0.000001)
        #expect(try float(try required(k8["raw"])) == 127)
        #expect(try float(try required(k8["value"])) == 1)
        #expect(try float(try required(p1["gate"])) == 1)
        #expect(abs(try float(try required(p1["adsr"])) - (100.0 / 127.0)) < 0.000001)
        #expect(abs(try float(try required(p1["velocity"])) - (100.0 / 127.0)) < 0.000001)
    }

    @Test func midiSnapshotKeepsADSRReleaseAfterNoteOff() throws {
        let state = MIDIControlState()
        state.defaultADSR = ADSR(attack: 0, decay: 0, sustain: 1, release: 1)
        state.ingest(bytes: [0x90, 36, 127], atSeconds: 1)
        state.ingest(bytes: [0x80, 36, 0], atSeconds: 2)

        let duringRelease = try pad("p1", in: state.javascriptStateValue(at: 2.25))
        #expect(try float(try required(duringRelease["gate"])) == 0)
        #expect(abs(try float(try required(duringRelease["adsr"])) - 0.75) < 0.000001)
        #expect(try float(try required(duringRelease["velocity"])) == 1)

        let afterRelease = try pad("p1", in: state.javascriptStateValue(at: 3.1))
        #expect(try float(try required(afterRelease["gate"])) == 0)
        #expect(try float(try required(afterRelease["adsr"])) == 0)
        #expect(try float(try required(afterRelease["velocity"])) == 0)
    }

}

private enum TestError: Error {
    case missingValue
    case wrongType
}

private func required(_ value: StateValue.Value?) throws -> StateValue.Value {
    guard let value else { throw TestError.missingValue }
    return value
}

private func object(from value: StateValue.Value) throws -> [String: StateValue.Value] {
    guard case .object(let object) = value else { throw TestError.wrongType }
    return object
}

private func float(_ value: StateValue.Value) throws -> Double {
    guard case .float(let value) = value else { throw TestError.wrongType }
    return value
}

private func pad(_ key: String, in value: StateValue) throws -> [String: StateValue.Value] {
    let midi = try object(from: value.value)
    let pads = try object(from: try required(midi["pads"]))
    return try object(from: try required(pads[key]))
}
