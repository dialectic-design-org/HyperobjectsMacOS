//
//  GeometriesScene.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 11/10/2024.
//

import Foundation

protocol GeometriesScene: Identifiable, ObservableObject {
    var id: UUID { get }
    var name: String { get }
    var inputs: [SceneInput] { get set }
    var geometryGenerators: [any GeometryGenerator] { get set }
    var changedInputs: Set<String> { get set }
    var cachedGeometries: [GeometryWrapped] { get set }
    
    func updateInput(name: String, value: Any)
    func updatePythonCode(for generatorId: UUID, newCode: String)
    func generateAllGeometries() -> [any Geometry]
}
