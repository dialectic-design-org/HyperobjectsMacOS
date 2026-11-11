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

    // MARK: - Scripted objects (Cube)

    @Test func cubeInstancesBridgeAsObjectArray() async throws {
        let engine = JSEngineManager()
        let script = """
        var cube1 = new Cube({ "Width": 0.3, "Height": 0.8, "Position X": -0.8 });
        var cube2 = new Cube({ "Width": 0.2, "Height": 0.3, "Position X": 0.8 });
        cube1.set("Rotation Y", 1.5);
        cube1["LineWidth"] = 3;
        cube2.set({ "audio_add_Position Y": 0.5, "Rotation Origin X": 0.4 });
        var outputState = { "Cubes": [cube1, cube2] };
        """
        #expect(await run(engine, script) == nil)
        guard case .array(let cubes)? = engine.outputState["Cubes"]?.value else {
            Issue.record("Cubes is not an array: \(String(describing: engine.outputState["Cubes"]))")
            return
        }
        #expect(cubes.count == 2)
        guard case .object(let first) = cubes[0], case .object(let second) = cubes[1] else {
            Issue.record("Cubes elements are not objects")
            return
        }
        #expect(first["__type"] == .string("Cube"))
        #expect(first["Width"] == .float(0.3))
        #expect(first["Rotation Y"] == .float(1.5))
        #expect(first["LineWidth"] == .float(3))
        #expect(second["audio_add_Position Y"] == .float(0.5))
        #expect(second["Rotation Origin X"] == .float(0.4))
        // Only what the script set crosses the bridge, not the defaults or the methods.
        #expect(first.count == 6)
    }

    @Test func emptyCubeArrayAndSingleCubeBridge() async {
        let engine = JSEngineManager()
        #expect(await run(engine, "var outputState = { Cubes: [] };") == nil)
        #expect(engine.outputState["Cubes"] != nil)
        #expect(await run(engine, "var outputState = { Cubes: new Cube({ id: 'solo' }) };") == nil)
        guard case .object(let cube)? = engine.outputState["Cubes"]?.value else {
            Issue.record("A single Cube should bridge as an object")
            return
        }
        #expect(cube["id"] == .string("solo"))
    }

    @Test func unknownCubeParameterReportsUserLine() async {
        let engine = JSEngineManager()
        let error = await run(engine, "var a = 1;\nvar cube = new Cube({\n  \"Widht\": 0.3\n});\nvar outputState = { Cubes: [cube] };")
        #expect(error?.contains("Cube has no parameter \"Widht\"") == true)
        #expect(engine.errorLine == 2)
    }

    @Test func unknownCubeParameterThrowsForBracketAndDotAssignment() async {
        let engine = JSEngineManager()
        let bracket = await run(engine, "var cube = new Cube();\n\ncube[\"Widht\"] = 1;\nvar outputState = { Cubes: [cube] };")
        #expect(bracket?.contains("has no parameter \"Widht\"") == true)
        #expect(engine.errorLine == 3)

        let dot = await run(engine, "var cube = new Cube();\ncube.Widht = 1;\nvar outputState = { Cubes: [cube] };")
        #expect(dot?.contains("has no parameter \"Widht\"") == true)
        #expect(engine.errorLine == 2)

        let setter = await run(engine, "var cube = new Cube();\ncube.set(\"Heigth\", 1);\nvar outputState = { Cubes: [cube] };")
        #expect(setter?.contains("has no parameter \"Heigth\"") == true)
        #expect(engine.errorLine == 2)
    }

    @Test func unknownCubeParameterSuggestsClosestName() async {
        let engine = JSEngineManager()
        let typo = await run(engine, "var outputState = { Cubes: [new Cube({ \"Widht\": 1 })] };")
        #expect(typo?.contains("Did you mean \"Width\"?") == true)

        let capitalisation = await run(engine, "var outputState = { Cubes: [new Cube({ \"Rotation X delay\": 1 })] };")
        #expect(capitalisation?.contains("Did you mean \"Rotation X Delay\"?") == true)

        let prefixed = await run(engine, "var outputState = { Cubes: [new Cube({ \"audio_add_Widht\": 1 })] };")
        #expect(prefixed?.contains("Did you mean \"audio_add_Width\"?") == true)

        let unrelated = await run(engine, "var outputState = { Cubes: [new Cube({ \"zzzzzzzzzzzzzzzzzzzz\": 1 })] };")
        #expect(unrelated?.contains("has no parameter") == true)
        #expect(unrelated?.contains("Did you mean") == false)
    }

    @Test func cubeGetReturnsSchemaDefault() async {
        let engine = JSEngineManager()
        let script = """
        var cube = new Cube({ "Height": 0.9 });
        var outputState = { w: cube.get("Width"), h: cube.get("Height"), p: cube.get("Position X"),
                            u: cube.unset("Height").get("Height"), isCube: cube instanceof Cube };
        """
        #expect(await run(engine, script) == nil)
        #expect(engine.outputState["w"]?.value == .float(0.5))
        #expect(engine.outputState["h"]?.value == .float(0.9))
        #expect(engine.outputState["p"]?.value == .float(0))
        #expect(engine.outputState["u"]?.value == .float(0.5))
        #expect(engine.outputState["isCube"]?.value == .bool(true))
    }

    @Test func scriptSubclassOfCubeUsesTheCubeParameters() async {
        let engine = JSEngineManager()
        let script = """
        class Spinner extends Cube {
            constructor(speed) { super({ "Width": 0.2 }); this.set("Rotation Y", speed); }
        }
        var spinner = new Spinner(2);
        var outputState = { Cubes: [spinner], w: spinner.get("Height"), type: spinner.__type };
        """
        #expect(await run(engine, script) == nil)
        #expect(engine.outputState["w"]?.value == .float(0.5))
        #expect(engine.outputState["type"]?.value == .string("Cube"))
        let typo = await run(engine, "class Spinner extends Cube {}\nvar outputState = { Cubes: [new Spinner({ \"Widht\": 1 })] };")
        #expect(typo?.contains("Did you mean \"Width\"?") == true)
        #expect(engine.errorLine == 2)
    }

    @Test func cubeAcceptsEveryCubeSceneInputAndItsPrefixedKeys() async {
        let engine = JSEngineManager()
        let script = """
        var cube = new Cube();
        var names = Object.keys(Cube.defaults);
        for (var i = 0; i < names.length; i++) {
            cube[names[i]] = Cube.defaults[names[i]];
            cube["audio_add_" + names[i]] = 0;
            cube["audio_multiply_offset_" + names[i]] = 1;
            cube["frame_tick_" + names[i]] = 0;
        }
        var outputState = { count: names.length, Cubes: [cube] };
        """
        #expect(await run(engine, script) == nil)
        #expect(engine.outputState["count"]?.value == .float(Double(makeCubeSceneInputs().count)))
    }

    @Test func scriptedCubesReachTheLiveCodingScene() async throws {
        let engine = JSEngineManager()
        let script = """
        var outputState = {
            "Lines": [],
            "Cubes": [new Cube({ "Position X": -1 }), new Cube({ "Position X": 1, "Face offset": 0.1 })]
        };
        """
        #expect(await run(engine, script) == nil)

        let scene = generateGeometrySceneLiveCoding()
        let store = try #require(scene.objectStore)
        store.apply(from: engine.outputState, warningCache: ScriptOutputWarningCache())
        scene.updateInput(name: "Lines", value: [Line]())
        scene.setWrappedGeometries()
        // 12 edges for the plain cube, 24 for the one with a face offset.
        #expect(scene.renderBuffer.consume().geometries.count == 36)
    }

    @Test func stackFallbackFindsTheInnermostUserFrame() {
        let url = JSEngineManager.userScriptSourceURL.absoluteString
        let stack = "set@\nSceneObject@\nCube@\nmakeCube@\(url):90:25\nuserMain@\(url):95:3"
        #expect(JSEngineManager.userScriptLine(inStack: stack) == 90)
        #expect(JSEngineManager.userScriptLine(inStack: "set@\nglobal code@other.js:3:1") == nil)
    }

    @Test func userScriptLineOffsetMatchesWrapperPrefix() {
        let prefixLines = JSEngineManager.wrapperPrefix.components(separatedBy: "\n").count - 1
        #expect(JSEngineManager.userScriptLineOffset == prefixLines)
        #expect(JSEngineManager.wrapperPrefix.hasSuffix("\n"))
        #expect(JSEngineManager.wrapperSuffix.hasPrefix("\n"))
    }
}
