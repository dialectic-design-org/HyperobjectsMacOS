//
//  ResolutionMode.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 02/01/2025.
//


enum ResolutionMode: String, CaseIterable, Identifiable {
    case fixed = "fixed"
    case dynamic = "dynamic"
    
    var id: String { self.rawValue }
}
