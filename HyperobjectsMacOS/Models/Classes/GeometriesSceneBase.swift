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

struct AudioState {
    var signal: Float = 0
    var signalRaw: Float = 0
    var signalProcessed: Double = 0
    var signalsSmoothed: [Int: Float] = [:]
    var signalsSmoothedProcessed: [Int: Double] = [:]
    var lowpassRaw: Double = 0
    var lowpassSmoothed: Double = 0
    var lowpassProcessed: Double = 0
}

class GeometriesSceneBase: ObservableObject, GeometriesScene {
    let id = UUID()
    let name: String
    @Published var inputs: [SceneInput]
    @Published var inputGroups: [SceneInputGroup] = []
    @Published var geometryGenerators: [any GeometryGenerator]
    var changedInputs: Set<String> = []
    var cachedGeometries: [GeometryWrapped] = []
    @Published var audioState = AudioState()

    var audioSignal: Float { audioState.signal }
    var audioSignalsSmoothed: [Int: Float] { audioState.signalsSmoothed }
    var audioSignalRaw: Float { audioState.signalRaw }
    var audioSignalProcessed: Double { audioState.signalProcessed }
    var audioSignalsSmoothedProcessed: [Int: Double] { audioState.signalsSmoothedProcessed }
    var audioSignalLowpassRaw: Double { audioState.lowpassRaw }
    var audioSignalLowpassSmoothed: Double { audioState.lowpassSmoothed }
    var audioSignalLowpassProcessed: Double { audioState.lowpassProcessed }
    var frameStamp: Int = 0
    
    @Published var sceneHasBackgroundColor: Bool = false
    @Published var backgroundColor: SIMD3<Float> = SIMD3<Float>(0.0, 0.0, 0.0)

    /// Closure type for geometry-time overrides
    typealias GeometryTimeOverrideClosure = (RenderOverrideContext) -> RenderConfigurationOverrides

    /// Closure type for render-time overrides
    typealias RenderTimeOverrideClosure = (RenderOverrideContext) -> RenderConfigurationOverrides

    var geometryTimeOverride: GeometryTimeOverrideClosure?
    var renderTimeOverride: RenderTimeOverrideClosure?

    var cachedRenderOverrides: RenderConfigurationOverrides = .none

    let renderBuffer = DoubleBuffer<RenderSnapshot>(RenderSnapshot())

    private let _geometryGenerationRequested = Atomic<Bool>(value: false)

