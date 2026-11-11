//
//  ScriptedObjectStoreTests.swift
//  HyperobjectsMacOSTests
//

import Testing
import Foundation
import SwiftUI
@testable import HyperobjectsMacOS

/// outputState with a "Cubes" array, as a script would return it.
func cubesOutput(_ descriptors: [[String: StateValue.Value]]) -> [String: StateValue] {
    ["Cubes": StateValue(value: .array(descriptors.map { params in
        var tagged = params
        tagged["__type"] = .string("Cube")
        return .object(tagged)
    }))]
}

@MainActor
struct ScriptedObjectStoreTests {

    private let warnings = ScriptOutputWarningCache()

    private func makeStore() -> ScriptedObjectStore {
        ScriptedObjectStore(collections: ["Cubes": .cube])
    }

    private func cubes(in store: ScriptedObjectStore) -> [ScriptedObjectInstance] {
        store.instances["Cubes"] ?? []
    }

    private func double(_ instance: ScriptedObjectInstance, _ name: String) -> Double? {
        instance.bank.getInputWithName(name: name).value as? Double
    }

    @Test func cubeCollectionCreatesOneInstancePerDescriptor() {
        let store = makeStore()
        store.apply(from: cubesOutput([[:], [:], [:]]), warningCache: warnings)
        #expect(cubes(in: store).count == 3)
        #expect(cubes(in: store).map(\.id) == ["#0", "#1", "#2"])
        #expect(cubes(in: store).allSatisfy { $0.kind == .cube })
    }

    @Test func singleObjectIsAcceptedAsOneCube() {
        let store = makeStore()
        store.apply(from: ["Cubes": StateValue(value: .object(["Width": .float(0.3)]))], warningCache: warnings)
        #expect(cubes(in: store).count == 1)
        #expect(double(cubes(in: store)[0], "Width") == 0.3)
    }

    @Test func cubeParametersAreWrittenToTheInstanceInputs() {
        let store = makeStore()
        store.apply(from: cubesOutput([[
            "Width": .float(0.3),
            "Position X": .float(-0.8),
            "Outer Loop Cubes Count": .float(4),
            "Color mode": .string("RGB"),
            "Color start": .vector4(SIMD4<Double>(1, 0, 0, 1))
        ]]), warningCache: warnings)
        let cube = cubes(in: store)[0]
        #expect(double(cube, "Width") == 0.3)
        #expect(double(cube, "Position X") == -0.8)
        #expect(cube.bank.getInputWithName(name: "Outer Loop Cubes Count").value as? Int == 4)
        #expect(cube.bank.getInputWithName(name: "Color mode").value as? String == "RGB")
        let color = (cube.bank.getInputWithName(name: "Color start").value as? Color)?.asSIMD4()
        #expect(color.map { abs($0.x - 1) < 0.01 && abs($0.y) < 0.01 && abs($0.z) < 0.01 } == true)
        // Untouched parameters keep the Cube scene defaults.
        #expect(double(cube, "Height") == 0.5)
    }

    @Test func omittedCubeParameterFallsBackToDefault() {
        let store = makeStore()
        store.apply(from: cubesOutput([["Width": .float(0.3), "audio_add_Width": .float(0.4)]]), warningCache: warnings)
        store.apply(from: cubesOutput([[:]]), warningCache: warnings)
        let cube = cubes(in: store)[0]
        #expect(double(cube, "Width") == 0.5)
        #expect(cube.bank.getInputWithName(name: "Width").audioAmplificationAddition == 0)
    }

    @Test func statefulCubeValueIsNotResetWhenOmitted() {
        let store = makeStore()
        store.apply(from: cubesOutput([["frame_tick_Stateful Rotation X": .float(0.1)]]), warningCache: warnings)
        let input = cubes(in: store)[0].bank.getInputWithName(name: "Stateful Rotation X")
        #expect(input.tickValueAdjustment == 0.1)
        input.value = 2.0   // what the audio tick accumulates

        store.apply(from: cubesOutput([[:]]), warningCache: warnings)
        #expect(input.tickValueAdjustment == 0)
        #expect(input.value as? Double == 2.0)
    }

