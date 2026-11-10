//
//  ScriptRenderOverridesTests.swift
//  HyperobjectsMacOSTests
//

import Testing
import Foundation
@testable import HyperobjectsMacOS

struct ScriptRenderOverridesTests {

    private func float(_ d: Double) -> StateValue { StateValue(value: .float(d)) }

    @Test func scriptOutputOverridesCameraAndProjectionValues() {
        let overrides = ScriptRenderOverrides()
        overrides.apply(from: [
            "projectionMix": float(0.25),
            "cameraDistance": float(3.5),
            "orthographicProjectionHeight": float(2.5),
            "FOVDivision": float(4)
        ])
        let current = overrides.current()
        #expect(current.projectionMix == 0.25)
        #expect(current.cameraDistance == 3.5)
        #expect(current.orthographicProjectionHeight == 2.5)
        #expect(current.fovDivision == 4)
    }

    @Test func keysNoLongerReturnedFallBackToRenderConfiguration() {
        let overrides = ScriptRenderOverrides()
        overrides.apply(from: ["cameraDistance": float(3.5), "FOVDivision": float(4)])
        overrides.apply(from: ["cameraDistance": float(6)])
        #expect(overrides.current().cameraDistance == 6)
        #expect(overrides.current().fovDivision == nil)
        overrides.apply(from: [:])
        #expect(overrides.current().cameraDistance == nil)
    }

    @Test func invalidValuesAreIgnoredAndProjectionMixIsClamped() {
        let parsed = ScriptRenderOverrides.parse([
            "projectionMix": float(1.7),
            "cameraDistance": float(.nan),
            "orthographicProjectionHeight": float(0),
            "FOVDivision": StateValue(value: .string("4"))
        ])
        #expect(parsed.projectionMix == 1)
        #expect(parsed.cameraDistance == nil)
        #expect(parsed.orthographicProjectionHeight == nil)
        #expect(parsed.fovDivision == nil)
        #expect(ScriptRenderOverrides.parse(["FOVDivision": float(-2)]).fovDivision == nil)
        #expect(ScriptRenderOverrides.parse(["cameraDistance": float(1e300)]).cameraDistance == nil)
    }

    @Test func clearRemovesAllOverrides() {
        let overrides = ScriptRenderOverrides()
        overrides.apply(from: ["projectionMix": float(0)])
        overrides.clear()
        #expect(overrides.current().projectionMix == nil)
    }

    @Test func scriptOverridesWinOverSceneOverridesWhenMerged() {
        var scene = RenderConfigurationOverrides()
        scene.cameraDistance = 2
        scene.fovDivision = 5
        let script = ScriptRenderOverrides.parse(["cameraDistance": float(9)])
        let merged = scene.merged(with: script)
        #expect(merged.cameraDistance == 9)
        #expect(merged.fovDivision == 5)
    }
}
