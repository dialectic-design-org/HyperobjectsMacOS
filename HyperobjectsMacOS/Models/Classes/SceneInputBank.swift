//
//  SceneInputBank.swift
//  HyperobjectsMacOS
//
//  A private set of SceneInputs, used as the state of one scripted object (e.g. a `Cube`
//  created in a live-coding script).
//

import Foundation

/// Anything a generator can ask for a `SceneInput` by name, for history-aware lookups.
protocol SceneInputProviding: AnyObject {
    func getInputWithName(name: String) -> SceneInput
}

extension GeometriesSceneBase: SceneInputProviding {}

/// A set of SceneInputs with their own value history. The list of inputs never changes after
/// creation; the inputs themselves are written on the main thread and read (through their
/// lock-guarded history) on the geometry queue.
final class SceneInputBank: SceneInputProviding {
    /// Long enough for every delay slider of the Cube scene (the rotation delays go up to
    /// 2π seconds) and much shorter than a scene input's 30 s, because every scripted object
    /// carries its own copy of all inputs.
    static let historyWindow: CFTimeInterval = 10.0

    let inputs: [SceneInput]
    let inputsByName: [String: SceneInput]
    /// Precomputed for the audio tick, which advances stateful floats.
    let statefulInputs: [SceneInput]

    init(inputs: [SceneInput]) {
        self.inputs = inputs
        self.inputsByName = Dictionary(inputs.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        self.statefulInputs = inputs.filter { $0.type == .statefulFloat }
        for input in inputs {
            input.setHistoryWindow(Self.historyWindow)
        }
    }

    func getInputWithName(name: String) -> SceneInput {
        guard let input = inputsByName[name] else {
            fatalError("SceneInput named \(name) not found in bank")
        }
        return input
    }
}