    @Test func prefixedAudioAndTickKeysApplyPerCube() {
        let store = makeStore()
        store.apply(from: cubesOutput([
            ["audio_add_Position X": .float(0.5), "audio_multiply_offset_Width": .float(0.25), "audio_delay_Height": .float(0.3)],
            [:]
        ]), warningCache: warnings)
        let first = cubes(in: store)[0].bank
        let second = cubes(in: store)[1].bank
        #expect(first.getInputWithName(name: "Position X").audioAmplificationAddition == 0.5)
        #expect(first.getInputWithName(name: "Width").audioAmplificationMultiplicationOffset == 0.25)
        #expect(first.getInputWithName(name: "Height").audioDelay == 0.3)
        #expect(second.getInputWithName(name: "Position X").audioAmplificationAddition == 0)
        #expect(second.getInputWithName(name: "Width").audioAmplificationMultiplicationOffset == 1)
    }

    @Test func cubeInstancesKeepTheirBankByIndex() {
        let store = makeStore()
        store.apply(from: cubesOutput([["Width": .float(0.1)], ["Width": .float(0.2)]]), warningCache: warnings)
        let before = cubes(in: store).map(\.bank)
        store.apply(from: cubesOutput([["Width": .float(0.3)], ["Width": .float(0.4)]]), warningCache: warnings)
        let after = cubes(in: store).map(\.bank)
        #expect(before[0] === after[0])
        #expect(before[1] === after[1])
        #expect(double(cubes(in: store)[0], "Width") == 0.3)
    }

    @Test func cubeInstancesKeepTheirBankByIdWhenReordered() {
        let store = makeStore()
        store.apply(from: cubesOutput([["id": .string("a")], ["id": .string("b")]]), warningCache: warnings)
        let a = cubes(in: store)[0].bank
        let b = cubes(in: store)[1].bank
        store.apply(from: cubesOutput([["id": .string("b")], ["id": .string("a")], ["id": .float(3)]]), warningCache: warnings)
        #expect(cubes(in: store).map(\.id) == ["b", "a", "3"])
        #expect(cubes(in: store)[0].bank === b)
        #expect(cubes(in: store)[1].bank === a)
    }

    @Test func duplicateIdFallsBackToThePosition() {
        let store = makeStore()
        store.apply(from: cubesOutput([["id": .string("a")], ["id": .string("a")]]), warningCache: warnings)
        #expect(cubes(in: store).map(\.id) == ["a", "#1"])
        #expect(cubes(in: store)[0].bank !== cubes(in: store)[1].bank)
    }

    @Test func removedCubesAreDropped() {
        let store = makeStore()
        store.apply(from: cubesOutput([[:], [:], [:]]), warningCache: warnings)
        let first = cubes(in: store)[0].bank
        store.apply(from: cubesOutput([[:]]), warningCache: warnings)
        #expect(cubes(in: store).count == 1)
        #expect(cubes(in: store)[0].bank === first)
    }

    @Test func missingCollectionKeyRemovesAllCubes() {
        let store = makeStore()
        store.apply(from: cubesOutput([[:], [:]]), warningCache: warnings)
        store.apply(from: ["Lines": StateValue(value: .lineSegments([]))], warningCache: warnings)
        #expect(cubes(in: store).isEmpty)
        #expect(store.captureSnapshot().isEmpty)
    }

    @Test func emptyArrayParsedAsLineSegmentsRemovesAllCubes() throws {
        let store = makeStore()
        store.apply(from: cubesOutput([[:], [:]]), warningCache: warnings)
        // This is how `"Cubes": []` arrives from JavaScript.
        let empty = try #require(StateValue.fromJSONValue([Any]()))
        store.apply(from: ["Cubes": empty], warningCache: warnings)
        #expect(cubes(in: store).isEmpty)
    }

    @Test func unknownCubeParameterIsIgnored() {
        let store = makeStore()
        store.apply(from: cubesOutput([["Widht": .float(0.3), "Height": .float(0.9)]]), warningCache: warnings)
        #expect(cubes(in: store).count == 1)
        #expect(double(cubes(in: store)[0], "Width") == 0.5)
        #expect(double(cubes(in: store)[0], "Height") == 0.9)
    }

