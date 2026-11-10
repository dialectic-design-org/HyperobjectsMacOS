//
//  LiveCodeCommenting.swift
//  HyperobjectsMacOS
//
//  Cmd+/ line-comment toggling for the live-code editor (pure text logic, unit-tested).
//

import Foundation

enum LiveCodeCommenting {
    struct Edit: Equatable {
        /// Range of the original text to replace (whole lines).
        var range: NSRange
        var replacement: String
        /// Selection to apply afterwards, in the new text.
        var selection: NSRange
    }

    /// Toggles `// ` line comments on every line touched by `selection` (like VS Code):
    /// - if every non-blank line is already commented, the comment markers are removed;
    /// - otherwise `// ` is inserted at the smallest indentation of the non-blank lines,
    ///   so the block stays aligned. Blank lines are left alone.
    /// Offsets are UTF-16 (NSString / NSTextView). Returns nil when there is nothing to do.
    static func toggle(text: String, selection: NSRange) -> Edit? {
        let ns = text as NSString
        let length = ns.length
        let start = min(max(selection.location, 0), length)
        var end = min(start + max(selection.length, 0), length)
        // A selection that ends right after a newline doesn't include the next line.
        if end > start, ns.character(at: end - 1) == newline { end -= 1 }

        let block = ns.lineRange(for: NSRange(location: start, length: end - start))

        // Lines in the block: content range excludes the line terminator.
        var lines: [NSRange] = []
        ns.enumerateSubstrings(in: block, options: [.byLines, .substringNotRequired]) { _, range, _, _ in
            lines.append(range)
        }
        if lines.isEmpty {
            // Caret on an empty last line (after a trailing newline): nothing to comment.
            return nil
        }

        let nonBlank = lines.filter { indentation(of: $0, in: ns) < $0.length }
        guard !nonBlank.isEmpty else { return nil }

        let allCommented = nonBlank.allSatisfy { line in
            let indent = indentation(of: line, in: ns)
            return ns.substring(with: NSRange(location: line.location + indent, length: line.length - indent)).hasPrefix("//")
        }

        // Edits in original coordinates: (location, removedLength, insertedText).
        var edits: [(location: Int, removed: Int, inserted: String)] = []
        if allCommented {
            for line in nonBlank {
                let markerStart = line.location + indentation(of: line, in: ns)
                let afterMarker = markerStart + 2
                let removeSpace = afterMarker < NSMaxRange(line) && ns.character(at: afterMarker) == space
                edits.append((markerStart, removeSpace ? 3 : 2, ""))
            }
        } else {
            let column = nonBlank.map { indentation(of: $0, in: ns) }.min() ?? 0
            for line in nonBlank {
                edits.append((line.location + column, 0, "// "))
            }
        }

        // Build the replacement for the block.
        let replacement = NSMutableString(string: ns.substring(with: block))
        for edit in edits.reversed() {
            replacement.replaceCharacters(in: NSRange(location: edit.location - block.location, length: edit.removed),
                                          with: edit.inserted)
        }

        // Map the original selection into the new text.
        func map(_ position: Int) -> Int {
            var shifted = position
            for edit in edits {
                let delta = (edit.inserted as NSString).length - edit.removed
                if position >= edit.location + edit.removed {
                    shifted += delta
                } else if position > edit.location {
                    // Inside a removed marker: snap to where the marker was.
                    shifted -= position - edit.location
                }
            }
            return shifted
        }
        let newStart = map(start)
        let newEnd = map(min(start + max(selection.length, 0), length))
        return Edit(range: block,
                    replacement: replacement as String,
                    selection: NSRange(location: newStart, length: max(0, newEnd - newStart)))
    }

    private static let newline: unichar = 10
    private static let space: unichar = 32
    private static let tab: unichar = 9

    /// Number of leading spaces/tabs in `line`.
    private static func indentation(of line: NSRange, in ns: NSString) -> Int {
        var count = 0
        while count < line.length {
            let c = ns.character(at: line.location + count)
            guard c == space || c == tab else { break }
            count += 1
        }
        return count
    }
}
