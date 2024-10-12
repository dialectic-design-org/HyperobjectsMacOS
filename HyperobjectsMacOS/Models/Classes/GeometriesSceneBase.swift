//
//  GeometriesSceneBase.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 11/10/2024.
//

import Foundation

class GeometriesSceneBase: GeometriesScene {
    let id = UUID()
    let name: String
    @Published var inputs: [SceneInput]
    @Published var geometryGenerators: [any GeometryGenerator]
    @Published var changedInputs: Set<String> = []
    
    init(name: String, inputs: [SceneInput], geometryGenerators: [any GeometryGenerator]) {
        self.name = name
        self.inputs = inputs
        self.geometryGenerators = geometryGenerators
    }
    
    func updateInput(name: String, value: Any) {
        if let index = inputs.firstIndex(where: { $0.name == name }) {
            inputs[index].value = value
            changedInputs.insert(name)
        }
    }
    
    func updatePythonCode(for generatorId: UUID, newCode: String) {
        if let index = geometryGenerators.firstIndex(where: { $0.id == generatorId }) {
            geometryGenerators[index].pythonCode = newCode
            if let cachedGenerator = geometryGenerators[index] as? CachedGeometryGenerator {
                cachedGenerator.invalidateCache()
            }
        }
    }
    
    func generateAllGeometries() -> [any Geometry] {
        let inputDict = Dictionary(uniqueKeysWithValues: inputs.map { ($0.name, $0.value) })
        return geometryGenerators.flatMap { generator in
            if generator.needsRecalculation(changedInputs: changedInputs) {
                return generator.generateGeometries(inputs: inputDict)
            } else if let cachedGenerator = generator as? CachedGeometryGenerator {
                return cachedGenerator.generateGeometries(inputs: inputDict)
            }
            return []
        }
    }
}
