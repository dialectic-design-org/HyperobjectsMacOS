//
//  Windows.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 11/10/2024.
//

import SwiftUI

let renderViewConfig = WindowInfo(
    id: "render_view",
    title: "Render View",
    showOnLoad: true,
    content: AnyView(Text("Render view placeholder"))
)

let allWindows: [WindowInfo] = [
    renderViewConfig
]
