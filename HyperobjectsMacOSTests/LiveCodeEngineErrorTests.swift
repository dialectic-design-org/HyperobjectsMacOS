//
//  LiveCodeEngineErrorTests.swift
//  HyperobjectsMacOSTests
//

import Testing
import Foundation
@testable import HyperobjectsMacOS

@MainActor
struct LiveCodeEngineErrorTests {

    /// Runs a script and returns nil on success or the error message on failure.
    private func run(_ engine: JSEngineManager, _ script: String) async -> String? {
        await withCheckedContinuation { continuation in
            _ = engine.executeScript(
                script,
                inputState: [:],
                completion: { _ in continuation.resume(returning: nil) },
                failure: { continuation.resume(returning: $0) }
            )
        }
    }

    @Test func syntaxErrorReportsLineInUserScriptCoordinates() async {
        let engine = JSEngineManager()
        let error = await run(engine, "var a = 1;\nvar b = ;\noutputState = {};")
        #expect(error?.hasPrefix("SyntaxError") == true)
        #expect(engine.errorLine == 2)
    }

    @Test func runtimeErrorReportsLineInUserScriptCoordinates() async {
        let engine = JSEngineManager()
        let error = await run(engine, "outputState = {};\n\nundefinedFunction();")
        #expect(error != nil)
        #expect(engine.errorLine == 3)
    }

    @Test func syntaxErrorKeepsPreviousScriptCompiled() async {
        let engine = JSEngineManager()
        #expect(await run(engine, "outputState = {x: 1};") == nil)
        #expect(await run(engine, "outputState = {x: ;") != nil)
        // The previous userMain is still defined: the good script runs without recompiling.
        #expect(await run(engine, "outputState = {x: 1};") == nil)
        #expect(engine.outputState["x"] != nil)
        #expect(engine.errorMessage == nil)
        #expect(engine.errorLine == nil)
    }

    @Test func userScriptLineOffsetMatchesWrapperPrefix() {
        let prefixLines = JSEngineManager.wrapperPrefix.components(separatedBy: "\n").count - 1
        #expect(JSEngineManager.userScriptLineOffset == prefixLines)
        #expect(JSEngineManager.wrapperPrefix.hasSuffix("\n"))
        #expect(JSEngineManager.wrapperSuffix.hasPrefix("\n"))
    }
}
