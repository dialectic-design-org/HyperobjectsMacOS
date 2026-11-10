//
//  LiveCodeEditorView.swift
//  HyperobjectsMacOS
//

import SwiftUI
import AppKit
import Combine

extension Notification.Name {
    static let liveCodeFocusEditor = Notification.Name("liveCodeFocusEditor")
}

/// NSTextView subclass: tab inserts spaces. Cmd+Return / Cmd+S are menu key equivalents
/// (LiveCodeCommands), so they work regardless of which view has focus.
final class LiveCodeTextView: NSTextView {
    override func insertTab(_ sender: Any?) {
        insertText("    ", replacementRange: selectedRange())
    }

    override var acceptsFirstResponder: Bool { isEditable }

    /// Cmd+/ (sent through the responder chain by LiveCodeCommands, so it only acts on the
    /// focused editor). Goes through shouldChangeText/didChangeText so it is undoable and
    /// updates the session like normal typing.
    @objc func toggleLineComment(_ sender: Any?) {
        guard isEditable,
              let edit = LiveCodeCommenting.toggle(text: string, selection: selectedRange()),
              shouldChangeText(in: edit.range, replacementString: edit.replacement) else { return }
        textStorage?.replaceCharacters(in: edit.range, with: edit.replacement)
        didChangeText()
        undoManager?.setActionName("Toggle Comment")
        setSelectedRange(edit.selection)
    }
}

struct LiveCodeEditorView: NSViewRepresentable {
    @ObservedObject var session: LiveCodeSession
    let isEditable: Bool
    /// Burned-in mode: the Metal rasterizer draws the code; this view stays as an invisible
    /// input surface (typing, selection, undo, IME keep working).
    var isInvisibleInputSurface: Bool = false
    var features = LiveCodeOverlayFeatures()

    func makeCoordinator() -> Coordinator { Coordinator(session: session) }

