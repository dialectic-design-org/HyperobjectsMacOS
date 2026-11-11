//
//  ScriptParameterCatalogTests.swift
//  HyperobjectsMacOSTests
//

import Testing
import Foundation
import AppKit
@testable import HyperobjectsMacOS

@MainActor
struct ScriptParameterCatalogTests {

    private let cube = ScriptParameterCatalog.parameters(for: .cube)

    private func names(_ query: String) -> [String] {
        ScriptParameterCatalog.search(query, in: cube).map(\.key)
    }

    private func match(_ name: String, prefix: String = "") throws -> ScriptParameterMatch {
        let parameter = try #require(cube.first { $0.name == name })
        return ScriptParameterMatch(parameter: parameter, keyPrefix: prefix)
    }

    // MARK: - Catalog

    @Test func cubeCatalogListsEveryCubeInput() throws {
        #expect(cube.map(\.name) == makeCubeSceneInputs().map(\.name))
        #expect(cube.allSatisfy { $0.owner == "Cube" })

        let width = try #require(cube.first { $0.name == "Width" })
        #expect(width.defaultLiteral == "0.5")
        #expect(width.rangeText == "0…3")
        let count = try #require(cube.first { $0.name == "Outer Loop Cubes Count" })
        #expect(count.defaultLiteral == "1")
        #expect(count.rangeText == "1…20")
        let position = try #require(cube.first { $0.name == "Position X" })
        #expect(position.group == "Position")
        #expect(position.rangeText == "-3…3")
        let color = try #require(cube.first { $0.name == "Color start" })
        #expect(color.defaultLiteral == "[1, 1, 1, 1]")
        #expect(color.rangeText == nil)
    }

    @Test func sceneCatalogListsObjectParametersBeforeSceneInputs() {
        let scene = generateGeometrySceneLiveCoding()
        let parameters = ScriptParameterCatalog.parameters(for: scene)
        #expect(parameters.count == cube.count + scene.inputs.count)
        #expect(parameters.first?.owner == "Cube")
        #expect(parameters.suffix(2).map(\.name) == ["Lines", "Message"])
        #expect(parameters.suffix(2).allSatisfy { $0.owner == scene.name })

        // A scene without object collections only lists its own inputs.
        let cubeScene = generateGeometrySceneCube()
        #expect(ScriptParameterCatalog.parameters(for: cubeScene).allSatisfy { $0.owner == cubeScene.name })
    }

    // MARK: - Search

    @Test func parameterSearchMatchesAllPartsOfTheQuery() {
        let found = names("out spr x")
        #expect(found.first == "Outer Loop Cubes spread x")
        #expect(found.allSatisfy { $0.lowercased().contains("out") && $0.lowercased().contains("spr") && $0.lowercased().contains("x") })
        #expect(names("OUTER loop CUBES count") == ["Outer Loop Cubes Count"])
        #expect(names("no such parameter").isEmpty)
    }

    @Test func parameterSearchRanksNamesStartingWithTheQueryFirst() {
        let found = names("width")
        #expect(found.first == "Width")
        // "Width delay" starts with the query; "LineWidth" only contains it.
        let delay = found.firstIndex(of: "Width delay")
        let lineWidth = found.firstIndex(of: "LineWidth")
        #expect(delay != nil && lineWidth != nil)
        #expect(delay! < lineWidth!)

        // Every part starting a word ranks above a match inside a word.
        let rotation = names("rot x")
        #expect(rotation.first == "Rotation X")
    }

    @Test func parameterSearchKeepsScriptKeyPrefix() {
        #expect(names("audio_add_ wid").first == "audio_add_Width")
        #expect(names("audio_multiply_offset_width").first == "audio_multiply_offset_Width")
        #expect(names("audio_multiply_width").first == "audio_multiply_Width")
        #expect(names("frame_tick_stateful rotation x").first == "frame_tick_Stateful Rotation X")
        // The prefix alone lists every parameter with it.
        #expect(names("audio_delay_").count == cube.count)
        #expect(names("audio_delay_").first == "audio_delay_" + cube[0].name)
    }

    @Test func emptyParameterQueryListsEverythingInDeclarationOrder() {
        #expect(names("") == cube.map(\.name))
        #expect(names("   ") == cube.map(\.name))
    }

    // MARK: - Snippets

    @Test func parameterSnippetOmitsQuotesInsideOpenString() throws {
        let width = try match("Width")
        #expect(LiveCodeParameterSnippet.text(for: width, withDefault: false, insideString: false) == "\"Width\"")
        #expect(LiveCodeParameterSnippet.text(for: width, withDefault: false, insideString: true) == "Width")
        #expect(LiveCodeParameterSnippet.text(for: width, withDefault: true, insideString: true) == "Width")

        #expect(LiveCodeParameterSnippet.openStringContentStart(in: "cube.set(\"") == 10)
        #expect(LiveCodeParameterSnippet.openStringContentStart(in: "cube.set(\"Wid") == 10)
        #expect(LiveCodeParameterSnippet.openStringContentStart(in: "cube.set('Wid") == 10)
        #expect(LiveCodeParameterSnippet.openStringContentStart(in: "cube.set(\"Width\", ") == nil)
        #expect(LiveCodeParameterSnippet.openStringContentStart(in: "var a = \"x\\\"y") == 9)
        #expect(LiveCodeParameterSnippet.openStringContentStart(in: "var a = 1; // it's") == nil)
        #expect(LiveCodeParameterSnippet.openStringContentStart(in: "") == nil)
    }

