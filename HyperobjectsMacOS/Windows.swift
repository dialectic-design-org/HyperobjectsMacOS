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


let allWindows: [WindowInfo] = [
    windowsManagerWindowConfig,
    secondaryRenderWindowConfig,
    sceneInputsWindowConfig,
    renderConfigurationsWindowConfig,
    sceneGeometriesListWindowConfig,
    viewportFrontViewWindowConfig,
    viewportSideViewWindowConfig,
    viewportTopViewWindowConfig,
    sceneSelectorViewWindowConfig
]
