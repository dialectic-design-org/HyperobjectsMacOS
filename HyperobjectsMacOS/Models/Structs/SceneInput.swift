//
//  SceneInput.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 11/10/2024.
//

import Foundation

struct SceneInput: Identifiable {
    var id: UUID = UUID()
    var name: String
    var type: InputType
    var value: Any
}
