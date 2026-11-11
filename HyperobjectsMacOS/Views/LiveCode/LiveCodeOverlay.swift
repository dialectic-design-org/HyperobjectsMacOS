//
//  LiveCodeOverlay.swift
//  HyperobjectsMacOS
//
//  The live-code layer that RenderView puts on top of the MTKView.
//

import SwiftUI

enum CodeOverlayRole {
    /// No code overlay (e.g. other uses of RenderView).
    case none
    /// Editable: the performer types here (main window).
    case editor
    /// Read-only audience view that follows the performer's caret (secondary render window).
    case mirror
}

/// The optional-feature toggles from RenderConfigurations, passed down as plain values so the
/// overlay does not need to observe RenderConfigurations itself.
struct LiveCodeOverlayFeatures: Equatable {
    var lineNumbers = false
    var console = false
    var inputReadout = false
}

struct LiveCodeOverlay: View {
    @ObservedObject var session: LiveCodeSession
    let role: CodeOverlayRole
    let output: CodeOverlayOutput
    let features: LiveCodeOverlayFeatures

    var body: some View {
        GeometryReader { geo in
            let rect = session.style.placement.rect(in: geo.size, fraction: session.style.sizeFraction)
            VStack(alignment: .leading, spacing: LiveCodePanelMetrics.spacing) {
                if features.inputReadout {
                    if output == .screen {
                        LiveCodeInputReadoutPanel(info: session.info, style: session.style)
                    } else {
                        LiveCodeReadoutPlaceholder(info: session.info, style: session.style)
                    }
                }

                LiveCodeEditorView(
                    session: session,
                    isEditable: role == .editor,
                    isInvisibleInputSurface: output == .burnedIn,
                    features: features
                )
                .frame(maxHeight: .infinity)
                // Performer only: an overlay, so the editor keeps its size and the burned-in
                // snapshot (which the audience sees) is not affected.
                .overlay(alignment: .top) {
                    if role == .editor {
                        LiveCodeParameterSearchPanel(search: session.parameterSearch, style: session.style)
                    }
                }

                if output == .screen {
                    if let message = session.errorMessage {
                        LiveCodeErrorBanner(message: message, line: session.errorLine, fontSize: session.style.infoFontSize)
                    }
                    if features.console {
                        LiveCodeConsolePanel(info: session.info, style: session.style)
                    }
                } else {
                    // The rasterizer draws the error line and console here; reserve the space.
                    LiveCodeBottomPlaceholder(info: session.info,
                                              style: session.style,
                                              hasError: session.errorMessage != nil,
                                              showsConsole: features.console)
                }

                if role == .editor || session.style.showStatusInMirror {
                    LiveCodeStatusStrip(session: session)
                }
            }
            .frame(width: max(rect.width, 0), height: max(rect.height, 0), alignment: .topLeading)
            .position(x: rect.midX, y: rect.midY)
            .onAppear { publishGeometry(geo) }
            .onChange(of: geo.frame(in: .global)) { _, _ in publishGeometry(geo) }
        }
        .allowsHitTesting(role == .editor)
    }

    private func publishGeometry(_ geo: GeometryProxy) {
        guard role == .editor else { return }
        let frame = geo.frame(in: .global)
        session.publishOverlayGeometry(origin: frame.origin, viewSize: frame.size)
    }
}

struct LiveCodeErrorBanner: View {
    let message: String
    let line: Int?
    let fontSize: CGFloat

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(line.map { "line \($0): \(message)" } ?? message)
                .lineLimit(3)
            Spacer(minLength: 0)
        }
        .font(.system(size: fontSize, weight: .medium, design: .monospaced))
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.red.opacity(0.75))
    }
}

struct LiveCodeStatusStrip: View {
    @ObservedObject var session: LiveCodeSession

    var body: some View {
        HStack(spacing: 10) {
            Text(session.displayName)
            if session.isDirty {
                Circle().fill(.orange).frame(width: 7, height: 7).help("Unsaved changes")
            }
            if session.hasUnevaluatedChanges {
                Text("⌘↩ to run").foregroundStyle(.yellow)
            }
            if session.pendingExternalText != nil {
                Text("File changed on disk").foregroundStyle(.orange)
                Button("Load") { session.acceptExternalChange() }
                Button("Keep mine") { session.keepLocalChanges() }
            }
            Spacer(minLength: 0)
            Text(session.evaluationMode.rawValue).foregroundStyle(.secondary)
        }
        .font(.system(size: 11, design: .monospaced))
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.6))
    }
}
