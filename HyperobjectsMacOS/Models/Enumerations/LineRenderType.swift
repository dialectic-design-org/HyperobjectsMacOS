//
//  LineRenderTypes.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 02/01/2025.
//

enum LineRenderType: String, CaseIterable, Identifiable {
    case primitive = "primitive"
    case primitiveStrip = "primitiveStrip"
    case tube = "tube"
    case sdf = "sdf"
    
    var id: String { self.rawValue }
}
