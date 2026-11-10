//
//  LiveCodeSettingsView.swift
//  HyperobjectsMacOS
//
//  Live code overlay controls, embedded in RenderConfigurationsView.
//

import SwiftUI

struct LiveCodeSettingsView: View {
    @EnvironmentObject var renderConfigurations: RenderConfigurations
    @EnvironmentObject var session: LiveCodeSession

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LIVE CODE OVERLAY").fontWeight(.bold)

            Toggle("Show code overlay (⇧⌘L)", isOn: $renderConfigurations.showCodeOverlay)

            Picker("Output", selection: $renderConfigurations.codeOverlayOutput) {
                ForEach(CodeOverlayOutput.allCases) { Text($0.rawValue).tag($0) }
            }

            Picker("Evaluate", selection: $session.evaluationMode) {
                ForEach(LiveCodeEvaluationMode.allCases) { Text($0.rawValue).tag($0) }
            }
            if session.evaluationMode == .live {
                HStack {
                    Text("Debounce")
                    Slider(value: $session.liveDebounceSeconds, in: 0.1...2.0)
                    Text(String(format: "%.1fs", session.liveDebounceSeconds))
                }
            }

            Picker("Placement", selection: $session.style.placement) {
                ForEach(LiveCodeOverlayPlacement.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            HStack {
                Text("Size")
                Slider(value: $session.style.sizeFraction, in: 0.2...1.0)
            }
            HStack {
                Text("Font")
                Slider(value: $session.style.fontSize, in: 10...64, step: 1)
                Text("\(Int(session.style.fontSize))pt")
            }
            HStack {
                Text("Text opacity")
                Slider(value: $session.style.textOpacity, in: 0.05...1)
                Text("\(Int((session.style.textOpacity * 100).rounded()))%")
            }
            HStack {
                Text("Backdrop")
                Slider(value: $session.style.lineBackdropOpacity, in: 0...1)
            }
            Toggle("Show status bar in mirror", isOn: $session.style.showStatusInMirror)

            Divider()
            Text("Optional features").fontWeight(.bold)
            Toggle("⌘↩ also saves the file", isOn: $renderConfigurations.codeEvaluateAlsoSaves)
            Toggle("Show line numbers", isOn: $renderConfigurations.showCodeLineNumbers)
            Toggle("Show console output", isOn: $renderConfigurations.showCodeConsole)
            Toggle("Show input readout", isOn: $renderConfigurations.showCodeInputReadout)
            if renderConfigurations.showCodeInputReadout {
                TextField("inputState keys (comma separated, dotted paths allowed)",
                          text: $renderConfigurations.codeInputReadoutKeys)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
}
