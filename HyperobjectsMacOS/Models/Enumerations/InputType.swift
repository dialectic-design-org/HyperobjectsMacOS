//
//  InputType.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 06/11/2024.
//

enum InputType: String, CaseIterable, Identifiable {
    case string = "string"
    case float = "float"
    case integer = "integer"
    case vector2d = "vector2d"
    
    var id: String { self.rawValue }
}
