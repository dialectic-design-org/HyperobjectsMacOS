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
    
    func generateGeometries(inputs: [String: Any], overrideCache: Bool = false) -> [any Geometry] {
        if let cached = cachedGeometries {
            if overrideCache == false {
                return cached
            } else {
            }
        }
        cachedGeometries = generateGeometriesFromInputs(inputs: inputs)
        return cachedGeometries ?? []
    }
    
    func generateGeometriesFromInputs(inputs: [String: Any]) -> [any Geometry] {
        fatalError("generateGeometriesFromInputs must be implemented by subclasses")
    }
    
    func needsRecalculation(changedInputs: Set<String>) -> Bool {
        // Check if there are matching elements in changedInputs and in inputDependencies
        return !Set(changedInputs).intersection(Set(inputDependencies)).isEmpty
    }
    
    func invalidateCache() {
        cachedGeometries = nil
    }
}
