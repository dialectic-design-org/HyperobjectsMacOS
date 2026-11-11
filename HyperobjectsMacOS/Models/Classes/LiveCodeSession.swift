//
//  LiveCodeSession.swift
//  HyperobjectsMacOS
//
//  Owns the live-code editor buffer that is shown on top of the render view: two-way sync
//  with the script file, evaluation through the regular JSEngineManager path, error state,
//  overlay style and the optional info panels (console / input readout).
//

import SwiftUI
import AppKit
import Combine

enum LiveCodeEvaluationMode: String, CaseIterable, Identifiable {
    /// Only Cmd+Return evaluates.
    case manual = "Manual (⌘↩)"
    /// Cmd+S writes the file; the save also evaluates.
    case onSave = "On save (⌘S)"
    /// Debounced evaluation while typing. The last good script keeps running on errors.
    case live = "Live (debounced)"
    var id: String { rawValue }
}

enum LiveCodeOverlayPlacement: String, CaseIterable, Identifiable {
    case fullscreen = "Fullscreen"
    case left = "Left"
    case right = "Right"
    case bottom = "Bottom"
    var id: String { rawValue }

    /// Rect of the code panel inside a container of `size`, top-left origin (SwiftUI space).
    func rect(in size: CGSize, fraction: CGFloat, margin: CGFloat = 16) -> CGRect {
        let f = min(max(fraction, 0.2), 1.0)
        let inner = CGRect(origin: .zero, size: size).insetBy(dx: margin, dy: margin)
        guard inner.width > 0, inner.height > 0 else { return .zero }
        switch self {
        case .fullscreen:
            return inner
        case .left:
            return CGRect(x: inner.minX, y: inner.minY, width: inner.width * f, height: inner.height)
        case .right:
            let w = inner.width * f
            return CGRect(x: inner.maxX - w, y: inner.minY, width: w, height: inner.height)
        case .bottom:
            let h = inner.height * f
            return CGRect(x: inner.minX, y: inner.maxY - h, width: inner.width, height: h)
        }
    }
}

struct LiveCodeOverlayStyle: Equatable {
    var fontSize: CGFloat = 22
    var lineBackdropOpacity: Double = 0.7
    /// Opacity of the code glyphs (and line numbers); the backdrop has its own slider.
    var textOpacity: Double = 1.0
    var placement: LiveCodeOverlayPlacement = .left
    var sizeFraction: CGFloat = 0.55
    var showStatusInMirror: Bool = false

    /// Font for the secondary panels (console, readout, line numbers).
    var infoFontSize: CGFloat { max(9, fontSize * 0.6) }
}

/// Visual feedback after an evaluation (whole-buffer flash).
struct LiveCodeEvalFlash: Equatable {
    let id = UUID()
    let succeeded: Bool
}

/// An error shown in the overlay. `line` is 1-based in the user's script.
struct LiveCodeError: Equatable {
    var message: String
    var line: Int?
}

/// One line of the optional input readout panel.
struct LiveCodeReadoutRow: Equatable, Hashable {
    var key: String
    var value: String
}

final class LiveCodeSession: ObservableObject {
    // MARK: Buffer
    @Published var text: String = "" {
        didSet { if text != oldValue { textDidChange() } }
    }
    /// Caret/selection of the editor; mirrored by the read-only audience view.
    @Published var selectedRange = NSRange(location: 0, length: 0)

    // MARK: File sync
    @Published private(set) var fileURL: URL?
    @Published private(set) var lastSavedText: String = ""
    @Published private(set) var pendingExternalText: String?

    // MARK: Evaluation
    @Published private(set) var lastEvaluatedText: String = ""
    @Published var evaluationMode: LiveCodeEvaluationMode = .manual
    @Published var liveDebounceSeconds: Double = 0.5
    @Published private(set) var flash: LiveCodeEvalFlash?

