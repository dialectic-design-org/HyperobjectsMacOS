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

let allWindows: [WindowInfo] = [
    renderWindowConfig,
    sceneInputsWindowConfig
]
