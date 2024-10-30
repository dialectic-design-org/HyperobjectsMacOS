//
//  Windows.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 11/10/2024.
//

import SwiftUI

let renderWindowConfig = WindowInfo(
    id: "render_view",
    title: "Render View",
    showOnLoad: true,
    content: AnyView(RenderView())
)

let sceneInputsWindowConfig = WindowInfo(
    id: "scene_inputs",
    title: "Scene Inputs",
    showOnLoad: true,
    content: AnyView(SceneInputsView())
)

let sceneGeometriesListWindowConfig = WindowInfo(
    id: "scene_geometries_list",
    title: "Scene Geometries List",
    showOnLoad: true,
    content: AnyView(GeometriesListView())
)

let viewportFrontViewWindowConfig = WindowInfo(
    id: "viewport_front_view",
    title: "Viewport Front View",
    showOnLoad: true,
    content: AnyView(ViewportView(direction: "z"))
)

let sceneSelectorViewWindowConfig = WindowInfo(
    id: "scene_selector",
    title: "Scene Selector",
    showOnLoad: true,
    content: AnyView(SceneSelectorView())
)


let allWindows: [WindowInfo] = [
    renderWindowConfig,
    sceneInputsWindowConfig,
    sceneGeometriesListWindowConfig,
    viewportFrontViewWindowConfig,
    sceneSelectorViewWindowConfig
]
