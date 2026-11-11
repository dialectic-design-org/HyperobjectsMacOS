//
//  LiveCodeParameterSearchPanel.swift
//  HyperobjectsMacOS
//
//  Search panel over the live-code editor (Cmd+Shift+P): type a few letters of a script
//  parameter, pick one, and Return writes its name at the editor's caret. Shown to the
//  performer only; it is not part of the burned-in overlay or the mirror window.
//

import SwiftUI
import AppKit

struct LiveCodeParameterSearchPanel: View {
    @ObservedObject var search: LiveCodeParameterSearchModel
    let style: LiveCodeOverlayStyle

    private var fontSize: CGFloat { max(style.infoFontSize, 12) }
    private var font: Font { Font(LiveCodePanelMetrics.font(size: fontSize)) }

    var body: some View {
        if search.isPresented {
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider().overlay(Color.white.opacity(0.25))
                if search.results.isEmpty {
                    Text(search.catalogCount == 0 ? "This scene has no script parameters" : "No parameter matches")
                        .foregroundStyle(Color(white: 0.6))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                } else {
                    ForEach(search.visibleResults, id: \.match.id) { row in
                        resultRow(row.match, isSelected: row.index == search.selectedIndex)
                            .contentShape(Rectangle())
                            .onTapGesture { insert(at: row.index, withDefault: false) }
                    }
                }
                Divider().overlay(Color.white.opacity(0.25))
                Text("↑↓ select    ↩ insert name    ⌥↩ insert with default    esc close")
                    .foregroundStyle(Color(white: 0.55))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
            }
            .font(font)
            .foregroundStyle(.white)
            .background(Color.black.opacity(0.92))
            .overlay(Rectangle().stroke(Color.white.opacity(0.35), lineWidth: 1))
            .frame(maxWidth: 720)
            .padding(10)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Color(white: 0.6))
            ParameterSearchField(text: $search.query, fontSize: fontSize) { command in
                handle(command)
            }
            .frame(height: LiveCodePanelMetrics.lineHeight(fontSize: fontSize) + 4)
            Text("\(search.results.count) of \(search.catalogCount)")
                .foregroundStyle(Color(white: 0.6))
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private func resultRow(_ match: ScriptParameterMatch, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            Text(match.key)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            if search.showsOwner {
                Text(match.parameter.owner)
                    .lineLimit(1)
                    .foregroundStyle(Color(white: 0.6))
            }
            Text(match.parameter.defaultText)
                .lineLimit(1)
                .monospacedDigit()
                .frame(minWidth: 60, alignment: .trailing)
            Text(match.parameter.rangeText ?? "")
                .lineLimit(1)
                .monospacedDigit()
                .foregroundStyle(Color(white: 0.6))
                .frame(minWidth: 90, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 2)
        .background(isSelected ? Color.accentColor.opacity(0.55) : Color.clear)
    }

    // MARK: - Actions

    private func handle(_ command: ParameterSearchField.Command) {
        switch command {
        case .up: search.moveSelection(by: -1)
        case .down: search.moveSelection(by: 1)
        case .pageUp: search.moveSelection(by: -LiveCodeParameterSearchModel.pageSize)
        case .pageDown: search.moveSelection(by: LiveCodeParameterSearchModel.pageSize)
        case .insert: insert(at: search.selectedIndex, withDefault: false)
        case .insertWithDefault: insert(at: search.selectedIndex, withDefault: true)
        case .cancel:
            search.dismiss()
            NotificationCenter.default.post(name: .liveCodeFocusEditor, object: nil)
        }
    }

    private func insert(at index: Int, withDefault: Bool) {
        search.select(index)
        guard let match = search.selected else { return }   // nothing to insert: stay open
        search.dismiss()
        // The editor takes focus back and writes the name at its caret.
        NotificationCenter.default.post(
            name: .liveCodeInsertParameter,
            object: search,
            userInfo: [LiveCodeParameterInsertion.userInfoKey: LiveCodeParameterInsertion(match: match, withDefault: withDefault)]
        )
    }
}

/// Single-line AppKit text field: takes focus when it appears and reports the keys the panel
/// acts on. AppKit rather than a SwiftUI TextField, because the field editor would otherwise
/// consume the arrow keys and Return.
private struct ParameterSearchField: NSViewRepresentable {
    enum Command {
        case up, down, pageUp, pageDown, insert, insertWithDefault, cancel
    }

    @Binding var text: String
    let fontSize: CGFloat
    let onCommand: (Command) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextField {
        let field = FocusingTextField(string: text)
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.textColor = .white
        field.font = LiveCodePanelMetrics.font(size: fontSize)
        field.placeholderString = "parameter name, e.g. spread x"
        field.usesSingleLineMode = true
        field.lineBreakMode = .byTruncatingTail
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text { field.stringValue = text }
        let font = LiveCodePanelMetrics.font(size: fontSize)
        if field.font != font { field.font = font }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: ParameterSearchField

        init(_ parent: ParameterSearchField) { self.parent = parent }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            if parent.text != field.stringValue { parent.text = field.stringValue }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.moveUp(_:)): parent.onCommand(.up)
            case #selector(NSResponder.moveDown(_:)): parent.onCommand(.down)
            case #selector(NSResponder.pageUp(_:)), #selector(NSResponder.scrollPageUp(_:)): parent.onCommand(.pageUp)
            case #selector(NSResponder.pageDown(_:)), #selector(NSResponder.scrollPageDown(_:)): parent.onCommand(.pageDown)
            case #selector(NSResponder.insertNewline(_:)): parent.onCommand(.insert)
            // Option+Return in a text field.
            case #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)): parent.onCommand(.insertWithDefault)
            case #selector(NSResponder.cancelOperation(_:)): parent.onCommand(.cancel)
            default: return false
            }
            return true
        }
    }
}

private final class FocusingTextField: NSTextField {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else { return }
        // On the next turn: the window is still laying out the new view at this point.
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            window.makeFirstResponder(self)
        }
    }
}