    // MARK: Errors
    // Two sources: the result of the last evaluation from the editor (sticky until the next
    // evaluation succeeds) and the engine's current error (e.g. a runtime error thrown by the
    // running script in the 120 Hz loop). The evaluation error wins: with per-frame runs on,
    // the loop keeps running the last good script and would otherwise clear it immediately.
    @Published private(set) var errorMessage: String?
    @Published private(set) var errorLine: Int?
    private var evaluationError: LiveCodeError?
    private var engineError: LiveCodeError?

    // MARK: Style
    @Published var style = LiveCodeOverlayStyle()

    /// Optional info panels (console / input readout). A separate ObservableObject so its
    /// 10 Hz updates never re-render the editor, which observes the session.
    let info = LiveCodeInfoModel()

    /// Parameter search panel (performer only). Also a separate ObservableObject, so typing
    /// in the search field does not re-render the editor.
    let parameterSearch = LiveCodeParameterSearchModel()

    /// Injected by the App. Runs `script` through the regular JSEngineManager path and calls
    /// `done(nil)` on success or `done(error)` on a syntax/runtime error.
    var evaluator: ((_ script: String, _ done: @escaping (LiveCodeError?) -> Void) -> Void)?

    /// Thread-safe snapshot for the Metal rasterizer (burned-in output mode).
    let overlayState = LiveCodeOverlayState()

    /// Where the editor's RenderView sits in its window. Not @Published: no view depends on
    /// it; the editor reads it when publishing snapshots for the burned-in mode.
    private(set) var overlayGeometry: LiveCodeOverlayGeometry?

    private var liveDebounce: DispatchWorkItem?

    var isDirty: Bool { text != lastSavedText }
    var hasUnevaluatedChanges: Bool { text != lastEvaluatedText }
    var displayName: String { fileURL?.lastPathComponent ?? "scratch.js" }

    // MARK: File attachment

    /// Called right before `fileMonitor.startMonitoring(url:)`. The monitor's initial load
    /// arrives through `fileDidChangeOnDisk` and fills the buffer.
    func attach(url: URL) {
        fileURL = url
        lastSavedText = ""
        lastEvaluatedText = ""
        pendingExternalText = nil
        text = ""
    }

    func detach() {
        fileURL = nil
        lastSavedText = text   // buffer stays visible as a scratch buffer, not marked dirty
        pendingExternalText = nil
        lastEvaluatedText = ""
        clearError()
    }

    /// Starts an in-memory buffer that is not backed by a file.
    func startScratch(_ initialText: String) {
        fileURL = nil
        pendingExternalText = nil
        lastEvaluatedText = ""
        text = initialText
        lastSavedText = initialText
        clearError()
    }

    /// Routed from `FileMonitor`'s callback (main thread).
    func fileDidChangeOnDisk(_ content: String) {
        // Echo of our own in-place save.
        if content == lastSavedText {
            if evaluationMode == .onSave, content != lastEvaluatedText {
                evaluate(content)
            }
            return
        }
        let wasDirty = isDirty
        lastSavedText = content
        if wasDirty && !text.isEmpty {
            // The overlay has unsaved edits and the file changed under us: don't clobber either.
            pendingExternalText = content
            return
        }
        pendingExternalText = nil
        text = content
        evaluate(content)   // keeps the original behaviour: saving in an external editor runs the script
    }

    func acceptExternalChange() {
        guard let pending = pendingExternalText else { return }
        pendingExternalText = nil
        text = pending
        lastSavedText = pending
        evaluate(pending)
    }

    func keepLocalChanges() { pendingExternalText = nil }

    // MARK: Evaluation

    func evaluateBuffer() { evaluate(text) }

    func evaluate(_ script: String) {
        liveDebounce?.cancel()
        lastEvaluatedText = script
        guard let evaluator else { return }
        evaluator(script) { [weak self] error in
            guard let self else { return }
            self.flash = LiveCodeEvalFlash(succeeded: error == nil)
            self.evaluationError = error
            self.refreshDisplayedError()
        }
    }

