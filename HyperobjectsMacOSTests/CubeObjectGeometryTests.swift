//
//  CubeObjectGeometryTests.swift
//  HyperobjectsMacOSTests
//

import Testing
import Foundation
import simd
@testable import HyperobjectsMacOS

/// Resolves a bank's inputs the way a geometry pass does, with a silent audio signal.
func resolvedInputs(_ bank: SceneInputBank) -> [String: Any] {
    GeometriesSceneBase.resolveInputs(
        bank.inputs.map { SceneInputView(capturing: $0) },
        snap: SceneInputSnapshot(),
        liveInput: { bank.inputsByName[$0] }
    )
}

func cubeLines(_ values: [String: Any] = [:]) -> [Line] {
    let bank = SceneInputBank(inputs: makeCubeSceneInputs())
    for (name, value) in values {
        bank.getInputWithName(name: name).value = value
    }
    return CubeGenerator.generateLines(inputs: resolvedInputs(bank), inputSource: bank)
}

func centroid(_ lines: [Line]) -> SIMD3<Float> {
    var sum = SIMD3<Float>(repeating: 0)
    for line in lines { sum += line.startPoint + line.endPoint }
    return sum / Float(max(lines.count * 2, 1))
}

func isClose(_ a: SIMD3<Float>, _ b: SIMD3<Float>, tolerance: Float = 1e-4) -> Bool {
    simd_length(a - b) < tolerance
}

struct CubeObjectGeometryTests {

    /// Order-sensitive summary of a set of lines.
    private func fingerprint(_ lines: [Line]) -> (count: Int, sum: SIMD3<Double>, weighted: Double) {
        var sum = SIMD3<Double>(repeating: 0)
        var weighted = 0.0
        for (i, line) in lines.enumerated() {
            let s = SIMD3<Double>(line.startPoint), e = SIMD3<Double>(line.endPoint)
            sum += s + e
            weighted += Double(i + 1) * (s.x + 2 * s.y + 3 * s.z + 4 * e.x + 5 * e.y + 6 * e.z)
        }
        return (lines.count, sum, weighted)
    }

    @Test func cubeGeometryMatchesReferenceForFixedInputs() {
        let lines = cubeLines([
            "Size": 0.7, "Width": 0.4, "Height": 0.9, "Depth": 0.6,
            "Outer Loop Cubes Count": 3, "Inner Loop Cubes Count": 2,
            "Outer Loop Cubes spread x": 1.5, "Inner Loop Cubes spread y": 0.8,
            "InnerCubesScaling": 0.5,
            "Rotation X": 0.3, "Rotation Y": 0.5, "Rotation Z": 0.2, "Rotation Y Offset": 0.4,
            "Scene Rotation X": 0.2, "Scene Rotation Y": 0.6,
            "Wave Amplitude Outer Loop translate z": 0.2, "Wave Frequency Outer Loop translate z": 1.0,
            "Wave Offset Outer Loop translate z": 0.1
        ])
        let f = fingerprint(lines)
        // Recorded from CubeGenerator before the position and rotation origin inputs were
        // added. With those inputs at 0 the geometry has to stay the same.
        #expect(f.count == 72)
        #expect(abs(f.sum.x - -3.1861299723386765) < 1e-4)
        #expect(abs(f.sum.y - 0.9252329890150577) < 1e-4)
        #expect(abs(f.sum.z - 4.564320271834731) < 1e-4)
        #expect(abs(f.weighted - 9835.165128197754) < 1e-3)
    }

    @Test func cubeLinesFromBankMatchCubeSceneDefaults() {
        let lines = cubeLines()
        // Size 0.5 * Width/Height/Depth 0.5: a cube from -0.25 to 0.25, centred on the origin.
        #expect(lines.count == 12)
        #expect(isClose(centroid(lines), SIMD3<Float>(0, 0, 0)))
        for line in lines {
            for point in [line.startPoint, line.endPoint] {
                #expect(abs(abs(point.x) - 0.25) < 1e-5)
                #expect(abs(abs(point.y) - 0.25) < 1e-5)
                #expect(abs(abs(point.z) - 0.25) < 1e-5)
            }
        }
    }

