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
    var controlsCamera: Bool = false
    
    @Published var pythonCode: String
    
    private var cachedGeometries: [any Geometry]?
    
    init(name: String, inputDependencies: [String], pythonCode: String = "", controlsCamera: Bool = false) {
        self.name = name
        self.inputDependencies = inputDependencies
        self.pythonCode = pythonCode
        self.controlsCamera = controlsCamera
    }
    
    func generateGeometries(inputs: [String: Any], overrideCache: Bool = false, withScene: GeometriesSceneBase) -> [any Geometry] {
        if let cached = cachedGeometries {
            if overrideCache == false {
                return cached
            } else {
            }
        }
        cachedGeometries = generateGeometriesFromInputs(inputs: inputs, withScene: withScene)
        return cachedGeometries ?? []
    }
    
    func generateGeometriesFromInputs(inputs: [String: Any], withScene: GeometriesSceneBase) -> [any Geometry] {
        fatalError("generateGeometriesFromInputs must be implemented by subclasses")
    }
    
    func needsRecalculation(changedInputs: Set<String>) -> Bool {
        // Check if there are matching elements in changedInputs and in inputDependencies
        return !Set(changedInputs).intersection(Set(inputDependencies)).isEmpty
    }
    
    func controlCamera() -> (eye: SIMD3<Float>, target: SIMD3<Float>, up: SIMD3<Float>) {
        return (
            eye: SIMD3<Float>(0.0, 0.0, -3.0),
            target: SIMD3<Float>(0.0, 1.0, 0.0),
            up: SIMD3<Float>()
        )
    }
    
    func invalidateCache() {
        cachedGeometries = nil
    }
}