    func makeNSView(context: Context) -> NSScrollView {
        let coordinator = context.coordinator

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder

        // TextKit 1 on purpose: the line-number ruler and the Metal rasterizer reproduce this
        // layout with NSLayoutManager.
        let textView = LiveCodeTextView(usingTextLayoutManager: false)
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isEditable = isEditable
        textView.isSelectable = isEditable
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.insertionPointColor = .white
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.selectedTextAttributes = [.backgroundColor: NSColor.systemBlue.withAlphaComponent(0.5)]

        textView.textStorage?.delegate = coordinator.highlighter
        textView.delegate = coordinator
        scrollView.documentView = textView

        let ruler = LiveCodeLineNumberRuler(textView: textView, scrollView: scrollView)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = features.lineNumbers

        coordinator.textView = textView
        coordinator.scrollView = scrollView
        coordinator.ruler = ruler
        coordinator.attachObservers()

        coordinator.applyStyle(session.style)
        coordinator.syncText(session.text)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let c = context.coordinator
        c.parent = self
        c.isUpdatingFromSwiftUI = true
        defer { c.isUpdatingFromSwiftUI = false }

        c.applyStyle(session.style)
        c.syncText(session.text)

        if scrollView.rulersVisible != features.lineNumbers {
            scrollView.rulersVisible = features.lineNumbers
        }
        c.ruler?.errorLine = session.errorLine

        if !isEditable {
            c.showMirrorCaret(at: session.selectedRange)
        }
        c.showErrorLine(session.errorLine)
        c.runFlashIfNeeded(session.flash)

        let alpha: CGFloat = isInvisibleInputSurface ? 0 : 1
        if scrollView.alphaValue != alpha { scrollView.alphaValue = alpha }

        c.publishSnapshotIfNeeded()
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        coordinator.detachObservers()
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        let session: LiveCodeSession
        let highlighter = JSSyntaxHighlighter()
        var parent: LiveCodeEditorView?
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?
        weak var ruler: LiveCodeLineNumberRuler?

        var isUpdatingFromSwiftUI = false
        private var isApplyingExternalText = false
        private var appliedStyle: LiveCodeOverlayStyle?
        private var appliedErrorLine: Int?
        private var errorNeedsRefresh = true
        private var appliedMirrorCaret: NSRange?
        private var lastFlashID: UUID?
        private var flashTimer: Timer?
        private var flashTint: NSColor?
        private var observers: [NSObjectProtocol] = []
        private var infoSubscription: AnyCancellable?

        init(session: LiveCodeSession) { self.session = session }

        // MARK: Observers

        func attachObservers() {
            guard let scrollView else { return }
            let center = NotificationCenter.default

            observers.append(center.addObserver(forName: .liveCodeFocusEditor, object: nil, queue: .main) { [weak self] _ in
                guard let tv = self?.textView, tv.isEditable else { return }
                tv.window?.makeKeyAndOrderFront(nil)
                tv.window?.makeFirstResponder(tv)
            })

            // Scrolling and resizing move the text inside the overlay: republish for Metal.
            scrollView.contentView.postsBoundsChangedNotifications = true
            observers.append(center.addObserver(forName: NSView.boundsDidChangeNotification,
                                                object: scrollView.contentView, queue: .main) { [weak self] _ in
                self?.publishSnapshotIfNeeded()
            })
            scrollView.postsFrameChangedNotifications = true
            observers.append(center.addObserver(forName: NSView.frameDidChangeNotification,
                                                object: scrollView, queue: .main) { [weak self] _ in
                self?.publishSnapshotIfNeeded()
            })

            // Console / readout changes only matter to the burned-in snapshot.
            infoSubscription = session.info.objectWillChange.sink { [weak self] _ in
                // objectWillChange fires before the value changes; read it on the next turn.
                DispatchQueue.main.async { self?.publishSnapshotIfNeeded() }
            }
        }

        func detachObservers() {
            observers.forEach { NotificationCenter.default.removeObserver($0) }
            observers.removeAll()
            infoSubscription = nil
            flashTimer?.invalidate()
        }

        // MARK: Text sync

        func textDidChange(_ notification: Notification) {
            guard !isApplyingExternalText, let tv = textView else { return }
            errorNeedsRefresh = true
            if session.text != tv.string { session.text = tv.string }
            publishSnapshotIfNeeded()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isApplyingExternalText, let tv = textView, tv.isEditable else { return }
            let range = tv.selectedRange()
            if isUpdatingFromSwiftUI {
                // Don't publish from inside a SwiftUI view update.
                DispatchQueue.main.async { [weak self] in
                    if self?.session.selectedRange != range { self?.session.selectedRange = range }
                }
            } else if session.selectedRange != range {
                session.selectedRange = range
            }
            publishSnapshotIfNeeded()
        }

        /// External text change (file reload, accepted conflict, scratch): replace, keep caret.
        func syncText(_ text: String) {
            guard let tv = textView, tv.string != text else { return }
            let selection = tv.selectedRange()
            isApplyingExternalText = true
            tv.string = text
            if let storage = tv.textStorage { highlighter.highlight(storage) }
            let location = min(selection.location, (text as NSString).length)
            tv.setSelectedRange(NSRange(location: location, length: 0))
            isApplyingExternalText = false
            errorNeedsRefresh = true
            appliedMirrorCaret = nil
        }

        // MARK: Style

        func applyStyle(_ style: LiveCodeOverlayStyle) {
            guard style != appliedStyle, let tv = textView, let storage = tv.textStorage else { return }
            appliedStyle = style
            highlighter.font = .monospacedSystemFont(ofSize: style.fontSize, weight: .medium)
            highlighter.backdrop = NSColor.black.withAlphaComponent(style.lineBackdropOpacity)
            highlighter.textOpacity = style.textOpacity
            tv.typingAttributes = highlighter.baseAttributes
            tv.font = highlighter.font
            highlighter.highlight(storage)
            ruler?.font = LiveCodePanelMetrics.font(size: style.fontSize * 0.75)
            ruler?.backdrop = NSColor.black.withAlphaComponent(style.lineBackdropOpacity)
            ruler?.textOpacity = style.textOpacity
        }

        // MARK: Markers (temporary attributes: no undo entries, no re-highlight)

        func showErrorLine(_ line: Int?) {
            guard errorNeedsRefresh || line != appliedErrorLine,
                  let tv = textView, let lm = tv.layoutManager else { return }
            appliedErrorLine = line
            errorNeedsRefresh = false
            let full = NSRange(location: 0, length: (tv.string as NSString).length)
            lm.removeTemporaryAttribute(.underlineStyle, forCharacterRange: full)
            lm.removeTemporaryAttribute(.underlineColor, forCharacterRange: full)
            guard let line, let range = Self.characterRange(ofLine: line, in: tv.string) else { return }
            lm.addTemporaryAttributes([
                .underlineStyle: NSUnderlineStyle.thick.rawValue | NSUnderlineStyle.patternDot.rawValue,
                .underlineColor: NSColor.systemRed
            ], forCharacterRange: range)
        }

        func showMirrorCaret(at range: NSRange) {
            guard range != appliedMirrorCaret, let tv = textView, let lm = tv.layoutManager else { return }
            appliedMirrorCaret = range
            let length = (tv.string as NSString).length
            lm.removeTemporaryAttribute(.backgroundColor, forCharacterRange: NSRange(location: 0, length: length))
            guard length > 0 else { return }
            let caret = range.length > 0
                ? NSIntersectionRange(range, NSRange(location: 0, length: length))
                : NSRange(location: min(range.location, length - 1), length: 1)
            lm.addTemporaryAttribute(.backgroundColor, value: NSColor.white.withAlphaComponent(0.55), forCharacterRange: caret)
            tv.scrollRangeToVisible(caret)
        }

        func runFlashIfNeeded(_ flash: LiveCodeEvalFlash?) {
            guard let flash, flash.id != lastFlashID, let tv = textView, let lm = tv.layoutManager else { return }
            lastFlashID = flash.id
            let base = flash.succeeded ? NSColor.systemGreen : NSColor.systemRed
            var strength: CGFloat = 0.6
            flashTimer?.invalidate()
            flashTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self, weak tv] timer in
                guard let self, let tv else { timer.invalidate(); return }
                let full = NSRange(location: 0, length: (tv.string as NSString).length)
                strength -= 0.05
                if strength <= 0 {
                    lm.removeTemporaryAttribute(.foregroundColor, forCharacterRange: full)
                    self.flashTint = nil
                    timer.invalidate()
                } else {
                    // Tint the glyphs; the per-line backdrop keeps them readable.
                    let tint = base.blended(withFraction: 1 - strength, of: .white) ?? base
                    lm.addTemporaryAttribute(.foregroundColor,
                                             value: self.highlighter.textColor(tint),
                                             forCharacterRange: full)
                    self.flashTint = base.withAlphaComponent(strength * 0.6)
                }
                self.publishSnapshotIfNeeded()
            }
        }

        static func characterRange(ofLine line: Int, in text: String) -> NSRange? {
            let ns = text as NSString
            var current = 1
            var found: NSRange?
            ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length),
                                   options: [.byLines, .substringNotRequired]) { _, range, _, stop in
                if current == line { found = range; stop.pointee = true }
                current += 1
            }
            return found
        }

        // MARK: Burned-in snapshot

        func publishSnapshotIfNeeded() {
            guard let parent, parent.isEditable, parent.isInvisibleInputSurface,
                  let tv = textView, let storage = tv.textStorage, let sv = scrollView,
                  let textRect = visibleTextRectInRenderView() else { return }
            let text = storage.copy() as? NSAttributedString ?? NSAttributedString()
            let style = session.style
            let features = parent.features
            let geometry = session.overlayGeometry
            let snapshotFields = (
                caret: tv.selectedRange(),
                inset: tv.textContainerInset,
                containerWidth: tv.textContainer?.size.width ?? textRect.width,
                padding: tv.textContainer?.lineFragmentPadding ?? 5,
                scrollY: sv.contentView.bounds.origin.y,
                gutter: sv.rulersVisible ? (sv.verticalRulerView?.ruleThickness ?? 0) : 0
            )
            let errorMessage = session.errorMessage
            let errorLine = session.errorLine
            let console = features.console ? session.info.consoleTail : []
            let readout = features.inputReadout ? session.info.inputReadout : []
            let tint = flashTint
            session.overlayState.publish { version in
                LiveCodeOverlaySnapshot(
                    version: version,
                    attributedText: text,
                    caretRange: snapshotFields.caret,
                    errorLine: errorLine,
                    errorMessage: errorMessage,
                    viewSize: geometry?.viewSize ?? .zero,
                    textRect: textRect,
                    textInset: snapshotFields.inset,
                    containerWidth: snapshotFields.containerWidth,
                    lineFragmentPadding: snapshotFields.padding,
                    scrollOffsetY: snapshotFields.scrollY,
                    fontSize: style.fontSize,
                    backdropOpacity: style.lineBackdropOpacity,
                    textOpacity: style.textOpacity,
                    flashTint: tint,
                    gutterWidth: snapshotFields.gutter,
                    consoleTail: console,
                    inputReadout: readout
                )
            }
        }

        /// The scroll view's visible text area (clip view, excluding the ruler) in the
        /// RenderView's point space with a top-left origin.
        private func visibleTextRectInRenderView() -> CGRect? {
            guard let sv = scrollView, let content = sv.window?.contentView,
                  let geometry = session.overlayGeometry, geometry.viewSize.width > 0 else { return nil }
            let clip = sv.contentView
            var rect = clip.convert(clip.bounds, to: content)
            if !content.isFlipped {
                rect.origin.y = content.bounds.height - rect.maxY
            }
            rect.origin.x -= geometry.origin.x
            rect.origin.y -= geometry.origin.y
            return rect
        }
    }
}
