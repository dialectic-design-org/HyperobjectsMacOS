//
//  JSSyntaxHighlighter.swift
//  HyperobjectsMacOS
//

import AppKit

/// Regex-based JS highlighter applied as NSTextStorage attributes.
/// Also applies the per-line backdrop: `.backgroundColor` paints behind glyph runs only,
/// which gives the Hydra-style "highlighted line" look over the visuals.
final class JSSyntaxHighlighter: NSObject, NSTextStorageDelegate {
    struct Theme {
        var base = NSColor(white: 0.95, alpha: 1)
        var keyword = NSColor(calibratedRed: 1.00, green: 0.47, blue: 0.66, alpha: 1)
        var number = NSColor(calibratedRed: 0.68, green: 0.85, blue: 1.00, alpha: 1)
        var string = NSColor(calibratedRed: 0.65, green: 0.89, blue: 0.53, alpha: 1)
        var comment = NSColor(white: 0.6, alpha: 1)
        var global = NSColor(calibratedRed: 1.00, green: 0.80, blue: 0.40, alpha: 1)
    }

    var theme = Theme()
    var font: NSFont = .monospacedSystemFont(ofSize: 22, weight: .medium)
    var backdrop: NSColor = NSColor.black.withAlphaComponent(0.7)
    /// Applied to every foreground colour and to the glyph shadow.
    var textOpacity: CGFloat = 1.0 {
        didSet { glyphShadow = Self.makeShadow(opacity: textOpacity) }
    }

    /// Soft glyph shadow so text stays readable over busy visuals. Fades with the text, so
    /// low text opacity doesn't leave a dark halo behind.
    private var glyphShadow = JSSyntaxHighlighter.makeShadow(opacity: 1.0)

    private static func makeShadow(opacity: CGFloat) -> NSShadow {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.9 * opacity)
        shadow.shadowBlurRadius = 3
        shadow.shadowOffset = .zero
        return shadow
    }

    /// A theme colour with the text opacity applied.
    func textColor(_ color: NSColor) -> NSColor {
        color.withAlphaComponent(color.alphaComponent * textOpacity)
    }

    var baseAttributes: [NSAttributedString.Key: Any] {
        [.font: font, .foregroundColor: textColor(theme.base), .backgroundColor: backdrop, .shadow: glyphShadow]
    }

    private static func re(_ pattern: String) -> NSRegularExpression {
        // Patterns are compile-time constants; a failure here is a programming error.
        try! NSRegularExpression(pattern: pattern)
    }
    private static let keyword = re(#"\b(var|let|const|function|return|if|else|for|while|do|break|continue|new|this|typeof|instanceof|in|of|true|false|null|undefined|switch|case|default|try|catch|finally|throw|class|extends)\b"#)
    // Globals provided by JSInternalStateRuntime / JSEngineManager.
    private static let global = re(#"\b(inputState|outputState|baseState|internalState|runtime|persist|resetInternalState|internalStateVersion|Weights|Math|console)\b"#)
    private static let number = re(#"\b\d+(\.\d+)?([eE][+-]?\d+)?\b"#)
    private static let string = re(#""(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*'|`(?:[^`\\]|\\.)*`"#)
    private static let comment = re(#"//[^\n]*|/\*[\s\S]*?\*/"#)

    func textStorage(_ textStorage: NSTextStorage,
                     didProcessEditing editedMask: NSTextStorageEditActions,
                     range editedRange: NSRange,
                     changeInLength delta: Int) {
        guard editedMask.contains(.editedCharacters) else { return }
        // Block comments and template strings span lines, so highlight the whole buffer.
        // Live-coding scripts are small (< ~1k lines); this stays well under a millisecond.
        highlight(textStorage)
    }

    func highlight(_ storage: NSTextStorage) {
        let full = NSRange(location: 0, length: storage.length)
        guard full.length > 0 else { return }
        let s = storage.string
        storage.setAttributes(baseAttributes, range: full)
        // Later rules win: strings and comments override keywords inside them.
        apply(Self.global, theme.global, s, storage)
        apply(Self.keyword, theme.keyword, s, storage)
        apply(Self.number, theme.number, s, storage)
        apply(Self.string, theme.string, s, storage)
        apply(Self.comment, theme.comment, s, storage)
    }

    private func apply(_ regex: NSRegularExpression, _ color: NSColor, _ s: String, _ storage: NSTextStorage) {
        regex.enumerateMatches(in: s, range: NSRange(location: 0, length: (s as NSString).length)) { match, _, _ in
            if let range = match?.range { storage.addAttribute(.foregroundColor, value: textColor(color), range: range) }
        }
    }
}