    @Test func nonFiniteParameterKeepsThePreviousValue() {
        let store = makeStore()
        store.apply(from: cubesOutput([["Width": .float(0.3)]]), warningCache: warnings)
        store.apply(from: cubesOutput([["Width": .float(.nan)]]), warningCache: warnings)
        #expect(double(cubes(in: store)[0], "Width") == 0.3)
    }

    @Test func objectOfAnotherKindIsSkipped() {
        let store = makeStore()
        store.apply(from: ["Cubes": StateValue(value: .array([
            .object(["__type": .string("Sphere")]),
            .object(["__type": .string("Cube")])
        ]))], warningCache: warnings)
        #expect(cubes(in: store).count == 1)
    }

    @Test func instanceCountIsCapped() {
        let store = makeStore()
        store.apply(from: cubesOutput(Array(repeating: [:], count: 70)), warningCache: warnings)
        #expect(cubes(in: store).count == ScriptedObjectStore.maxInstancesPerCollection)
    }

    @Test func newCubeHistoryIsSeededWithItsFirstValues() {
        let store = makeStore()
        store.apply(from: cubesOutput([["Width": .float(0.3)]]), warningCache: warnings)
        let width = cubes(in: store)[0].bank.getInputWithName(name: "Width")
        // A delayed lookup sees the cube's first value, not the default it was created with.
        #expect(width.getHistoryValue(millisecondsAgo: 2000) as? Float == 0.3)
        #expect(width.historyCount == 1)
    }

    @Test func snapshotFollowsScriptChangesAndStatefulValues() throws {
        let store = makeStore()
        func snapshotValue(_ name: String) throws -> Double {
            let cube = try #require(store.captureSnapshot()["Cubes"]?.first)
            let entry = try #require(cube.entries.first { $0.name == name })
            guard case .float(let value) = entry.value else { throw SnapshotError.notAFloat }
            return value
        }

        store.apply(from: cubesOutput([["Width": .float(0.3)]]), warningCache: warnings)
        #expect(try snapshotValue("Width") == 0.3)
        #expect(try snapshotValue("Height") == 0.5)

        store.apply(from: cubesOutput([["Width": .float(0.7)]]), warningCache: warnings)
        #expect(try snapshotValue("Width") == 0.7)

        store.apply(from: cubesOutput([[:]]), warningCache: warnings)
        #expect(try snapshotValue("Width") == 0.5)

        // Stateful values change outside the script (audio tick) and are captured every time.
        let stateful = try #require(store.statefulInputs.first { $0.name == "Stateful Rotation Y" })
        stateful.value = 1.25
        #expect(try snapshotValue("Stateful Rotation Y") == 1.25)
    }

    @Test func scriptOutputAppliesCubesNextToSceneInputs() throws {
        let scene = generateGeometrySceneLiveCoding()
        let store = try #require(scene.objectStore)
        let lines = scene.getInputWithName(name: "Lines")
        func run(_ output: [String: StateValue]) {
            // What a script sees for the scene's own inputs.
            let inputState = ["Lines": lines.toStateValue()]
            applyScriptOutput(inputState: inputState, outputState: output, baseState: [:], scene: scene,
                              bandFieldManager: BandFieldManager(), scriptRenderOverrides: ScriptRenderOverrides(),
                              warningCache: warnings)
        }
        #expect(lines.valueAsLines().count == 1)

        var output = cubesOutput([["Width": .float(0.3)], ["Width": .float(0.2)]])
        output["Lines"] = StateValue(value: .lineSegments([]))
        run(output)
        #expect(lines.valueAsLines().isEmpty)
        #expect(store.instances["Cubes"]?.count == 2)

        // RESET only concerns the scene's own inputs; the cubes stay as returned.
        output["RESET"] = StateValue(value: .bool(true))
        run(output)
        #expect(store.instances["Cubes"]?.count == 2)

        // A run that does not return "Cubes" removes them.
        run(["Lines": StateValue(value: .lineSegments([]))])
        #expect(store.instances["Cubes"]?.isEmpty == true)
    }

    @Test func removeAllDropsEveryInstance() {
        let store = makeStore()
        store.apply(from: cubesOutput([[:], [:]]), warningCache: warnings)
        store.removeAll()
        #expect(cubes(in: store).isEmpty)
        #expect(store.statefulInputs.isEmpty)
    }
}

private enum SnapshotError: Error {
    case notAFloat
}
