//
//  LiveCodeCommands.swift
//  HyperobjectsMacOS
//
//  "Live Code" menu. Menu key equivalents are handled before the text view's keyDown, so
//  Cmd+Return evaluates whichever window or view has focus.
//

import SwiftUI
import AppKit

struct LiveCodeCommands: Commands {
    @ObservedObject var session: LiveCodeSession
    @ObservedObject var renderConfigs: RenderConfigurations

    var body: some Commands {
        CommandMenu("Live Code") {
            Button(renderConfigs.codeEvaluateAlsoSaves ? "Evaluate and Save" : "Evaluate") {
                LiveCodeActions.evaluate(session: session, alsoSave: renderConfigs.codeEvaluateAlsoSaves)
            }
            .keyboardShortcut(.return, modifiers: [.command])

            Button("Toggle Comment") {
                // Responder chain: only the focused live-code editor handles this.
                NSApp.sendAction(#selector(LiveCodeTextView.toggleLineComment(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("/", modifiers: [.command])

            Button("Save") { LiveCodeActions.save(session) }
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(session.fileURL == nil)

            Divider()

            Toggle("Show Code Overlay", isOn: $renderConfigs.showCodeOverlay)
                .keyboardShortcut("l", modifiers: [.command, .shift])

            Button("Focus Editor") {
                renderConfigs.showCodeOverlay = true
                NotificationCenter.default.post(name: .liveCodeFocusEditor, object: nil)
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])

            Button("Increase Font Size") { session.style.fontSize = min(session.style.fontSize + 2, 64) }
                .keyboardShortcut("=", modifiers: [.command])
            Button("Decrease Font Size") { session.style.fontSize = max(session.style.fontSize - 2, 10) }
                .keyboardShortcut("-", modifiers: [.command])
        }
    }
}

enum LiveCodeActions {
    /// Cmd+Return. Evaluates first, so lastEvaluatedText already equals the saved text and the
    /// FileMonitor echo of the save does not evaluate a second time (in any evaluation mode).
    static func evaluate(session: LiveCodeSession, alsoSave: Bool) {
        session.evaluateBuffer()
        if alsoSave, session.fileURL != nil {
            save(session)
        }
    }

    static func save(_ session: LiveCodeSession) {
        do {
            try session.save()
        } catch {
            print("[LiveCode] Save failed: \(error)")
        }
    }
}
