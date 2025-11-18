//
//  SceneInputGroup.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 05/09/2025.
//

import SwiftUI

struct SceneInputGroup: Identifiable {
    var id: UUID
    var name: String
    var note: String?
    var background: Color
    var isVisible: Bool
    var isExpanded: Bool
    public init(id: UUID = UUID(),
                name: String,
                note: String? = nil,
                background: Color = .secondary,
                isVisible: Bool = true,
                isExpanded: Bool = false) {
        self.id = id
        self.name = name
        self.note = note
        self.background = background
        self.isVisible = isVisible
        self.isExpanded = isExpanded
    }
}