    @Test func parameterSnippetAppendsDefaultLiteral() throws {
        #expect(LiveCodeParameterSnippet.text(for: try match("Width"), withDefault: true, insideString: false) == "\"Width\": 0.5")
        #expect(LiveCodeParameterSnippet.text(for: try match("Color mode"), withDefault: true, insideString: false).hasPrefix("\"Color mode\": \""))
        #expect(LiveCodeParameterSnippet.text(for: try match("Width", prefix: "audio_add_"), withDefault: true, insideString: false) == "\"audio_add_Width\": 0")
        #expect(LiveCodeParameterSnippet.text(for: try match("Width", prefix: "audio_multiply_offset_"), withDefault: true, insideString: false) == "\"audio_multiply_offset_Width\": 1")
    }

    @Test func parameterSearchSeedUsesSelectionOrOpenString() {
        let text = "var cube = new Cube();\ncube.set(\"out spr"
        let end = (text as NSString).length
        #expect(LiveCodeParameterSnippet.seed(text: text, selection: NSRange(location: end, length: 0)) == "out spr")
        #expect(LiveCodeParameterSnippet.seed(text: text, selection: NSRange(location: 4, length: 4)) == "cube")
        #expect(LiveCodeParameterSnippet.seed(text: text, selection: NSRange(location: 4, length: 0)) == "")
        #expect(LiveCodeParameterSnippet.seed(text: text, selection: NSRange(location: 0, length: end)) == "")
        #expect(LiveCodeParameterSnippet.seed(text: text, selection: NSRange(location: end + 5, length: 0)) == "")
    }

    // MARK: - Editor insertion

    private func makeEditor(_ text: String, selection: NSRange) -> LiveCodeTextView {
        let view = LiveCodeTextView(usingTextLayoutManager: false)
        view.string = text
        view.setSelectedRange(selection)
        return view
    }

    @Test func parameterInsertWritesQuotedNameAtTheCaret() throws {
        let editor = makeEditor("cube.set(, 1);", selection: NSRange(location: 9, length: 0))
        editor.insertParameter(LiveCodeParameterInsertion(match: try match("Width"), withDefault: false))
        #expect(editor.string == "cube.set(\"Width\", 1);")
        #expect(editor.selectedRange() == NSRange(location: 16, length: 0))
    }

    @Test func parameterInsertReplacesWhatWasTypedOfAnOpenString() throws {
        let text = "cube.set(\"out spr"
        let editor = makeEditor(text, selection: NSRange(location: (text as NSString).length, length: 0))
        editor.insertParameter(LiveCodeParameterInsertion(match: try match("Outer Loop Cubes spread x"), withDefault: true))
        #expect(editor.string == "cube.set(\"Outer Loop Cubes spread x")
    }

    @Test func parameterInsertReplacesTheSelection() throws {
        let editor = makeEditor("new Cube({ \"Widht\": 1 })", selection: NSRange(location: 12, length: 5))
        editor.insertParameter(LiveCodeParameterInsertion(match: try match("Width"), withDefault: false))
        #expect(editor.string == "new Cube({ \"Width\": 1 })")

        let block = makeEditor("new Cube({\n    XX\n})", selection: NSRange(location: 15, length: 2))
        block.insertParameter(LiveCodeParameterInsertion(match: try match("Height"), withDefault: true))
        #expect(block.string == "new Cube({\n    \"Height\": 0.5\n})")
    }

    // MARK: - Panel model

    @Test func searchModelFiltersSelectsAndScrolls() {
        let model = LiveCodeParameterSearchModel()
        model.catalogProvider = { ScriptParameterCatalog.parameters(for: .cube) }
        #expect(model.isPresented == false)

        model.present(seed: "width")
        #expect(model.isPresented)
        #expect(model.catalogCount == cube.count)
        #expect(model.selected?.key == "Width")
        #expect(model.showsOwner == false)

        model.moveSelection(by: -1)
        #expect(model.selectedIndex == 0)
        model.moveSelection(by: 1)
        #expect(model.selectedIndex == 1)

        // Browsing the whole list keeps the selection inside the visible rows.
        model.query = ""
        #expect(model.results.count == cube.count)
        #expect(model.selectedIndex == 0)
        model.moveSelection(by: 25)
        #expect(model.selectedIndex == 25)
        #expect(model.visibleResults.count == LiveCodeParameterSearchModel.pageSize)
        #expect(model.visibleResults.contains { $0.index == 25 })
        model.moveSelection(by: 10_000)
        #expect(model.selectedIndex == cube.count - 1)
        #expect(model.visibleResults.last?.index == cube.count - 1)
        model.moveSelection(by: -10_000)
        #expect(model.visibleResults.first?.index == 0)

        model.query = "no such parameter"
        #expect(model.selected == nil)
        #expect(model.visibleResults.isEmpty)

        model.dismiss()
        #expect(model.isPresented == false)
    }

    @Test func searchModelShowsOwnersForTheLiveCodingScene() {
        let model = LiveCodeParameterSearchModel()
        let scene = generateGeometrySceneLiveCoding()
        model.catalogProvider = { ScriptParameterCatalog.parameters(for: scene) }
        model.present()
        #expect(model.showsOwner)
        #expect(model.results.count == cube.count + 2)
        model.query = "message"
        #expect(model.selected?.parameter.owner == scene.name)
    }
}