    /// Called from the render thread. Dispatches geometry generation to main thread
    /// if no generation is already pending. Uses fire-and-forget with backpressure.
    func requestGeometryGeneration() {
        guard !_geometryGenerationRequested.get() else { return }
        _geometryGenerationRequested.set(true)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.setWrappedGeometries()
            self._geometryGenerationRequested.set(false)
        }
    }

    private let _historyData = Atomic<[AudioDataPoint]>(value: [])
    var historyData: [AudioDataPoint] {
        get { _historyData.get() }
        set { _historyData.set(newValue) }
    }
    
    private let maxAudioHistoryDuration: TimeInterval = 30.0
    
    private var _inputMap: [String: SceneInput]?
    
    private var inputMap: [String: SceneInput] {
        if let map = _inputMap { return map }
        let map = Dictionary(uniqueKeysWithValues:  inputs.map { ($0.name, $0) })
        _inputMap = map
        return map
    }
    
    func invalidateInputCache() {
        _inputMap = nil
    }
    
    
    
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
    
    func updateFloatInputsWithAudio(smoothedVolumes: [Int: Float]) {
        var changedInputNames: [String] = []


        for (_, input) in inputs.enumerated() where input.type == .float {
            changedInputNames.append(input.name)
        }

        for (_, input) in inputs.enumerated() where input.type == .lines {
            changedInputNames.append(input.name)
        }

        // Batch notify all changes at once
        if !changedInputNames.isEmpty {
            setChangedInputs(names: changedInputNames)
        }


        let currentTime = Date().timeIntervalSince1970

        var smoothedVolumesAsDouble: [Int: Double] = [:]
        for (_, input) in smoothedVolumes.enumerated() {
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

        // Single get + local mutation + single set (avoids multiple Atomic accesses)
        var history = _historyData.get()
        history.append(dataPoint)

        let cutoffTime = currentTime - self.maxAudioHistoryDuration

        // OPTIMIZATION: Efficiently remove old history
        // Since the array is sorted by time, we only need to check from the start.
        var removeCount = 0
        for item in history {
            if item.timestamp < cutoffTime {
                removeCount += 1
            } else {
                break
            }
        }

        if removeCount > 0 {
            history.removeFirst(removeCount)
        }

        // Safety cap to prevent unbounded growth if timestamps drift
        if history.count > 4000 {
             let excess = history.count - 3600
             history.removeFirst(excess)
             print("⚠️ Audio History exceeded safety limit. Pruned \(excess) items.")
        }

        _historyData.set(history)
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
        guard let input = inputMap[name] else {
            fatalError("SceneInput named \(name) not found")
        }
        return input
//        guard let input = inputs.first(where: { $0.name == name }) else {
//            fatalError("SceneInput named \(name) not found in inputs.")
//        }
//        return input
    }
    
    func val_f(name: String, delay: Double = 0) -> Float {
        let input = self.getInputWithName(name: name)
        if input.type == .float {
            return ensureValueIsFloat(input.getHistoryValue(millisecondsAgo: delay))
        }
        return 0.0
    }

    func makeOverrideContext() -> RenderOverrideContext {
        let inputDict: [String: Any] = Dictionary(uniqueKeysWithValues: inputs.map { ($0.name, $0.value) })
        return RenderOverrideContext(
            frameStamp: frameStamp,
            audioSignal: audioSignal,
            audioSignalProcessed: audioSignalProcessed,
            inputs: inputDict
        )
    }

    func setWrappedGeometries() {
        self.cachedGeometries = self.generateAllGeometries().map { GeometryWrapped(geometry: $0) }

        // Compute and cache geometry-time overrides
        if let overrideClosure = geometryTimeOverride {
            cachedRenderOverrides = overrideClosure(makeOverrideContext())
        } else {
            cachedRenderOverrides = .none
        }

        // Publish consistent snapshot for the render thread
        renderBuffer.publish(RenderSnapshot(
            geometries: cachedGeometries,
            renderOverrides: cachedRenderOverrides
        ))
    }
    
    func resetAllInputsToInitialValues() {
        for i in 0..<inputs.count {
            inputs[i].resetToInitialValues()
        }
    }

}


extension GeometriesSceneBase {
    @MainActor func applyAudioTick(_ m: AudioSnapshot, using processor: EnvelopeProcessor) {
        // Compute all audio values locally first
        let processedSignal = processor.process(Double(m.smoothed))
        let lowpassProcessed = processor.process(Double(m.lowpassSmoothed))
        var smoothedProcessed: [Int: Double] = [:]
        for (_, val) in m.smoothedPerStep.enumerated() {
            smoothedProcessed[val.key] = processor.process(Double(val.value))
        }

        // Single @Published assignment → 1 objectWillChange notification
        audioState = AudioState(
            signal: m.smoothed,
            signalRaw: m.raw,
            signalProcessed: processedSignal,
            signalsSmoothed: m.smoothedPerStep,
            signalsSmoothedProcessed: smoothedProcessed,
            lowpassRaw: Double(m.lowpassRaw),
            lowpassSmoothed: Double(m.lowpassSmoothed),
            lowpassProcessed: lowpassProcessed
        )

        // Update statefulFloat inputs with audio-driven accumulation
        for i in 0..<inputs.count {
            if inputs[i].type == .statefulFloat {
                let historicalAudioSignal = extractHistoricAudioValue(for: inputs[i])
                if let floatValue = inputs[i].value as? Double {
                    inputs[i].value = floatValue +
                        inputs[i].tickValueAdjustment +
                        inputs[i].tickValueAudioAdjustment *
                        (historicalAudioSignal + inputs[i].tickValueAudioAdjustmentOffset)
                }
            }
        }

        // Mark changed inputs + record audio history
        updateFloatInputsWithAudio(smoothedVolumes: m.smoothedPerStep)

        frameStamp &+= 1
    }
}
