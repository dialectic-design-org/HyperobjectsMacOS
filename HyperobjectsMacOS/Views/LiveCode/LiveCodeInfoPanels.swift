//
//  LiveCodeInfoPanels.swift
//  HyperobjectsMacOS
//
//  Optional panels around the live code: console output and a live inputState readout.
//

import SwiftUI

struct LiveCodeConsolePanel: View {
    @ObservedObject var info: LiveCodeInfoModel
    let style: LiveCodeOverlayStyle

    var body: some View {
        if !info.consoleTail.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(info.consoleTail.enumerated()), id: \.offset) { _, line in
                    Text("› " + line).lineLimit(1).truncationMode(.tail)
                }
            }
            .font(Font(LiveCodePanelMetrics.font(size: style.infoFontSize)))
            .foregroundStyle(Color(white: 0.85))
            .padding(LiveCodePanelMetrics.padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(style.lineBackdropOpacity))
        }
    }
}

struct LiveCodeInputReadoutPanel: View {
    @ObservedObject var info: LiveCodeInfoModel
    let style: LiveCodeOverlayStyle

    var body: some View {
        if !info.inputReadout.isEmpty {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 0) {
                ForEach(info.inputReadout, id: \.key) { row in
                    GridRow {
                        Text(row.key).foregroundStyle(Color(white: 0.6))
                        Text(row.value).monospacedDigit().lineLimit(1)
                    }
                }
            }
            .font(Font(LiveCodePanelMetrics.font(size: style.infoFontSize)))
            .foregroundStyle(.white)
            .padding(LiveCodePanelMetrics.padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(style.lineBackdropOpacity))
        }
    }
}

// MARK: - Burned-in placeholders (reserve the space the Metal rasterizer draws into)

struct LiveCodeReadoutPlaceholder: View {
    @ObservedObject var info: LiveCodeInfoModel
    let style: LiveCodeOverlayStyle

    var body: some View {
        let height = LiveCodePanelMetrics.height(lineCount: info.inputReadout.count, fontSize: style.infoFontSize)
        if height > 0 {
            Color.clear.frame(height: height)
        }
    }
}

struct LiveCodeBottomPlaceholder: View {
    @ObservedObject var info: LiveCodeInfoModel
    let style: LiveCodeOverlayStyle
    let hasError: Bool
    let showsConsole: Bool

    var body: some View {
        let lines = (hasError ? 1 : 0) + (showsConsole ? info.consoleTail.count : 0)
        let height = LiveCodePanelMetrics.height(lineCount: lines, fontSize: style.infoFontSize)
        if height > 0 {
            Color.clear.frame(height: height)
        }
    }
}

// MARK: - Readout formatting

extension StateValue {
    /// Short, stable text for the overlay readout.
    var readoutString: String {
        func f(_ d: Double) -> String { String(format: "%.3f", d) }
        switch value {
        case .float(let d): return f(d)
        case .bool(let b): return b ? "true" : "false"
        case .string(let s): return s.count > 24 ? String(s.prefix(24)) + "…" : s
        case .vector3(let v): return "(\(f(v.x)), \(f(v.y)), \(f(v.z)))"
        case .vector4(let v): return "(\(f(v.x)), \(f(v.y)), \(f(v.z)), \(f(v.w)))"
        case .floatArray(let a): return "[\(a.count)] " + a.prefix(4).map(f).joined(separator: " ")
        case .array(let a): return "[\(a.count) items]"
        case .object(let o):
            let keys = o.keys.sorted()
            return "{" + keys.prefix(4).joined(separator: ", ") + (keys.count > 4 ? ", …}" : "}")
        case .lineSegments(let l): return "\(l.count) segments"
        }
    }
}

enum LiveCodeReadout {
    /// Parses "time, audioAmplitude, midi.knobs" into trimmed, non-empty keys.
    static func keys(from list: String) -> [String] {
        list.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Resolves a key or dotted path ("midi.knobs") against an inputState snapshot.
    static func value(for path: String, in state: [String: StateValue]) -> StateValue? {
        // Exact keys win, so input names that contain dots still work.
        if let direct = state[path] { return direct }
        let parts = path.split(separator: ".").map(String.init)
        guard let first = parts.first, var current = state[first]?.value else { return nil }
        for part in parts.dropFirst() {
            switch current {
            case .object(let dict):
                guard let next = dict[part] else { return nil }
                current = next
            case .array(let items):
                guard let index = Int(part), items.indices.contains(index) else { return nil }
                current = items[index]
            case .floatArray(let items):
                guard let index = Int(part), items.indices.contains(index) else { return nil }
                current = .float(items[index])
            default:
                return nil
            }
        }
        return StateValue(value: current)
    }

    static func rows(keys: [String], state: [String: StateValue]) -> [LiveCodeReadoutRow] {
        keys.map { LiveCodeReadoutRow(key: $0, value: value(for: $0, in: state)?.readoutString ?? "—") }
    }
}
