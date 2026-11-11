//
//  ScriptParameterCatalog.swift
//  HyperobjectsMacOS
//
//  The parameter names a live-coding script can set, for the parameter search in the code
//  overlay: the parameters of scripted objects (`Cube`) and the current scene's own inputs.
//

import Foundation

/// One searchable script parameter.
struct ScriptParameter: Identifiable, Equatable {
    /// "Cube", or the scene name for a flat outputState key.
    let owner: String
    let name: String
    let type: InputType
    let group: String?
    /// The default value, for display.
    let defaultText: String
    /// The default value as a JavaScript literal (`0.5`, `"HSL"`, `[1, 1, 1, 1]`), nil for
    /// types that have no short literal.
    let defaultLiteral: String?
    /// "0…3" for float and integer inputs.
    let rangeText: String?

    var id: String { owner + "/" + name }
}

/// A search result: a parameter, optionally addressed through a script key prefix.
struct ScriptParameterMatch: Identifiable, Equatable {
    let parameter: ScriptParameter
    /// "" or one of `ScriptInputApplier.keyPrefixes`, e.g. "audio_add_".
    let keyPrefix: String

    /// The key as it is written in a script.
    var key: String { keyPrefix + parameter.name }
    var id: String { parameter.owner + "/" + key }

    /// JavaScript literal of the key's default value.
    var defaultLiteral: String? {
        switch keyPrefix {
        case "": return parameter.defaultLiteral
        case "audio_multiply_offset_": return "1"
        case "audio_smoothed_source_": return "-1"
        default: return "0"
        }
    }
}

enum ScriptParameterCatalog {
    static func parameters(owner: String, inputs: [SceneInput]) -> [ScriptParameter] {
        inputs.map { input in
            let initial = input.initialStateValue()
            let literal = jsLiteral(initial)
            var rangeText: String?
            if input.type == .float || input.type == .integer {
                rangeText = number(Double(input.range.lowerBound)) + "…" + number(Double(input.range.upperBound))
            }
            return ScriptParameter(
                owner: owner,
                name: input.name,
                type: input.type,
                group: input.inputGroupName,
                defaultText: literal ?? initial.readoutString,
                defaultLiteral: literal,
                rangeText: rangeText
            )
        }
    }

    /// Everything a script can set in `scene`: the parameters of its scripted object kinds
    /// first, then the scene's own inputs.
    static func parameters(for scene: GeometriesSceneBase) -> [ScriptParameter] {
        var result: [ScriptParameter] = []
        let kinds = Set((scene.objectStore?.collections ?? [:]).values)
        for kind in ScriptedObjectKind.allCases where kinds.contains(kind) {
            result += parameters(for: kind)
        }
        result += parameters(owner: scene.name, inputs: scene.inputs)
        return result
    }

    /// The parameters of one object kind. Built once per kind.
    static func parameters(for kind: ScriptedObjectKind) -> [ScriptParameter] {
        kindParameters[kind] ?? []
    }

    private static let kindParameters: [ScriptedObjectKind: [ScriptParameter]] = {
        var result: [ScriptedObjectKind: [ScriptParameter]] = [:]
        for kind in ScriptedObjectKind.allCases {
            result[kind] = parameters(owner: kind.rawValue, inputs: kind.makeInputs())
        }
        return result
    }()

    /// All parameters that match `query`, best first.
    ///
    /// Matching ignores case. The query is split on spaces and every part has to occur in the
    /// name, so "out spr x" finds "Outer Loop Cubes spread x". A query that starts with a
    /// script key prefix ("audio_add_ wid") keeps that prefix in the results. Ranking: the
    /// exact name, names starting with the query, names in which every part starts a word,
    /// then any other match; shorter names first within a rank. An empty query returns
    /// everything in declaration order.
    static func search(_ query: String, in parameters: [ScriptParameter]) -> [ScriptParameterMatch] {
        var text = query.trimmingCharacters(in: .whitespaces).lowercased()
        var keyPrefix = ""
        for (prefix, _) in ScriptInputApplier.keyPrefixes where text.hasPrefix(prefix) {
            keyPrefix = prefix
            text = String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            break
        }
        let parts = text.split(separator: " ").map(String.init)
        if parts.isEmpty {
            return parameters.map { ScriptParameterMatch(parameter: $0, keyPrefix: keyPrefix) }
        }

        var ranked: [(rank: Int, length: Int, index: Int, parameter: ScriptParameter)] = []
        for (index, parameter) in parameters.enumerated() {
            let name = parameter.name.lowercased()
            guard parts.allSatisfy({ name.contains($0) }) else { continue }
            let rank: Int
            if name == text {
                rank = 0
            } else if name.hasPrefix(text) {
                rank = 1
            } else if parts.allSatisfy({ startsAWord($0, in: name) }) {
                rank = 2
            } else {
                rank = 3
            }
            ranked.append((rank, name.count, index, parameter))
        }
        ranked.sort { ($0.rank, $0.length, $0.index) < ($1.rank, $1.length, $1.index) }
        return ranked.map { ScriptParameterMatch(parameter: $0.parameter, keyPrefix: keyPrefix) }
    }

