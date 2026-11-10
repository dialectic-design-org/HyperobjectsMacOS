//
//  LiveCodeSessionTests.swift
//  HyperobjectsMacOSTests
//

import Testing
import Foundation
import AppKit
import Combine
@testable import HyperobjectsMacOS

@MainActor
struct LiveCodeSessionTests {

    /// Session whose evaluator records scripts and reports `result(script)` as the outcome.
    private final class Recorder {
        var evaluated: [String] = []
    }

    private func makeSession(result: @escaping (String) -> LiveCodeError? = { _ in nil }) -> (LiveCodeSession, Recorder) {
        let session = LiveCodeSession()
        let recorder = Recorder()
        session.evaluator = { script, done in
            recorder.evaluated.append(script)
            done(result(script))
        }
        return (session, recorder)
    }

    @Test func externalChangeIsAdoptedAndEvaluatedWhenBufferIsClean() {
        let (session, recorder) = makeSession()
        session.attach(url: URL(fileURLWithPath: "/tmp/a.js"))
        session.fileDidChangeOnDisk("outputState = {a: 1};")
        #expect(session.text == "outputState = {a: 1};")
        #expect(session.isDirty == false)
        #expect(recorder.evaluated == ["outputState = {a: 1};"])
    }

    @Test func externalChangeWhileDirtyRaisesConflictWithoutClobbering() {
        let (session, recorder) = makeSession()
        session.attach(url: URL(fileURLWithPath: "/tmp/a.js"))
        session.fileDidChangeOnDisk("v1")
        session.text = "v1 local edit"
        session.fileDidChangeOnDisk("v2 from vscode")
        #expect(session.text == "v1 local edit")
        #expect(session.pendingExternalText == "v2 from vscode")
        #expect(recorder.evaluated == ["v1"])

        session.acceptExternalChange()
        #expect(session.text == "v2 from vscode")
        #expect(session.pendingExternalText == nil)
        #expect(recorder.evaluated.last == "v2 from vscode")
    }

    @Test func keepLocalChangesDropsPendingExternalText() {
        let (session, _) = makeSession()
        session.attach(url: URL(fileURLWithPath: "/tmp/a.js"))
        session.fileDidChangeOnDisk("v1")
        session.text = "mine"
        session.fileDidChangeOnDisk("theirs")
        session.keepLocalChanges()
        #expect(session.pendingExternalText == nil)
        #expect(session.text == "mine")
    }

    @Test func echoOfOwnSaveIsIgnoredInManualMode() {
        let (session, recorder) = makeSession()
        session.attach(url: URL(fileURLWithPath: "/tmp/a.js"))
        session.fileDidChangeOnDisk("v1")
        session.text = "v2"
        session.markSavedForTesting()
        session.fileDidChangeOnDisk("v2")
        #expect(recorder.evaluated == ["v1"])
    }

    @Test func echoOfOwnSaveEvaluatesInOnSaveMode() {
        let (session, recorder) = makeSession()
        session.evaluationMode = .onSave
        session.attach(url: URL(fileURLWithPath: "/tmp/a.js"))
        session.fileDidChangeOnDisk("v1")
        session.text = "v2"
        session.markSavedForTesting()
        session.fileDidChangeOnDisk("v2")
        #expect(recorder.evaluated == ["v1", "v2"])
    }

    // Toggle "Cmd+Return also saves": evaluate first, then save, so the FileMonitor echo
    // must not evaluate a second time, in any evaluation mode.
    @Test func evaluateThenSaveDoesNotDoubleEvaluate() {
        for mode in LiveCodeEvaluationMode.allCases {
            let (session, recorder) = makeSession()
            session.evaluationMode = mode
            session.attach(url: URL(fileURLWithPath: "/tmp/a.js"))
            session.fileDidChangeOnDisk("v1")
            session.text = "v2"
            session.evaluateBuffer()
            session.markSavedForTesting()
            session.fileDidChangeOnDisk("v2")
            #expect(recorder.evaluated == ["v1", "v2"], "mode \(mode)")
        }
    }

    @Test func saveWritesInPlaceKeepingInode() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("live-\(UUID()).js")
        try "old content that is longer".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        let inodeBefore = try FileManager.default.attributesOfItem(atPath: url.path)[.systemFileNumber] as? Int

        let session = LiveCodeSession()
        session.attach(url: url)
        session.text = "new"
        try session.save()

