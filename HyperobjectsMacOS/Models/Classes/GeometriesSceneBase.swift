//
//  GeometriesSceneBase.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 11/10/2024.
//

import Foundation
import os

let geometryGenerationLog = OSLog(subsystem: "com.yourapp.geometry", category: .pointsOfInterest)


class GeometriesSceneBase: ObservableObject, GeometriesScene {
    let id = UUID()
    let name: String
    @Published var inputs: [SceneInput]
    @Published var geometryGenerators: [any GeometryGenerator]
    @Published var changedInputs: Set<String> = []
    @Published var cachedGeometries: [GeometryWrapped] = []
    @Published var audioSignal: Float = 0.0
    
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
        let startTime = DispatchTime.now()
        os_signpost(.begin, log: geometryGenerationLog, name: "generateAllGeometries")

        let inputDict: [String: Any] = Dictionary(uniqueKeysWithValues: inputs.map { input in
            if input.type == .float {
                return (input.name, input.combinedValueAsFloat(audioSignal: audioSignal))
            } else {
                return (input.name, input.value)
            }
        })

        let geometries = geometryGenerators.flatMap { generator in
            if generator.needsRecalculation(changedInputs: changedInputs) {
                return generator.generateGeometries(inputs: inputDict, overrideCache: true)
            } else if let cachedGenerator = generator as? CachedGeometryGenerator {
                return cachedGenerator.generateGeometries(inputs: inputDict, overrideCache: false)
            }
            return []
        }

        os_signpost(.end, log: geometryGenerationLog, name: "generateAllGeometries")
        let endTime = DispatchTime.now()

        let durationNano = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
        let durationMillis = Double(durationNano) / 1_000_000
        // print("Geometry generation took \(durationMillis) ms")

        return geometries
    }
    
    func updateFloatInputsWithAudio(_ audioValue: Float) {
        var changedInputNames: [String] = []
        
        for (index, input) in inputs.enumerated() where input.type == .float {
            // Only update if the value actually changed significantly
            if abs(input.valueAsFloat() - audioValue) > 0.001 {
                changedInputNames.append(input.name)
            }
        }
        
        // Batch notify all changes at once
        if !changedInputNames.isEmpty {
            setChangedInputs(names: changedInputNames) // New batched method
        }
    }
    
    func setChangedInputs(names: [String]) {
        changedInputs.formUnion(names)
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
