//
//  GeometryWrapped.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 27/10/2024.
//

import Foundation

struct GeometryWrapped: Identifiable {
    let id = UUID()
    let geometry: any Geometry
}
