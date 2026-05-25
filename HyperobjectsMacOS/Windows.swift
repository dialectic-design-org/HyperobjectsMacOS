//
//  Windows.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 11/10/2024.
//

import SwiftUI

let windowsManagerWindowConfig = WindowInfo(
    id: "windows_manager",
    title: "Windows Manager",
    showOnLoad: true,
    content: AnyView(WindowsManagerView())
)

let secondaryRenderWindowConfig = WindowInfo(
    id: "secondary_render_view",
    title: "Secondary Render View",
    showOnLoad: false,
    content: AnyView(RenderView())
)

let sceneInputsWindowConfig = WindowInfo(
    id: "scene_inputs",
    title: "Scene Inputs",
    showOnLoad: false,
    content: AnyView(SceneInputsView())
)

let renderConfigurationsWindowConfig = WindowInfo(
    id: "render_configurations",
    title: "Render Configurations",
    showOnLoad: false,
    content: AnyView(RenderConfigurationsView())
)

let sceneGeometriesListWindowConfig = WindowInfo(
    id: "scene_geometries_list",
    title: "Scene Geometries List",
    showOnLoad: false,
    content: AnyView(GeometriesListView())
)

let viewportFrontViewWindowConfig = WindowInfo(
    id: "viewport_front_view",
    title: "Viewport Front View",
    showOnLoad: false,
    content: AnyView(ViewportView(direction: "z"))
)

let viewportSideViewWindowConfig = WindowInfo(
    id: "viewport_side_view",
    title: "Viewport Side View",
    showOnLoad: false,
    content: AnyView(ViewportView(direction: "x"))
)

let viewportTopViewWindowConfig = WindowInfo(
    id: "viewport_top_view",
    title: "Viewport Top View",
    showOnLoad: false,
    content: AnyView(ViewportView(direction: "y"))
)

let sceneSelectorViewWindowConfig = WindowInfo(
    id: "scene_selector",
    title: "Scene Selector",
    showOnLoad: false,
    content: AnyView(SceneSelectorView())
)

let midiLogWindowConfig = WindowInfo(
    id: "midi_log",
    title: "MIDI Log",
    showOnLoad: false,
    content: AnyView(MIDILogView())
)

let bandFieldPreviewWindowConfig = WindowInfo(
    id: "band_field_preview",
    title: "Band Field Preview",
    showOnLoad: false,
    content: AnyView(BandFieldPreviewView())
)


let allWindows: [WindowInfo] = [
    windowsManagerWindowConfig,
    secondaryRenderWindowConfig,
    sceneInputsWindowConfig,
    renderConfigurationsWindowConfig,
    sceneGeometriesListWindowConfig,
    viewportFrontViewWindowConfig,
    viewportSideViewWindowConfig,
    viewportTopViewWindowConfig,
    sceneSelectorViewWindowConfig,
    midiLogWindowConfig,
    bandFieldPreviewWindowConfig
]

struct BandFieldPreviewView: View {
    @EnvironmentObject var bandFieldManager: BandFieldManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Preview", selection: $bandFieldManager.previewMode) {
                ForEach(BandFieldPreviewMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Canvas { context, size in
                let cols = max(1, Int(size.width / 4))
                let rows = max(1, Int(size.height / 4))
                let cellW = size.width / CGFloat(cols)
                let cellH = size.height / CGFloat(rows)
                for y in 0..<rows {
                    for x in 0..<cols {
                        let color = bandFieldManager.samplePreviewColor(
                            x: (Double(x) + 0.5) / Double(cols),
                            y: (Double(y) + 0.5) / Double(rows),
                            mode: bandFieldManager.previewMode
                        )
                        let rect = CGRect(
                            x: CGFloat(x) * cellW,
                            y: CGFloat(y) * cellH,
                            width: cellW + 0.5,
                            height: cellH + 0.5
                        )
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
            .frame(minWidth: 420, minHeight: 260)
            .background(Color.black)

            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let warning = bandFieldManager.warningMessage {
                Text(warning)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding()
    }

    private var statusText: String {
        let state = bandFieldManager.state
        let bandCount = state.layers.reduce(0) { $0 + $1.bands.count }
        if !state.enabled {
            return "Band field disabled or no valid outputState.bands received."
        }
        return "Layers: \(state.layers.count), bands: \(bandCount), x: \(state.xAmplitudePx)px, y: \(state.yAmplitudePx)px"
    }
}
