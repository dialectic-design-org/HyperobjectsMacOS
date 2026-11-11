//
//  LiveCodeParameterSearchPanelTests.swift
//  HyperobjectsMacOSTests
//
//  Drives the real overlay (editor + search panel) in an off-screen window: focus, the keys
//  the search field handles, and the insertion at the editor's caret.
//

import Testing
import Foundation
import AppKit
import SwiftUI
@testable import HyperobjectsMacOS

// Serialized: the "focus editor" notification is app-wide, so two overlays that are open at
// the same time would take the keyboard focus from each other.
@MainActor
@Suite(.serialized)
struct LiveCodeParameterSearchPanelTests {

    private func makeWindow(_ session: LiveCodeSession) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: -20_000, y: -20_000, width: 900, height: 600),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: LiveCodeOverlay(
            session: session, role: .editor, output: .screen, features: LiveCodeOverlayFeatures()))
        window.contentView?.layoutSubtreeIfNeeded()
        return window
    }

    /// Lets SwiftUI and the main queue catch up.
    private func settle() async {
        for _ in 0..<6 {
            try? await Task.sleep(for: .milliseconds(25))
        }
    }

    private func find<T: NSView>(_ type: T.Type, in view: NSView?) -> T? {
        guard let view else { return nil }
        if let match = view as? T { return match }
        for subview in view.subviews {
            if let match = find(type, in: subview) { return match }
        }
        return nil
    }

    @Test func searchPanelTakesFocusFiltersAndInsertsAtTheCaret() async throws {
        let session = LiveCodeSession()
        session.text = "var cube = new Cube();\ncube.set("
        session.parameterSearch.catalogProvider = { ScriptParameterCatalog.parameters(for: .cube) }
        let window = makeWindow(session)
        defer { window.close() }
        await settle()

        let editor = try #require(find(LiveCodeTextView.self, in: window.contentView))
        #expect(editor.string == session.text)
        window.makeFirstResponder(editor)
        editor.setSelectedRange(NSRange(location: (editor.string as NSString).length, length: 0))
        #expect(find(NSTextField.self, in: window.contentView) == nil)

        // Open: the search field appears and takes the keyboard focus.
        session.parameterSearch.present()
        await settle()
        let field = try #require(find(NSTextField.self, in: window.contentView))
        let fieldEditor = try #require(window.firstResponder as? NSTextView)
        #expect(fieldEditor.delegate === field)

        // Typing filters.
        fieldEditor.insertText("out spr x", replacementRange: NSRange(location: NSNotFound, length: 0))
        #expect(session.parameterSearch.query == "out spr x")
        #expect(session.parameterSearch.selected?.key == "Outer Loop Cubes spread x")

        // Arrow keys move the selection instead of the text cursor.
        fieldEditor.doCommand(by: #selector(NSResponder.moveDown(_:)))
        #expect(session.parameterSearch.selectedIndex == 1)
        fieldEditor.doCommand(by: #selector(NSResponder.moveUp(_:)))
        #expect(session.parameterSearch.selectedIndex == 0)

        // Return inserts at the editor's caret, closes the panel and returns the focus.
        fieldEditor.doCommand(by: #selector(NSResponder.insertNewline(_:)))
        await settle()
        #expect(session.parameterSearch.isPresented == false)
        #expect(editor.string == "var cube = new Cube();\ncube.set(\"Outer Loop Cubes spread x\"")
        #expect(session.text == editor.string)
        #expect(window.firstResponder === editor)
        #expect(find(NSTextField.self, in: window.contentView) == nil)
    }

    @Test func optionReturnInsertsTheDefaultAndEscapeClosesThePanel() async throws {
        let session = LiveCodeSession()
        session.text = "var cube = new Cube({\n    \n});"
        session.parameterSearch.catalogProvider = { ScriptParameterCatalog.parameters(for: .cube) }
        let window = makeWindow(session)
        defer { window.close() }
        await settle()

        let editor = try #require(find(LiveCodeTextView.self, in: window.contentView))
        window.makeFirstResponder(editor)
        editor.setSelectedRange(NSRange(location: 26, length: 0))

        session.parameterSearch.present(seed: "position x")
        await settle()
        var fieldEditor = try #require(window.firstResponder as? NSTextView)
        #expect(fieldEditor.string == "position x")
        fieldEditor.doCommand(by: #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)))
        await settle()
        #expect(editor.string == "var cube = new Cube({\n    \"Position X\": 0\n});")

        // Escape closes without inserting.
        session.parameterSearch.present()
        await settle()
        fieldEditor = try #require(window.firstResponder as? NSTextView)
        #expect(fieldEditor !== editor)
        fieldEditor.doCommand(by: #selector(NSResponder.cancelOperation(_:)))
        await settle()
        #expect(session.parameterSearch.isPresented == false)
        #expect(editor.string == "var cube = new Cube({\n    \"Position X\": 0\n});")
        #expect(window.firstResponder === editor)
    }
}
