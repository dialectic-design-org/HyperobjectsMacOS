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
    @Published var cachedGeometries: [GeometryWrapped] = []
    
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
        let inputDict: [String: Any] = Dictionary(uniqueKeysWithValues: inputs.map { input in
            if input.type == .float, let floatValue = input.value as? Float {
                return (input.name, floatValue + input.audioSignal * input.audioAmplification as Any)
            } else {
                return (input.name, input.value)
            }
        })
        
        return geometryGenerators.flatMap { generator in
            if generator.needsRecalculation(changedInputs: changedInputs) {
                return generator.generateGeometries(inputs: inputDict, overrideCache: true)
            } else if let cachedGenerator = generator as? CachedGeometryGenerator {
                return cachedGenerator.generateGeometries(inputs: inputDict, overrideCache: false)
            }
            return []
        }
    }
    
    func setChangedInput(name: String) {
        // Add changed input to changedInputs if not in array already
        if !changedInputs.contains(name) {
            changedInputs.insert(name)
        }
    }
    
    
    func setWrappedGeometries() {
        self.cachedGeometries = self.generateAllGeometries().map { GeometryWrapped(geometry: $0) }
    }
    
}
