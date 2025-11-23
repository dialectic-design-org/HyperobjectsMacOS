//
//  GeometriesSceneBase.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 11/10/2024.
//

import Foundation
import os

let geometryGenerationLog = OSLog(subsystem: "com.yourapp.geometry", category: .pointsOfInterest)

struct AudioSnapshot {
    let raw: Float
    let smoothed: Float
    let smoothedPerStep: [Int:Float]
    let lowpassRaw: Float
    let lowpassSmoothed: Float
}

class GeometriesSceneBase: ObservableObject, GeometriesScene {
    let id = UUID()
    let name: String
    @Published var inputs: [SceneInput]
    @Published var inputGroups: [SceneInputGroup] = []
    @Published var geometryGenerators: [any GeometryGenerator]
    @Published var changedInputs: Set<String> = []
    @Published var cachedGeometries: [GeometryWrapped] = []
    @Published var audioSignal: Float = 0.0
    @Published var audioSignalsSmoothed: [Int:Float] = [:]
    @Published var audioSignalRaw: Float = 0.0
    @Published var audioSignalProcessed: Double = 0.0
    @Published var audioSignalsSmoothedProcessed: [Int:Double] = [:]
    @Published var audioSignalProcessedHistory: [Double] = []
    
    @Published var audioSignalLowpassRaw: Double = 0.0
    @Published var audioSignalLowpassSmoothed: Double = 0.0
    @Published var audioSignalLowpassProcessed: Double = 0.0
    @Published var frameStamp: Int = 0
    
    
    @Published var historyData: [AudioDataPoint] = []
    
    private let maxAudioHistoryDuration: TimeInterval = 30.0
    
