//
//  Geometry.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 11/10/2024.
//

import Foundation

protocol Geometry: Identifiable {
    var id: UUID { get }
    var type: GeometryType { get }
    func getPoints() -> [SIMD3<Float>]
}
