//
//  LiveCodeLineNumberRuler.swift
//  HyperobjectsMacOS
//

import AppKit

/// Line-number gutter for the live-code editor. Requires the TextKit 1 layout manager.
final class LiveCodeLineNumberRuler: NSRulerView {
    private weak var textView: NSTextView?

    var font: NSFont = LiveCodePanelMetrics.font(size: 16) {
        didSet { if font != oldValue { updateThickness(); needsDisplay = true } }
    }
    var backdrop = NSColor.black.withAlphaComponent(0.7) {
        didSet { if backdrop != oldValue { needsDisplay = true } }
    }
    var errorLine: Int? {
        didSet { if errorLine != oldValue { needsDisplay = true } }
    }
    var textOpacity: CGFloat = 1.0 {
        didSet { if textOpacity != oldValue { needsDisplay = true } }
    }
    private var textColor: NSColor { NSColor(white: 0.65, alpha: textOpacity) }

    init(textView: NSTextView, scrollView: NSScrollView) {
        self.textView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        updateThickness()
        NotificationCenter.default.addObserver(self, selector: #selector(textDidChange),
                                               name: NSText.didChangeNotification, object: textView)
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { NotificationCenter.default.removeObserver(self) }

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }

    @objc private func textDidChange() {
        updateThickness()
        needsDisplay = true
    }

    /// Gutter width for the current line count (grows past 99, 999, ...).
    static func thickness(lineCount: Int, font: NSFont) -> CGFloat {
        let digits = max(2, String(max(1, lineCount)).count)
        let digitWidth = ("8" as NSString).size(withAttributes: [.font: font]).width
        return ceil(CGFloat(digits) * digitWidth + 16)
    }

    private func updateThickness() {
        let lines = Self.lineCount(of: textView?.string ?? "")
        let width = Self.thickness(lineCount: lines, font: font)
        if abs(ruleThickness - width) > 0.5 { ruleThickness = width }
    }

    static func lineCount(of text: String) -> Int {
        text.utf16.reduce(1) { $1 == 10 ? $0 + 1 : $0 }
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let tv = textView, let lm = tv.layoutManager, let tc = tv.textContainer else { return }
        backdrop.setFill()
        bounds.fill()

        let ns = tv.string as NSString
        let inset = tv.textContainerInset.height

        func drawLabel(_ number: Int, fragment: NSRect) {
            let color = number == errorLine ? NSColor.systemRed.withAlphaComponent(textOpacity) : textColor
            let label = "\(number)" as NSString
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            let size = label.size(withAttributes: attrs)
            let y = convert(NSPoint(x: 0, y: fragment.minY + inset), from: tv).y
            label.draw(at: NSPoint(x: ruleThickness - size.width - 8,
                                   y: y + (fragment.height - size.height) / 2),
                       withAttributes: attrs)
        }

        if ns.length == 0 {
            drawLabel(1, fragment: lm.extraLineFragmentRect)
            return
        }

        let visibleGlyphs = lm.glyphRange(forBoundingRect: tv.visibleRect, in: tc)
        let visibleChars = lm.characterRange(forGlyphRange: visibleGlyphs, actualGlyphRange: nil)

        // Line number of the first visible line = newlines before it + 1.
        var index = ns.lineRange(for: NSRange(location: min(visibleChars.location, ns.length), length: 0)).location
        var lineNumber = 1
        for i in 0..<index where ns.character(at: i) == 10 { lineNumber += 1 }

        let end = NSMaxRange(visibleChars)
        while index < ns.length && index <= end {
            let lineRange = ns.lineRange(for: NSRange(location: index, length: 0))
            let glyphIndex = lm.glyphIndexForCharacter(at: lineRange.location)
            drawLabel(lineNumber, fragment: lm.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil))
            lineNumber += 1
            index = NSMaxRange(lineRange)
        }
        // Empty last line after a trailing newline.
        if index >= ns.length, ns.character(at: ns.length - 1) == 10, !lm.extraLineFragmentRect.isEmpty {
            drawLabel(lineNumber, fragment: lm.extraLineFragmentRect)
        }
    }
}
