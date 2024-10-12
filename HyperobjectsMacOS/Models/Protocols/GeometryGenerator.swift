//
//  GeometryGenerator.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 11/10/2024.
//

import Foundation

protocol GeometryGenerator: Identifiable, ObservableObject {
    var id: UUID { get }
    var name: String { get }
    var inputDependencies: [String] { get }
    var pythonCode: String { get set }
    
    func generateGeometries(inputs: [String: Any]) -> [any Geometry]
    func needsRecalculation(changedInputs: Set<String>) -> Bool
}
