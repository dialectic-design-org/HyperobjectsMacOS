//
//  GeometryType.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 27/10/2024.
//

enum GeometryType: String, CaseIterable, Identifiable {
    case line = "line"
    case bezierCurve = "bezierCurve"
    
    var id: String { self.rawValue }
}
