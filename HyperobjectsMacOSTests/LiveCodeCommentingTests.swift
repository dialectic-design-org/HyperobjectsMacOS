//
//  LiveCodeCommentingTests.swift
//  HyperobjectsMacOSTests
//

import Testing
import Foundation
import AppKit
@testable import HyperobjectsMacOS

struct LiveCodeCommentingTests {

    /// Applies the toggle and returns (new text, new selection).
    private func apply(_ text: String, _ selection: NSRange) -> (String, NSRange)? {
        guard let edit = LiveCodeCommenting.toggle(text: text, selection: selection) else { return nil }
        let result = (text as NSString).replacingCharacters(in: edit.range, with: edit.replacement)
        return (result, edit.selection)
    }

    @Test func commentsCaretLineAndShiftsCaret() throws {
        let (text, sel) = try #require(apply("a = 1;\nb = 2;\n", NSRange(location: 9, length: 0)))
        #expect(text == "a = 1;\n// b = 2;\n")
        #expect(sel == NSRange(location: 12, length: 0))
    }

    @Test func uncommentsWithOrWithoutSpace() throws {
        #expect(try #require(apply("// a = 1;", NSRange(location: 4, length: 0))).0 == "a = 1;")
        #expect(try #require(apply("//a = 1;", NSRange(location: 4, length: 0))).0 == "a = 1;")
    }

    @Test func togglingTwiceRestoresTextAndSelection() throws {
        let original = "    x();\n    y();\n"
        let selection = NSRange(location: 6, length: 7)
        let (once, sel1) = try #require(apply(original, selection))
        let (twice, sel2) = try #require(apply(once, sel1))
        #expect(twice == original)
        #expect(sel2 == selection)
    }

    @Test func blockIsCommentedAtSmallestIndentAndBlankLinesSkipped() throws {
        let text = "if (a) {\n    b();\n\n}\n"
        let (result, _) = try #require(apply(text, NSRange(location: 0, length: (text as NSString).length)))
        #expect(result == "// if (a) {\n//     b();\n\n// }\n")
    }

    @Test func mixedBlockGetsCommentedNotUncommented() throws {
        let (result, _) = try #require(apply("// a();\nb();", NSRange(location: 0, length: 12)))
        #expect(result == "// // a();\n// b();")
    }

    @Test func selectionEndingAtLineStartExcludesNextLine() throws {
        // Selecting "a();\n" (full first line incl. newline) must not comment line 2.
        let (result, _) = try #require(apply("a();\nb();", NSRange(location: 0, length: 5)))
        #expect(result == "// a();\nb();")
    }

    @Test func blankOrEmptyLinesAreNoOps() {
        #expect(LiveCodeCommenting.toggle(text: "", selection: NSRange(location: 0, length: 0)) == nil)
        #expect(LiveCodeCommenting.toggle(text: "a();\n   \n", selection: NSRange(location: 6, length: 0)) == nil)
        #expect(LiveCodeCommenting.toggle(text: "a();\n", selection: NSRange(location: 5, length: 0)) == nil)
    }

    @Test func textOpacityAppliesToHighlightedColorsAndShadow() {
        let highlighter = JSSyntaxHighlighter()
        highlighter.textOpacity = 0.4
        let storage = NSTextStorage(string: "var x = 1; // note")
        highlighter.highlight(storage)
        let keyword = storage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        let comment = storage.attribute(.foregroundColor, at: 12, effectiveRange: nil) as? NSColor
        let shadow = storage.attribute(.shadow, at: 0, effectiveRange: nil) as? NSShadow
        #expect(abs((keyword?.alphaComponent ?? 0) - 0.4) < 0.001)
        #expect(abs((comment?.alphaComponent ?? 0) - 0.4) < 0.001)
        #expect(abs((shadow?.shadowColor?.alphaComponent ?? 0) - 0.36) < 0.001)
    }
}