    private func textDidChange() {
        guard evaluationMode == .live else { return }
        liveDebounce?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.hasUnevaluatedChanges else { return }
            self.evaluate(self.text)
        }
        liveDebounce = item
        DispatchQueue.main.asyncAfter(deadline: .now() + liveDebounceSeconds, execute: item)
    }

    // MARK: Saving

    enum SaveError: Error { case noFile }

    /// Writes in place (truncate + write) instead of atomically, so FileMonitor's
    /// DispatchSource on the original file descriptor keeps receiving events.
    func save() throws {
        guard let url = fileURL else { throw SaveError.noFile }
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.truncate(atOffset: 0)
        try handle.write(contentsOf: Data(text.utf8))
        lastSavedText = text
        pendingExternalText = nil
        // FileMonitor fires next; fileDidChangeOnDisk sees the echo and (in .onSave) evaluates.
    }

    #if DEBUG
    func markSavedForTesting() { lastSavedText = text }
    #endif

    // MARK: Errors

    /// Mirrors JSEngineManager's current error (called on change only, never per frame).
    func reportEngineError(_ message: String?, line: Int?) {
        engineError = message.map { LiveCodeError(message: $0, line: line) }
        refreshDisplayedError()
    }

    func clearError() {
        evaluationError = nil
        engineError = nil
        refreshDisplayedError()
    }

    private func refreshDisplayedError() {
        let shown = evaluationError ?? engineError
        if errorMessage != shown?.message { errorMessage = shown?.message }
        if errorLine != shown?.line { errorLine = shown?.line }
    }

    // MARK: Info panels

    func updateConsoleTail(_ tail: [String]) { info.updateConsoleTail(tail) }

    func updateInputReadout(_ rows: [LiveCodeReadoutRow]) { info.updateInputReadout(rows) }

    // MARK: Overlay geometry (burned-in mode)

    /// `origin` is the RenderView's top-left in window coordinates (SwiftUI `.global`).
    func publishOverlayGeometry(origin: CGPoint, viewSize: CGSize) {
        overlayGeometry = LiveCodeOverlayGeometry(origin: origin, viewSize: viewSize)
    }
}

final class LiveCodeInfoModel: ObservableObject {
    @Published private(set) var consoleTail: [String] = []
    @Published private(set) var inputReadout: [LiveCodeReadoutRow] = []

    func updateConsoleTail(_ tail: [String]) {
        if consoleTail != tail { consoleTail = tail }
    }

    func updateInputReadout(_ rows: [LiveCodeReadoutRow]) {
        if inputReadout != rows { inputReadout = rows }
    }
}

/// State of the parameter search panel in the code overlay: a query, the matching script
/// parameters and the selected row. Main thread only.
final class LiveCodeParameterSearchModel: ObservableObject {
    /// Number of result rows shown at once; the selection scrolls through the rest.
    static let pageSize = 10

    @Published private(set) var isPresented = false
    @Published var query = "" {
        didSet { if query != oldValue { refresh() } }
    }
    @Published private(set) var results: [ScriptParameterMatch] = []
    @Published private(set) var selectedIndex = 0
    /// Index of the first visible result row.
    @Published private(set) var windowStart = 0
    /// Number of parameters that can be searched.
    @Published private(set) var catalogCount = 0

    /// Injected by the App: the parameters a script can set in the current scene.
    var catalogProvider: (() -> [ScriptParameter])?
    private var catalog: [ScriptParameter] = []

    var selected: ScriptParameterMatch? {
        results.indices.contains(selectedIndex) ? results[selectedIndex] : nil
    }

    /// The result rows currently shown, with their index in `results`.
    var visibleResults: [(index: Int, match: ScriptParameterMatch)] {
        let end = min(windowStart + Self.pageSize, results.count)
        guard windowStart < end else { return [] }
        return (windowStart..<end).map { ($0, results[$0]) }
    }

    /// True when the catalog holds parameters of more than one owner (e.g. Cube and the scene).
    var showsOwner: Bool {
        guard let first = catalog.first else { return false }
        return catalog.contains { $0.owner != first.owner }
    }

