//
//  HyperobjectsMacOSTests.swift
//  HyperobjectsMacOSTests
//
//  Created by Erwin Hoogerwoord on 11/10/2024.
//

import Testing
import Foundation
import AppKit
@testable import HyperobjectsMacOS

struct HyperobjectsMacOSTests {

    @Test func stateValueParsesNumericNSNumbersAsFloats() throws {
        let one = try #require(StateValue.fromJSONValue(NSNumber(value: 1.0)))
        let zero = try #require(StateValue.fromJSONValue(NSNumber(value: 0.0)))
        let bool = try #require(StateValue.fromJSONValue(NSNumber(value: true)))

        #expect(try float(one.value) == 1.0)
        #expect(try float(zero.value) == 0.0)
        guard case .bool(true) = bool.value else {
            throw TestError.wrongType
        }
    }

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

    @Test func bandFieldParserAcceptsObjectSchema() throws {
        let bands = StateValue(value: .object([
            "enabled": .bool(true),
            "xAmplitudePx": .float(24),
            "yAmplitudePx": .float(12),
            "layers": .array([
                .object([
                    "axis": .string("vertical"),
                    "opacity": .float(0.5),
                    "bands": .array([
                        .object([
                            "center": .float(0),
                            "halfWidth": .float(0.25),
                            "featherW": .float(0.02),
                            "centerL": .float(0),
                            "halfLength": .float(1),
                            "featherL": .float(0.01),
                            "alpha": .float(1),
                            "dispersionPx": .float(32),
                            "rainbowBrightness": .float(2.5),
                            "gradMode": .string("width"),
                            "gradient": .array([
                                .array([.float(0), .floatArray([1, 0, 0, 1])]),
                                .array([.float(1), .floatArray([0, 1, 0, 1])])
                            ])
                        ])
                    ])
                ])
            ])
        ]))

        let state = try BandFieldManager.parse(bands, maxBands: 256)

        #expect(state.enabled)
        #expect(state.xAmplitudePx == 24)
        #expect(state.yAmplitudePx == 12)
        #expect(state.layers.count == 1)
        #expect(state.layers[0].bands.count == 1)
        #expect(state.layers[0].bands[0].colorStart.x == 1)
        #expect(state.layers[0].bands[0].colorEnd.y == 1)
        #expect(state.layers[0].bands[0].dispersionPx == 32)
        #expect(state.layers[0].bands[0].rainbowBrightness == 2.5)
        #expect(state.maxOffsetPx == 56)
    }

    @Test func bandFieldParserDefaultsAndClampsDispersion() throws {
        let bands = StateValue(value: .object([
            "enabled": .bool(true),
            "xAmplitudePx": .float(10),
            "yAmplitudePx": .float(20),
            "layers": .array([
                .object([
                    "bands": .array([
                        .object([
                            "dispersionPx": .float(-400),
                            "rainbowBrightness": .float(20),
                            "gradient": .array([
                                .array([.float(0), .floatArray([1, 1, 1, 1])])
                            ])
                        ]),
                        .object([:])
                    ])
                ])
            ])
        ]))

        let state = try BandFieldManager.parse(bands, maxBands: 256)

        #expect(state.layers[0].bands[0].dispersionPx == -256)
        #expect(state.layers[0].bands[0].rainbowBrightness == 8)
        #expect(state.layers[0].bands[1].dispersionPx == 0)
        #expect(state.layers[0].bands[1].rainbowBrightness == 1)
        #expect(state.maxOffsetPx == 276)
    }

    @Test func bandFieldParserAcceptsVectorGradientStopsFromJavaScriptArrays() throws {
        let bands = StateValue(value: .object([
            "enabled": .bool(true),
            "layers": .array([
                .object([
                    "bands": .array([
                        .object([
                            "gradient": .array([
                                .array([.float(0), .vector4(SIMD4<Double>(0.5, 0.25, 1.0, 1.0))]),
                                .array([.float(1), .vector4(SIMD4<Double>(0.5, 0.75, 1.0, 1.0))])
                            ])
                        ])
                    ])
                ])
            ])
        ]))

        let state = try BandFieldManager.parse(bands, maxBands: 256)

        #expect(state.layers[0].bands[0].colorStart.x == 0.5)
        #expect(state.layers[0].bands[0].colorStart.y == 0.25)
        #expect(state.layers[0].bands[0].colorStart.z == 1)
        #expect(state.layers[0].bands[0].colorEnd.x == 0.5)
        #expect(state.layers[0].bands[0].colorEnd.y == 0.75)
        #expect(state.layers[0].bands[0].colorEnd.z == 1)
    }

    @Test func bandFieldPreviewUsesNeutralDisplacementOutsideBands() throws {
        let state = BandFieldState(
            enabled: true,
            xAmplitudePx: 40,
            yAmplitudePx: 240,
            layers: [
                BandFieldLayer(axis: 0, blendMode: 0, opacity: 1, bands: [
                    BandFieldBand(
                        center: 0,
                        halfWidth: 0.01,
                        featherW: 0.001,
                        centerL: 0,
                        halfLength: 0.01,
                        featherL: 0.001,
                        alpha: 1,
                        colorStart: SIMD4<Float>(1, 1, 1, 1),
                        colorEnd: SIMD4<Float>(1, 1, 1, 1),
                        gradMode: 0,
                        dispersionPx: 0,
                        rainbowBrightness: 1
                    )
                ])
            ]
        )

        let color = BandFieldManager.samplePreviewColor(state: state, x: 0.0, y: 0.0, mode: .displacement)
        let nsColor = NSColor(color).usingColorSpace(.deviceRGB) ?? NSColor.black

        #expect(abs(Double(nsColor.redComponent) - 0.5) < 0.01)
        #expect(abs(Double(nsColor.greenComponent) - 0.5) < 0.01)
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