    @Test func cubeBankHasTheSameInputNamesAsTheCubeScene() {
        let scene = generateGeometrySceneCube()
        let bank = SceneInputBank(inputs: ScriptedObjectKind.cube.makeInputs())
        #expect(bank.inputs.map(\.name) == scene.inputs.map(\.name))
        #expect(Set(bank.inputs.map(\.name)).count == bank.inputs.count)
    }

    @Test func positionTranslatesEveryCubeLine() {
        let base = cubeLines()
        let moved = cubeLines(["Position X": 1.0, "Position Y": -0.5, "Position Z": 2.0])
        let offset = SIMD3<Float>(1.0, -0.5, 2.0)
        #expect(moved.count == base.count)
        for (a, b) in zip(base, moved) {
            #expect(isClose(b.startPoint, a.startPoint + offset))
            #expect(isClose(b.endPoint, a.endPoint + offset))
        }
    }

    @Test func positionIsAppliedAfterSceneRotation() {
        let lines = cubeLines(["Scene Rotation Y": Double.pi / 2, "Position X": 1.0])
        #expect(isClose(centroid(lines), SIMD3<Float>(1, 0, 0)))
    }

    @Test func rotationOriginPivotsCubeRotation() {
        // Half a turn around a pivot 0.5 to the right of the centre moves the centre to x = 1.
        let lines = cubeLines(["Rotation Z": Double.pi, "Rotation Origin X": 0.5])
        #expect(isClose(centroid(lines), SIMD3<Float>(1, 0, 0)))
        // Without a rotation the origin has no effect.
        #expect(isClose(centroid(cubeLines(["Rotation Origin X": 0.5])), SIMD3<Float>(0, 0, 0)))
    }

    @MainActor @Test func liveCodingSceneGeneratesGeometryForEveryCube() throws {
        let scene = generateGeometrySceneLiveCoding()
        let store = try #require(scene.objectStore)
        store.apply(from: cubesOutput([["Position X": .float(-1.0)], ["Position X": .float(1.0)]]),
                    warningCache: ScriptOutputWarningCache())
        scene.updateInput(name: "Lines", value: [Line]())   // also refreshes the snapshot
        scene.setWrappedGeometries()

        let lines = scene.renderBuffer.consume().geometries.compactMap { $0.geometry as? Line }
        #expect(lines.count == 24)
        #expect(isClose(centroid(Array(lines[0..<12])), SIMD3<Float>(-1, 0, 0)))
        #expect(isClose(centroid(Array(lines[12..<24])), SIMD3<Float>(1, 0, 0)))

        // Removing the cubes removes their geometry.
        store.apply(from: [:], warningCache: ScriptOutputWarningCache())
        scene.refreshSceneInputSnapshot()
        scene.setWrappedGeometries()
        #expect(scene.renderBuffer.consume().geometries.isEmpty)
    }

    @MainActor @Test func cubeDelayReadsItsOwnHistory() throws {
        let store = ScriptedObjectStore(collections: ["Cubes": .cube])
        let warnings = ScriptOutputWarningCache()
        store.apply(from: cubesOutput([["Width": .float(0.2)], ["Width": .float(0.2)]]), warningCache: warnings)
        store.apply(from: cubesOutput([["Width": .float(0.9)], ["Width": .float(0.2)]]), warningCache: warnings)
        let cubes = try #require(store.instances["Cubes"])
        let a = cubes[0].bank.getInputWithName(name: "Width")
        let b = cubes[1].bank.getInputWithName(name: "Width")
        #expect(a.getHistoryValue(millisecondsAgo: 0) as? Float == 0.9)
        #expect(b.getHistoryValue(millisecondsAgo: 0) as? Float == 0.2)
        #expect(a.historyCount == 2)
        #expect(b.historyCount == 1)
    }

    @Test func otherScenesHaveNoObjectStore() {
        #expect(generateGeometrySceneCube().objectStore == nil)
    }

    @Test func rotationOriginDoesNotMoveTheSceneRotationPivot() {
        let lines = cubeLines(["Scene Rotation Z": Double.pi, "Rotation Origin X": 0.5])
        #expect(isClose(centroid(lines), SIMD3<Float>(0, 0, 0)))
    }
}
