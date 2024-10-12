//
//  CachedGeometryGenerator.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 11/10/2024.
//

import Foundation

class CachedGeometryGenerator: GeometryGenerator {
    var id = UUID()
    var name: String
    var inputDependencies: [String]
    
    @Published var pythonCode: String
    
    private var cachedGeometries: [any Geometry]?
    
    init(name: String, inputDependencies: [String], pythonCode: String = "") {
        self.name = name
        self.inputDependencies = inputDependencies
        self.pythonCode = pythonCode
    }
    
    func generateGeometries(inputs: [String: Any]) -> [any Geometry] {
        if let cached = cachedGeometries {
            return cached
        }
        cachedGeometries = generateGeometriesFromInputs(inputs: inputs)
        return cachedGeometries ?? []
    }
    
    func generateGeometriesFromInputs(inputs: [String: Any]) -> [any Geometry] {
        fatalError("generateGeometriesFromInputs must be implemented by subclasses")
    }
    
    func needsRecalculation(changedInputs: Set<String>) -> Bool {
        !Set(inputDependencies).isDisjoint(with: changedInputs)
    }
    
    func invalidateCache() {
        cachedGeometries = nil
    }
}