        let inodeAfter = try FileManager.default.attributesOfItem(atPath: url.path)[.systemFileNumber] as? Int
        #expect(try String(contentsOf: url, encoding: .utf8) == "new")
        #expect(inodeBefore == inodeAfter)
        #expect(session.isDirty == false)
    }

    @Test func saveWithoutFileThrows() {
        let session = LiveCodeSession()
        session.startScratch("outputState = {};")
        #expect(throws: LiveCodeSession.SaveError.self) { try session.save() }
    }

    @Test func evaluationErrorStaysVisibleWhenEngineErrorClears() {
        let (session, _) = makeSession { _ in LiveCodeError(message: "SyntaxError: bad", line: 2) }
        session.startScratch("var b = ;")
        session.evaluateBuffer()
        #expect(session.errorMessage == "SyntaxError: bad")
        #expect(session.errorLine == 2)

        // The 120 Hz loop keeps running the last good script and clears the engine error.
        session.reportEngineError(nil, line: nil)
        #expect(session.errorMessage == "SyntaxError: bad")
    }

    @Test func successfulEvaluationClearsEvaluationError() {
        var fail = true
        let (session, _) = makeSession { _ in fail ? LiveCodeError(message: "Error: x", line: 1) : nil }
        session.startScratch("x()")
        session.evaluateBuffer()
        #expect(session.errorMessage != nil)
        fail = false
        session.evaluateBuffer()
        #expect(session.errorMessage == nil)
        #expect(session.flash?.succeeded == true)
    }

    @Test func engineRuntimeErrorIsShownWhenNoEvaluationError() {
        let (session, _) = makeSession()
        session.reportEngineError("Error: boom", line: 4)
        #expect(session.errorMessage == "Error: boom")
        #expect(session.errorLine == 4)
    }

    @Test func detachClearsErrorsAndKeepsBufferAsScratch() {
        let (session, _) = makeSession { _ in LiveCodeError(message: "Error", line: nil) }
        session.attach(url: URL(fileURLWithPath: "/tmp/a.js"))
        session.fileDidChangeOnDisk("broken()")
        session.detach()
        #expect(session.fileURL == nil)
        #expect(session.errorMessage == nil)
        #expect(session.text == "broken()")
        #expect(session.isDirty == false)
    }

    @Test func inputReadoutOnlyPublishesWhenValuesChange() {
        let session = LiveCodeSession()
        var publishes = 0
        let subscription = session.info.objectWillChange.sink { publishes += 1 }
        session.updateInputReadout([LiveCodeReadoutRow(key: "time", value: "1.000")])
        session.updateInputReadout([LiveCodeReadoutRow(key: "time", value: "1.000")])
        session.updateInputReadout([LiveCodeReadoutRow(key: "time", value: "1.100")])
        #expect(publishes == 2)
        subscription.cancel()
    }

    @Test func overlayPlacementRectsStayInsideContainer() {
        let size = CGSize(width: 1000, height: 600)
        for placement in LiveCodeOverlayPlacement.allCases {
            let rect = placement.rect(in: size, fraction: 0.5)
            #expect(CGRect(origin: .zero, size: size).contains(rect), "placement \(placement)")
            #expect(rect.width > 0 && rect.height > 0)
        }
    }
}

struct LiveCodeReadoutTests {

    @Test func stateValueReadoutStringIsShortForLargeValues() {
        let array = StateValue(value: .floatArray(Array(repeating: 0.5, count: 1000)))
        #expect(array.readoutString.hasPrefix("[1000]"))
        #expect(array.readoutString.count < 60)
    }

    @Test func readoutKeysAreTrimmedAndEmptyKeysDropped() {
        #expect(LiveCodeReadout.keys(from: " time, ,audioAmplitude ,") == ["time", "audioAmplitude"])
    }

    @Test func readoutResolvesDottedPathsAndMissingKeys() {
        let state: [String: StateValue] = [
            "time": StateValue(value: .float(1.5)),
            "midi": StateValue(value: .object(["knobs": .floatArray([0.25, 0.75])]))
        ]
        let rows = LiveCodeReadout.rows(keys: ["time", "midi.knobs.1", "nope"], state: state)
        #expect(rows.map(\.value) == ["1.500", "0.750", "—"])
    }

    @Test func lineNumberRulerCountsLinesAndGrowsGutter() {
        #expect(LiveCodeLineNumberRuler.lineCount(of: "") == 1)
        #expect(LiveCodeLineNumberRuler.lineCount(of: "a\nb\n") == 3)
        let font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        #expect(LiveCodeLineNumberRuler.thickness(lineCount: 1000, font: font)
                > LiveCodeLineNumberRuler.thickness(lineCount: 10, font: font))
    }

    @Test func jsSyntaxHighlighterColorsCommentsOverKeywords() {
        let highlighter = JSSyntaxHighlighter()
        let storage = NSTextStorage(string: "var x = 1; // var in comment")
        highlighter.highlight(storage)
        let ns = storage.string as NSString
        let keywordColor = storage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        let commentStart = ns.range(of: "// var").location + 3
        let commentColor = storage.attribute(.foregroundColor, at: commentStart, effectiveRange: nil) as? NSColor
        #expect(keywordColor == highlighter.theme.keyword)
        #expect(commentColor == highlighter.theme.comment)
    }
}