    init(name: String, inputs: [SceneInput], inputGroups: [SceneInputGroup] = [], geometryGenerators: [any GeometryGenerator]) {
        self.name = name
        self.inputs = inputs
        
        // Check if there are any inputs with an inputGroupName not in inputGroups, then add an input group for that.
        var allInputGroupNames: Set<String> = []
        var missingInputGroups: [SceneInputGroup] = []
        for input in inputs {
            allInputGroupNames.insert(input.inputGroupName ?? "")
        }
        for inputGroup in inputGroups {
            allInputGroupNames.remove(inputGroup.name)
        }
        for groupName in allInputGroupNames {
            missingInputGroups.append(SceneInputGroup(name: groupName))
        }
        self.inputGroups = inputGroups + missingInputGroups
        self.geometryGenerators = geometryGenerators
        if self.geometryGenerators.count == 0 {
            print("No geometries defined for scene \(name)")
        }
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
    
    func extractHistoricAudioValue(for input: SceneInput) -> Double {
        // Clamp historyData to latest 120 samples
        let clampedHistory = Array(historyData.suffix(120))
        
        let historyLength = clampedHistory.count
        guard historyLength > 0 else {
            // Fallback to current signal if no history available
            return audioSignalProcessed
        }
        
        let maxHistoryIndex = historyLength - 1
        
        // Map audioDelay (0-1) to history array index (0 to current length - 1)
        // audioDelay of 0 = most recent (last element), audioDelay of 1 = oldest available
        let delayIndex = Int(input.audioDelay * Float(maxHistoryIndex))
        let clampedIndex = min(max(0, delayIndex), maxHistoryIndex)
        
        // Get the historical audio signal value (index from end of array)
        let arrayIndex = max(0, historyLength - 1 - clampedIndex)
        if input.audioSmoothedSource == -1 {
            return clampedHistory[arrayIndex].processedVolume
        } else {
            if let val = clampedHistory[arrayIndex].smoothedProcessedVolumes[input.audioSmoothedSource] {
                return val
            }
        }
        return Double(0.0)
    }
    
    func generateAllGeometries() -> [any Geometry] {
        let startTime = DispatchTime.now()
        os_signpost(.begin, log: geometryGenerationLog, name: "generateAllGeometries")

        let inputDict: [String: Any] = Dictionary(uniqueKeysWithValues: inputs.map { input in
            // Extract historic audio value based on input.audioDelay from historyData
            
            if input.type == .float {
                // Get historic audio value from historyData based on audioDelay
                let historicAudioSignal = extractHistoricAudioValue(for: input)
                let combinedValueAsFloat = input.combinedValueAsFloat(audioSignal: Float(historicAudioSignal))
                input.addValueChange(value: combinedValueAsFloat)
                return (input.name, combinedValueAsFloat)
            } else if input.type == .colorInput {
                return (input.name, input.value)
            } else if input.type == .lines {
                return (input.name, input.value)
            } else {
                return (input.name, input.value)
            }
        })

        let geometries = geometryGenerators.flatMap { generator in
            if generator.needsRecalculation(changedInputs: changedInputs) {
                return generator.generateGeometries(inputs: inputDict, overrideCache: true, withScene: self)
            } else if let cachedGenerator = generator as? CachedGeometryGenerator {
                return cachedGenerator.generateGeometries(inputs: inputDict, overrideCache: false, withScene: self)
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
    
    func updateFloatInputsWithAudio(_ audioValue: Float, audioMonitor: AudioInputMonitor) {
        var changedInputNames: [String] = []

        
        for (index, input) in inputs.enumerated() where input.type == .float {
            // Only update if the value actually changed significantly
            // if abs(input.valueAsFloat() - audioValue) > 0.001 {
            if true {
                changedInputNames.append(input.name)
            }
        }
        
        for (index, input) in inputs.enumerated() where input.type == .lines {
            // Only update if the value actually changed significantly
            // if abs(input.valueAsFloat() - audioValue) > 0.001 {
            if true {
                changedInputNames.append(input.name)
            }
        }
        
        // Batch notify all changes at once
        if !changedInputNames.isEmpty {
            setChangedInputs(names: changedInputNames) // New batched method
        }
        
        
        let currentTime = Date().timeIntervalSince1970
        
        var smoothedVolumesAsDouble: [Int: Double] = [:]
        for (index, input) in audioMonitor.smoothedVolumes.enumerated() {
            smoothedVolumesAsDouble[input.key] = Double(input.value)
        }
        
        let dataPoint = AudioDataPoint(
            timestamp: currentTime,
            rawVolume: Double(self.audioSignalRaw),
            smoothedVolume: Double(self.audioSignal),
            smoothedVolumes: smoothedVolumesAsDouble,
            processedVolume: Double(self.audioSignalProcessed),
            smoothedProcessedVolumes: self.audioSignalsSmoothedProcessed
        )
        self.historyData.append(dataPoint)
        
        let cutoffTime = currentTime - self.maxAudioHistoryDuration
        self.historyData.removeAll { $0.timestamp < cutoffTime }
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
    
    func getInputWithName(name: String) -> SceneInput {
        guard let input = inputs.first(where: { $0.name == name }) else {
            fatalError("SceneInput named \(name) not found in inputs.")
        }
        return input
    }
    
    
    func setWrappedGeometries() {
        self.cachedGeometries = self.generateAllGeometries().map { GeometryWrapped(geometry: $0) }
    }
    
}


extension GeometriesSceneBase {
    @MainActor func applyAudioTick(_ m: AudioSnapshot, using processor: EnvelopeProcessor) {
        audioSignal = m.smoothed
        audioSignalsSmoothed = m.smoothedPerStep
        audioSignalRaw = m.raw
        audioSignalProcessed = processor.process(Double(m.smoothed))
        audioSignalLowpassRaw = Double(m.lowpassRaw)
        audioSignalLowpassSmoothed = Double(m.lowpassSmoothed)
        audioSignalLowpassProcessed = processor.process(Double(m.lowpassSmoothed))
        for (_, val) in audioSignalsSmoothed.enumerated() {
            audioSignalsSmoothedProcessed[val.key] = processor.process(Double(val.value))
        }
        
        
        frameStamp &+= 1
    }
}
