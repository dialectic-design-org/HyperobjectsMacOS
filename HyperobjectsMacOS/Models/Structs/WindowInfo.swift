//
//  WindowInfo.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 11/10/2024.
//

import SwiftUI

struct WindowInfo: Identifiable {
    let id: String
    let title: String
    let showOnLoad: Bool
    let content: AnyView
}
