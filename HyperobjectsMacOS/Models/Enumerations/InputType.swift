//
//  InputType.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 06/11/2024.
//

enum InputType: String, CaseIterable, Identifiable {
    case keyboard = "keyboard"
    case float = "float"
    case integer = "integer"
    case xy = "xy"
    
    var id: String { self.rawValue }
}
