//
//  GeometriesSceneBase.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 11/10/2024.
//

import Foundation
import os
import SwiftUI

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
    @Published var audioState = AudioState()

    let sigmoidEnvelope = SigmoidEnvelope()
    let freeformEnvelope = FreeformEnvelope()
    @Published var selectedEnvelopeType: EnvelopeType = .sigmoid

    var currentProcessor: EnvelopeProcessor {
        selectedEnvelopeType == .sigmoid ? sigmoidEnvelope : freeformEnvelope
    }

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
    
    private let geometryQueue = DispatchQueue(label: "io.hyperobjects.geometry", qos: .userInteractive)
    private let sceneInputSnapshot = Atomic<SceneInputSnapshot>(value: SceneInputSnapshot())

    private let _geometryGenerationRequested = Atomic<Bool>(value: false)
    private var geometryClockTimer: DispatchSourceTimer?
    private var geometryTriggerMode: GeometryTriggerMode = .onRenderRequest

    func requestGeometryGeneration() {
        // In fixedClock mode the timer drives generation; ignore render-thread hints.
        // In onInputChange mode, refreshSceneInputSnapshot kicks the queue directly.
        if case .fixedClock = geometryTriggerMode { return }
        if case .onInputChange = geometryTriggerMode { return }

        guard !_geometryGenerationRequested.get() else { return }
        _geometryGenerationRequested.set(true)
        geometryQueue.async { [weak self] in
            guard let self else { return }
            self.setWrappedGeometries()
            self._geometryGenerationRequested.set(false)
        }
    }

    func setGeometryTriggerMode(_ mode: GeometryTriggerMode) {
        geometryClockTimer?.cancel()
        geometryClockTimer = nil
        geometryTriggerMode = mode

        switch mode {
        case .onRenderRequest, .onInputChange:
            break
        case .fixedClock(let hz):
            let timer = DispatchSource.makeTimerSource(queue: geometryQueue)
            timer.schedule(deadline: .now(), repeating: 1.0 / hz)
            timer.setEventHandler { [weak self] in
                self?.setWrappedGeometries()
            }
            timer.resume()
            geometryClockTimer = timer
        }
    }

    deinit {
        geometryClockTimer?.cancel()
    }

    let audioHistory = AudioHistory(capacity: 3600)
    func historyData(since cutoff: Double) -> [AudioDataPoint] {
        audioHistory.snapshot(since: cutoff)
    }
    
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
        refreshSceneInputSnapshot()
    }

    func updatePythonCode(for generatorId: UUID, newCode: String) {
        if let index = geometryGenerators.firstIndex(where: { $0.id == generatorId }) {
            geometryGenerators[index].pythonCode = newCode
            if let cachedGenerator = geometryGenerators[index] as? CachedGeometryGenerator {
                cachedGenerator.invalidateCache()
            }
        }
        refreshSceneInputSnapshot()
    }

    func generateAllGeometries(from snap: SceneInputSnapshot) -> (geometries: [any Geometry], records: [(String, Float)]) {
        os_signpost(.begin, log: geometryGenerationLog, name: "generateAllGeometries")
        defer { os_signpost(.end, log: geometryGenerationLog, name: "generateAllGeometries") }

        // Snapshot the live input map once on this queue so we can write back the
        // per-input combinedValueAsFloat eagerly. SceneInput.history is guarded by
        // its own NSLock so cross-queue mutation is safe. Eager recording matches
        // the original main-thread pipeline: generators that read
        // getHistoryValue(millisecondsAgo: 0) see a Float (not the init-time Double),
        // which keeps `as! Float` force-casts in user code working.
        let liveInputs = inputMap

        let inputDict: [String: Any] = Dictionary(uniqueKeysWithValues: snap.entries.map { view -> (String, Any) in
            switch view.type {
            case .float:
                let historicAudio = Self.extractHistoricAudioValue(for: view, in: snap)
                let combined = Self.combinedValueAsFloat(view, audioSignal: Float(historicAudio))
                liveInputs[view.name]?.addValueChange(value: combined)
                return (view.name, combined)
            default:
                return (view.name, view.value.asAny())
            }
        })

        let geometries = snap.generators.flatMap { generator -> [any Geometry] in
            if generator.needsRecalculation(changedInputs: snap.changedInputs) {
                return generator.generateGeometries(inputs: inputDict, overrideCache: true, withScene: self)
            } else if let cached = generator as? CachedGeometryGenerator {
                return cached.generateGeometries(inputs: inputDict, overrideCache: false, withScene: self)
            }
            return []
        }

        // Records are now empty — kept in the return tuple for source compatibility
        // with the GeometriesScene protocol; the eager replay above superseded them.
        return (geometries, [])
    }

    private static func combinedValueAsFloat(_ v: SceneInputView, audioSignal: Float) -> Float {
        let base: Float
        if case .float(let d) = v.value { base = Float(d) } else { base = 0 }
        return base
            * (v.audioAmplificationMultiplicationOffset + v.audioAmplificationMultiplication * audioSignal)
            + v.audioAmplificationAddition * audioSignal
    }

    private static func extractHistoricAudioValue(for v: SceneInputView, in snap: SceneInputSnapshot) -> Double {
        let history = snap.audioHistorySuffix120
        let historyLength = history.count
        guard historyLength > 0 else {
            return snap.audioSignalProcessed
        }

        let maxHistoryIndex = historyLength - 1

        // audioDelay of 0 = most recent, 1 = oldest available
        let delayIndex = Int(v.audioDelay * Float(maxHistoryIndex))
        let clampedIndex = min(max(0, delayIndex), maxHistoryIndex)

        let arrayIndex = max(0, historyLength - 1 - clampedIndex)
        if v.audioSmoothedSource == -1 {
            return history[arrayIndex].processedVolume
        } else if let val = history[arrayIndex].smoothedProcessedVolumes[v.audioSmoothedSource] {
            return val
        }
        return 0.0
    }

    /// Thread-safe context builder for the render-thread renderTimeOverride path.
    /// Reads the atomic input snapshot, so callers don't need to be on main.
    func makeOverrideContext() -> RenderOverrideContext {
        return Self.makeOverrideContext(from: sceneInputSnapshot.get())
    }

    private static func makeOverrideContext(from snap: SceneInputSnapshot) -> RenderOverrideContext {
        let inputDict: [String: Any] = Dictionary(uniqueKeysWithValues: snap.entries.map {
            ($0.name, $0.value.asAny())
        })
        return RenderOverrideContext(
            frameStamp: snap.frameStamp,
            audioSignal: snap.audioSignal,
            audioSignalProcessed: snap.audioSignalProcessed,
            inputs: inputDict
        )
    }
    
    func updateFloatInputsWithAudio(smoothedVolumes: [Int: Float]) {
        let changedInputNames = inputs.compactMap { input -> String? in
            guard input.type == .float || input.type == .lines else { return nil }
            guard input.audioAmplificationMultiplication != 0 || input.audioAmplificationAddition != 0 else { return nil }
            return input.name
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

        // Ring buffer handles capacity — no pruning needed
        audioHistory.append(dataPoint)
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

    /// Runs on `geometryQueue`. Reads only `snap` and lock-protected scene state
    /// (`audioHistory`, `renderBuffer`). Main-thread side effects are dispatched async.
    func setWrappedGeometries() {
        let snap = sceneInputSnapshot.get()
        let (geometries, records) = generateAllGeometries(from: snap)
        let wrapped = geometries.map { GeometryWrapped(geometry: $0) }

        let overrides: RenderConfigurationOverrides
        if let overrideClosure = geometryTimeOverride {
            overrides = overrideClosure(Self.makeOverrideContext(from: snap))
        } else {
            overrides = .none
        }

        renderBuffer.publish(RenderSnapshot(
            geometries: wrapped,
            renderOverrides: overrides
        ))

        // History recording now happens eagerly inside generateAllGeometries (under
        // SceneInput.historyLock). No deferred main-thread replay is needed.
        _ = records
    }

    func resetAllInputsToInitialValues(refresh: Bool = true) {
        for i in 0..<inputs.count {
            inputs[i].resetToInitialValues()
        }
        if refresh {
            refreshSceneInputSnapshot()
        }
    }

    /// Main-thread only. Captures the current `inputs`, `changedInputs`, audio history,
    /// and override-context state into an atomic snapshot for the geometry queue to read.
    func refreshSceneInputSnapshot() {
        let views = inputs.map { input in
            SceneInputView(
                id: input.id,
                name: input.name,
                type: input.type,
                value: Self.captureValue(input.value, type: input.type),
                audioDelay: input.audioDelay,
                audioSmoothedSource: input.audioSmoothedSource,
                audioAmplificationMultiplication: input.audioAmplificationMultiplication,
                audioAmplificationAddition: input.audioAmplificationAddition,
                audioAmplificationMultiplicationOffset: input.audioAmplificationMultiplicationOffset
            )
        }
        sceneInputSnapshot.set(SceneInputSnapshot(
            entries: views,
            changedInputs: changedInputs,
            generators: geometryGenerators,
            audioHistorySuffix120: audioHistory.suffix(120),
            audioSignalProcessed: audioSignalProcessed,
            audioSignal: audioSignal,
            frameStamp: frameStamp,
            pendingValueHistoryRecords: []
        ))
        changedInputs.removeAll(keepingCapacity: true)

        // In onInputChange mode there is no render-thread driver — every input change
        // should produce one generation pass. Coalesce via the backpressure flag so
        // a slider drag doesn't queue dozens of pending generations.
        if case .onInputChange = geometryTriggerMode {
            guard !_geometryGenerationRequested.get() else { return }
            _geometryGenerationRequested.set(true)
            geometryQueue.async { [weak self] in
                guard let self else { return }
                self.setWrappedGeometries()
                self._geometryGenerationRequested.set(false)
            }
        }
    }
    
    private static func captureValue(_ any: Any, type: InputType) -> SceneInputValue {
        // For .integer-typed inputs we must preserve Int identity — `intFromInputs`
        // does `as? Int` and would fail against a Double.
        // For .float / .statefulFloat we collapse Int/Float/Double to .float(Double).
        if type == .integer {
            if let v = any as? Int    { return .integer(v) }
            if let v = any as? Double { return .integer(Int(v)) }
            if let v = any as? Float  { return .integer(Int(v)) }
        }
        switch any {
        case let v as Float:  return .float(Double(v))
        case let v as Double: return .float(v)
        case let v as Int:    return .float(Double(v))
        case let v as Bool:   return .bool(v)
        case let v as String: return .string(v)
        case let v as Color:  return .color(v)
        case let v as [Line]: return .lines(v)
        default:              return .unsupported
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

        // Update statefulFloat inputs with audio-driven accumulation.
        // We read audio history directly here — this runs on main, so we can.
        let historySuffix = audioHistory.suffix(120)
        for i in 0..<inputs.count {
            if inputs[i].type == .statefulFloat {
                let historicalAudioSignal = Self.historicAudioValue(
                    audioDelay: inputs[i].audioDelay,
                    audioSmoothedSource: inputs[i].audioSmoothedSource,
                    history: historySuffix,
                    fallback: audioSignalProcessed
                )
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

        // Rebuild the snapshot so the geometry queue sees fresh inputs/audio state.
        refreshSceneInputSnapshot()
    }

    /// Shared lookup logic between the static (snapshot-based) and instance (live)
    /// callers of historic audio lookup. Called on main thread by applyAudioTick.
    static func historicAudioValue(audioDelay: Float, audioSmoothedSource: Int, history: [AudioDataPoint], fallback: Double) -> Double {
        let historyLength = history.count
        guard historyLength > 0 else { return fallback }
        let maxHistoryIndex = historyLength - 1
        let delayIndex = Int(audioDelay * Float(maxHistoryIndex))
        let clampedIndex = min(max(0, delayIndex), maxHistoryIndex)
        let arrayIndex = max(0, historyLength - 1 - clampedIndex)
        if audioSmoothedSource == -1 {
            return history[arrayIndex].processedVolume
        } else if let val = history[arrayIndex].smoothedProcessedVolumes[audioSmoothedSource] {
            return val
        }
        return 0.0
    }
}