    func present(seed: String = "") {
        catalog = catalogProvider?() ?? []
        catalogCount = catalog.count
        isPresented = true
        if query == seed {
            refresh()
        } else {
            query = seed
        }
    }

    func dismiss() {
        if isPresented { isPresented = false }
    }

    func moveSelection(by delta: Int) {
        guard !results.isEmpty else { return }
        select(min(max(selectedIndex + delta, 0), results.count - 1))
    }

    func select(_ index: Int) {
        guard results.indices.contains(index) else { return }
        selectedIndex = index
        if index < windowStart {
            windowStart = index
        } else if index >= windowStart + Self.pageSize {
            windowStart = index - Self.pageSize + 1
        }
    }

    private func refresh() {
        results = ScriptParameterCatalog.search(query, in: catalog)
        selectedIndex = 0
        windowStart = 0
    }
}

/// Non-observing environment entry for views that only pass the session along (RenderView).
/// `@EnvironmentObject` would subscribe to every keystroke; reading a plain reference doesn't.
private struct LiveCodeSessionKey: EnvironmentKey {
    static let defaultValue: LiveCodeSession? = nil
}

extension EnvironmentValues {
    var liveCodeSession: LiveCodeSession? {
        get { self[LiveCodeSessionKey.self] }
        set { self[LiveCodeSessionKey.self] = newValue }
    }
}

struct LiveCodeOverlayGeometry: Equatable {
    /// RenderView top-left in window coordinates (top-left origin).
    var origin: CGPoint
    var viewSize: CGSize
}

/// Shared sizing for the info panels so the SwiftUI placeholders (burned-in mode) and the
/// Metal rasterizer reserve exactly the same space.
enum LiveCodePanelMetrics {
    static let padding: CGFloat = 6
    static let spacing: CGFloat = 6

    static func font(size: CGFloat) -> NSFont { .monospacedSystemFont(ofSize: size, weight: .regular) }

    static func lineHeight(fontSize: CGFloat) -> CGFloat {
        ceil(NSLayoutManager().defaultLineHeight(for: font(size: fontSize)))
    }

    static func height(lineCount: Int, fontSize: CGFloat) -> CGFloat {
        lineCount == 0 ? 0 : CGFloat(lineCount) * lineHeight(fontSize: fontSize) + 2 * padding
    }
}

// MARK: - Snapshot for the Metal rasterizer

struct LiveCodeOverlaySnapshot {
    var version: UInt64
    /// Highlighted text (immutable copy of the editor's text storage).
    var attributedText: NSAttributedString
    var caretRange: NSRange?
    var errorLine: Int?
    var errorMessage: String?
    /// Geometry in the editor view's point space (top-left origin).
    var viewSize: CGSize
    /// Frame of the text view's visible area (excluding the line-number gutter).
    var textRect: CGRect
    var textInset: CGSize
    var containerWidth: CGFloat
    var lineFragmentPadding: CGFloat
    var scrollOffsetY: CGFloat
    var fontSize: CGFloat
    var backdropOpacity: Double
    var textOpacity: Double
    /// Evaluation flash, composited over the drawn text while it fades.
    var flashTint: NSColor?
    // Optional features, drawn by the rasterizer in burned-in mode.
    var gutterWidth: CGFloat
    var consoleTail: [String]
    var inputReadout: [LiveCodeReadoutRow]
}

/// Written on main, read from the render thread.
final class LiveCodeOverlayState {
    private let lock = NSLock()
    private var snapshot: LiveCodeOverlaySnapshot?
    private var version: UInt64 = 0

    func publish(_ make: (UInt64) -> LiveCodeOverlaySnapshot) {
        lock.lock(); defer { lock.unlock() }
        version &+= 1
        snapshot = make(version)
    }

    func clear() {
        lock.lock(); snapshot = nil; version &+= 1; lock.unlock()
    }

    func current() -> LiveCodeOverlaySnapshot? {
        lock.lock(); defer { lock.unlock() }
        return snapshot
    }
}