    private static func startsAWord(_ part: String, in name: String) -> Bool {
        name.hasPrefix(part) || name.contains(" " + part)
    }

    // MARK: - Literals

    /// A JavaScript literal for a default value, nil when there is no short one.
    static func jsLiteral(_ value: StateValue) -> String? {
        switch value.value {
        case .float(let d):
            return number(d)
        case .bool(let b):
            return b ? "true" : "false"
        case .string(let s):
            let escaped = s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            return "\"" + escaped + "\""
        case .vector4(let v):
            return "[" + [v.x, v.y, v.z, v.w].map(number).joined(separator: ", ") + "]"
        case .vector3(let v):
            return "[" + [v.x, v.y, v.z].map(number).joined(separator: ", ") + "]"
        default:
            return nil
        }
    }

    private static func number(_ d: Double) -> String {
        guard d.isFinite else { return "0" }
        return String(format: "%g", d)
    }
}

/// Text that the parameter search inserts into the editor.
enum LiveCodeParameterSnippet {
    /// UTF-16 offset in `linePrefix` (the caret's line up to the caret) at which the content of
    /// a still open string literal starts; nil when the caret is not inside a string.
    static func openStringContentStart(in linePrefix: String) -> Int? {
        let units = Array(linePrefix.utf16)
        let backslash: UInt16 = 0x5C, slash: UInt16 = 0x2F
        let quotes: Set<UInt16> = [0x22, 0x27, 0x60]   // " ' `
        var openQuote: UInt16?
        var contentStart = 0
        var i = 0
        while i < units.count {
            let unit = units[i]
            if let quote = openQuote {
                if unit == backslash {
                    i += 1   // skip the escaped character
                } else if unit == quote {
                    openQuote = nil
                }
            } else if quotes.contains(unit) {
                openQuote = unit
                contentStart = i + 1
            } else if unit == slash, i + 1 < units.count, units[i + 1] == slash {
                return nil   // the rest of the line is a comment
            }
            i += 1
        }
        return openQuote == nil ? nil : contentStart
    }

    /// `"Width"`; `Width` inside an open string literal; `"Width": 0.5` with `withDefault`
    /// (outside a string, when the default has a literal).
    static func text(for match: ScriptParameterMatch, withDefault: Bool, insideString: Bool) -> String {
        if insideString { return match.key }
        let quoted = "\"" + match.key + "\""
        if withDefault, let literal = match.defaultLiteral {
            return quoted + ": " + literal
        }
        return quoted
    }

    /// What the search field starts with: the selected text when it is a short single line,
    /// otherwise what was typed so far of a string literal at the caret.
    static func seed(text: String, selection: NSRange) -> String {
        let ns = text as NSString
        guard selection.location != NSNotFound, NSMaxRange(selection) <= ns.length else { return "" }
        if selection.length > 0 {
            let selected = ns.substring(with: selection)
            return selected.count <= 80 && !selected.contains("\n") ? selected : ""
        }
        let lineStart = ns.lineRange(for: NSRange(location: selection.location, length: 0)).location
        let linePrefix = ns.substring(with: NSRange(location: lineStart, length: selection.location - lineStart))
        guard let contentStart = openStringContentStart(in: linePrefix) else { return "" }
        return (linePrefix as NSString).substring(from: contentStart)
    }
}
