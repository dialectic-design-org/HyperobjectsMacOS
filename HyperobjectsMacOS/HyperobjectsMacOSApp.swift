//
//  HyperobjectsMacOSApp.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 11/10/2024.
//

import SwiftUI

private final class TimeBox {
    var value: Double
    init(_ value: Double) { self.value = value }
}

private final class ScriptInputCache {
    private var current: [String: StateValue] = [:]
    private let lock = NSLock()
    
    func update(_ next: [String: StateValue]) {
        lock.lock(); current = next; lock.unlock()
    }
    
    func snapshot() -> [String: StateValue] {
        lock.lock(); defer { lock.unlock() }
        return current
    }
}

/// Caches each scene's `baseState` (its inputs' authored initial values). Initial values
/// never change after a scene is built, so this is computed once per scene.
private final class ScriptBaseStateCache {
    private var sceneID: ObjectIdentifier?
    private var current: [String: StateValue] = [:]
    private let lock = NSLock()

    func baseState(for scene: GeometriesSceneBase) -> [String: StateValue] {
        let id = ObjectIdentifier(scene)
        lock.lock(); defer { lock.unlock() }
        if sceneID != id {
            current = prepareScriptBaseState(scene: scene)
            sceneID = id
        }
        return current
    }
}

private final class ScriptOutputWarningCache {
    private var boolTypeMismatchKeys: Set<String> = []
    private let lock = NSLock()

    private var intCoercionFailureKeys: Set<String> = []

    func warnIntCoercionFailureOnce(key: String, output: StateValue) {
        lock.lock()
        let isNew = intCoercionFailureKeys.insert(key).inserted
        lock.unlock()
        if isNew {
            print("[State Change] Could not convert output for integer input \(key) to an Int: \(output)")
        }
    }

    func warnBoolTypeMismatchOnce(key: String, input: StateValue, output: StateValue) {
        lock.lock()
        let isNew = boolTypeMismatchKeys.insert(key).inserted
        lock.unlock()
        if isNew {
            print("[State Change] Ignoring bool output for numeric key \(key): \(input) -> \(output)")
        }
    }
}

private func safeInt(_ value: Double) -> Int? {
    guard value.isFinite else { return nil }
    if value >= Double(Int.max) { return Int.max }
    if value <= Double(Int.min) { return Int.min }
    return Int(value)
}

@main
struct HyperobjectsMacOSApp: App {
    @StateObject private var sceneManager = SceneManager(initialScene: generateGeometrySceneSwarm())
    @StateObject private var renderConfigurations = RenderConfigurations()
    @StateObject private var jsEngine = JSEngineManager()
    @StateObject private var fileMonitor = FileMonitor()
    @StateObject private var audioMonitor = AudioInputMonitor()
    @StateObject private var videoStreamManager = VideoStreamManager()
    @StateObject private var midiManager = MIDIManager()
    @StateObject private var bandFieldManager = BandFieldManager()
    @StateObject private var liveCodeSession = LiveCodeSession()
    @State private var selectedFile: URL?
    @State private var isFilePickerPresented = false
    @State private var jsTimer: DispatchSourceTimer?
    
    @State private var latestScript: String = ""
    private let timeBox: TimeBox
    private let scriptInputCache = ScriptInputCache()
    private let scriptBaseStateCache = ScriptBaseStateCache()
    private let scriptOutputWarningCache = ScriptOutputWarningCache()
    
    init() {
        print("Application initialized")
        // Initialize a box to hold time without capturing self
        let timeBox = TimeBox(0)
        self.timeBox = timeBox
        
    }
    
    var body: some Scene {
        WindowGroup("Main", id: "main") {
            ContentView()
                .environmentObject(sceneManager.currentScene)
                .environmentObject(renderConfigurations)
                .environmentObject(videoStreamManager)
                .environmentObject(audioMonitor)
                .environmentObject(bandFieldManager)
                .environment(\.liveCodeSession, liveCodeSession)
                .modifier(LiveCodeAppBindings(
                    session: liveCodeSession,
                    jsEngine: jsEngine,
                    renderConfigs: renderConfigurations,
                    readoutSource: { [weak midiManager] in
                        var state = scriptInputCache.snapshot()
                        state["time"] = StateValue(value: .float(timeBox.value))
                        if let midiManager {
                            state["midi"] = midiManager.controls.javascriptStateValue()
                        }
                        return state
                    }
                ))
                .onChange(of: audioMonitor.smoothedVolume) { _, _ in
                    let snap = AudioSnapshot(
                        raw: audioMonitor.volume,
                        smoothed: audioMonitor.smoothedVolume,
                        smoothedPerStep: audioMonitor.smoothedVolumes,
                        lowpassRaw: Float(audioMonitor.lowpassVolume),
                        lowpassSmoothed: Float(audioMonitor.lowpassVolume)
                    )
                    sceneManager.currentScene.applyAudioTick(snap, using: sceneManager.currentScene.currentProcessor)
                    scriptInputCache.update(prepareScriptInput(sceneManager: sceneManager, timeBox: timeBox, audioMonitor: audioMonitor, midiControls: midiManager.controls))
                }
                .onChange(of: midiManager.lastCCUpdate) { _, _ in
                    let k7 = midiManager.controls.ccValue(controller: 7, interpolate: true)
                    let k8 = midiManager.controls.ccValue(controller: 8, interpolate: true)
                    let envelope = sceneManager.currentScene.sigmoidEnvelope
                    envelope.steepness = 0.0 + pow(k7 * 3, 5)
                    envelope.threshold = k8
                }
                .onChange(of: midiManager.lastSignalUpdate) { _, _ in
                    scriptInputCache.update(prepareScriptInput(sceneManager: sceneManager, timeBox: timeBox, audioMonitor: audioMonitor, midiControls: midiManager.controls))
                }
                .onChange(of: renderConfigurations.geometryTriggerMode) { _, newMode in
                    sceneManager.currentScene.setGeometryTriggerMode(newMode)
                }
                .onChange(of: ObjectIdentifier(sceneManager.currentScene)) { _, _ in
                    // New scene defaults to .onRenderRequest — push the user's current choice.
                    sceneManager.currentScene.setGeometryTriggerMode(renderConfigurations.geometryTriggerMode)
                    scriptInputCache.update(prepareScriptInput(sceneManager: sceneManager, timeBox: timeBox, audioMonitor: audioMonitor, midiControls: midiManager.controls))
                }
                .onChange(of: fileMonitor.unloadToken) { _, _ in
                    latestScript = ""
                    liveCodeSession.detach()
                    renderConfigurations.scriptRenderOverrides.clear()
                    jsEngine.reset()
                    bandFieldManager.disable()
                    scriptInputCache.update(prepareScriptInput(sceneManager: sceneManager, timeBox: timeBox, audioMonitor: audioMonitor, midiControls: midiManager.controls))
                    sceneManager.currentScene.refreshSceneInputSnapshot()
                }
                .onAppear {
                    print("Main content view onappear")
                    audioMonitor.startMonitoring()
                    // Single path for running a script, used by the editor overlay and (through the
                    // session) by FileMonitor. Calls `done(nil)` on success or `done(error)`.
                    let runScript: (String, @escaping (LiveCodeError?) -> Void) -> Void = { [weak sceneManager, weak jsEngine, weak midiManager] script, done in
                        guard let sceneManager = sceneManager, let jsEngine = jsEngine, let midiManager = midiManager else { return }
                        
                        let targetScene = sceneManager.currentScene
                        let inputState = prepareScriptInput(scene: targetScene, timeBox: timeBox, audioMonitor: audioMonitor, midiControls: midiManager.controls)
                        
                        let baseState = scriptBaseStateCache.baseState(for: targetScene)

                        _ = jsEngine.executeScript(
                            script,
                            inputState: inputState,
                            baseState: baseState,
                            completion: { outputState in
                                latestScript = script
                                applyScriptOutput(inputState: inputState, outputState: outputState, baseState: baseState, scene: targetScene, bandFieldManager: bandFieldManager, scriptRenderOverrides: renderConfigurations.scriptRenderOverrides, warningCache: scriptOutputWarningCache)
                                targetScene.refreshSceneInputSnapshot()
                                scriptInputCache.update(prepareScriptInput(scene: targetScene, timeBox: timeBox, audioMonitor: audioMonitor, midiControls: midiManager.controls))
                                done(nil)
                            },
                            failure: { message in
                                // errorLine is set in the same main-thread hand-off, before this runs.
                                done(LiveCodeError(message: message, line: jsEngine.errorLine))
                            }
                        )
                    }

                    liveCodeSession.evaluator = runScript
                    // File changes go through the session: it adopts the text (or flags a
                    // conflict with unsaved overlay edits) and evaluates via runScript.
                    fileMonitor.setCallback { [weak liveCodeSession] content in
                        liveCodeSession?.fileDidChangeOnDisk(content)
                    }
                    
                    
                    if jsTimer == nil {
                        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInteractive))
                        timer.schedule(deadline: .now(), repeating: 1.0 / 120.0)
                        timer.setEventHandler { [weak sceneManager, weak jsEngine, weak midiManager] in
                            guard let sceneManager, let jsEngine, let midiManager else { return }

                            timeBox.value += 1.0 / 120.0

                            if renderConfigurations.runScriptOnFrameChange && latestScript.isEmpty == false {
                                var inputState = scriptInputCache.snapshot()
                                inputState["time"] = StateValue(value: .float(timeBox.value))
                                inputState["midi"] = midiManager.controls.javascriptStateValue()

                                let targetScene = sceneManager.currentScene
                                let baseState = scriptBaseStateCache.baseState(for: targetScene)
                                _ = jsEngine.executeScript(latestScript, inputState: inputState, baseState: baseState, skipIfBusy: true) { outputState in
                                    applyScriptOutput(inputState: inputState, outputState: outputState, baseState: baseState, scene: targetScene, bandFieldManager: bandFieldManager, scriptRenderOverrides: renderConfigurations.scriptRenderOverrides, warningCache: scriptOutputWarningCache)
                                    targetScene.refreshSceneInputSnapshot()
                                    scriptInputCache.update(prepareScriptInput(scene: targetScene, timeBox: timeBox, audioMonitor: audioMonitor, midiControls: midiManager.controls))
                                }
                            }
                        }
                        timer.resume()
                        jsTimer = timer
                    }
                    
                    // Producer is now off-main; build the initial snapshot here on main,
                    // then ask the geometry queue to run once so renderBuffer has content.
                    sceneManager.currentScene.refreshSceneInputSnapshot()
                    sceneManager.currentScene.requestGeometryGeneration()
                }
                .onDisappear {
                    jsTimer?.cancel()
                    jsTimer = nil
                }
        }// Open it explicitly at launch (and keep a menu command for manual reopen)
        .commands {
            OpenMainWindowCommand()
            LiveCodeCommands(session: liveCodeSession, renderConfigs: renderConfigurations)
        }
        
        Window("\(windowsManagerWindowConfig.title) (scene: \(sceneManager.currentScene.name))", id: windowsManagerWindowConfig.id) {
            windowsManagerWindowConfig.content.environmentObject(sceneManager.currentScene)
        }
        
        Window("\(secondaryRenderWindowConfig.title) (scene: \(sceneManager.currentScene.name))", id: secondaryRenderWindowConfig.id) {
            secondaryRenderWindowConfig.content.environmentObject(sceneManager.currentScene)
                                               .environmentObject(renderConfigurations)
                                               .environmentObject(videoStreamManager)
                                               .environmentObject(bandFieldManager)
                                               .environment(\.liveCodeSession, liveCodeSession)
        }
        
        Window("\(sceneInputsWindowConfig.title) (scene: \(sceneManager.currentScene.name))", id: sceneInputsWindowConfig.id) {
            sceneInputsWindowConfig.content.environmentObject(sceneManager.currentScene)
                .environmentObject(renderConfigurations)
                .environmentObject(jsEngine)
                .environmentObject(fileMonitor)
                .environmentObject(audioMonitor)
                .environmentObject(liveCodeSession)
        }

        Window("\(renderConfigurationsWindowConfig.title) (scene: \(sceneManager.currentScene.name))", id: renderConfigurationsWindowConfig.id) {
            renderConfigurationsWindowConfig.content.environmentObject(sceneManager.currentScene)
                                                    .environmentObject(renderConfigurations)
                                                    .environmentObject(videoStreamManager)
                                                    .environmentObject(bandFieldManager)
                                                    .environmentObject(liveCodeSession)
        }
        
        Window("\(sceneGeometriesListWindowConfig.title) (scene: \(sceneManager.currentScene.name))", id: sceneGeometriesListWindowConfig.id) {
            sceneGeometriesListWindowConfig.content.environmentObject(sceneManager.currentScene)
        }
        
        Window("\(viewportFrontViewWindowConfig.title) (scene: \(sceneManager.currentScene.name))", id: viewportFrontViewWindowConfig.id) {
            viewportFrontViewWindowConfig.content.environmentObject(sceneManager.currentScene)
        }
        
        Window("\(viewportSideViewWindowConfig.title) (scene: \(sceneManager.currentScene.name))", id: viewportSideViewWindowConfig.id) {
            viewportSideViewWindowConfig.content.environmentObject(sceneManager.currentScene)
        }
        
        Window("\(viewportTopViewWindowConfig.title) (scene: \(sceneManager.currentScene.name))", id: viewportTopViewWindowConfig.id) {
            viewportTopViewWindowConfig.content.environmentObject(sceneManager.currentScene)
        }
        
        Window(sceneSelectorViewWindowConfig.title, id: sceneSelectorViewWindowConfig.id) {
            sceneSelectorViewWindowConfig.content.environmentObject(sceneManager)
        }
        
        Window("\(midiLogWindowConfig.title)", id: midiLogWindowConfig.id) {
            midiLogWindowConfig.content.environmentObject(midiManager)
        }

        Window("\(bandFieldPreviewWindowConfig.title)", id: bandFieldPreviewWindowConfig.id) {
            bandFieldPreviewWindowConfig.content.environmentObject(bandFieldManager)
        }
    }
    
}


private func prepareScriptInput(sceneManager: SceneManager, timeBox: TimeBox, audioMonitor: AudioInputMonitor, midiControls: MIDIControlState) -> [String: StateValue] {
    prepareScriptInput(scene: sceneManager.currentScene, timeBox: timeBox, audioMonitor: audioMonitor, midiControls: midiControls)
}

private func prepareScriptInput(scene: GeometriesSceneBase, timeBox: TimeBox, audioMonitor: AudioInputMonitor, midiControls: MIDIControlState) -> [String: StateValue] {
    
    var latestAudioAmplitude = scene.audioSignalProcessed.isZero ? 0.0 : scene.audioSignalProcessed.magnitude
    let smoothedAudioAmplitudes = scene.audioSignalsSmoothedProcessed.map {
        return $0.value
    }
    
    let recentVolumes = audioMonitor.recentVolumes.map {
        return Double($0)
    }
    
    let cutoff = (scene.audioHistory.suffix(1).first?.timestamp ?? 0) - 10.0
    let recentVolumesProcessed = scene.historyData(since: cutoff).map {
        return $0.processedVolume
    }
    
    var inputState: [String: StateValue] = [
        "time": StateValue(value: .float(timeBox.value)),
        "audioAmplitude": StateValue(value: .float(latestAudioAmplitude)),
        "smoothedAudioAmplitudes": StateValue(value: .floatArray(smoothedAudioAmplitudes)),
        "recentVolumesRaw": StateValue(value: .floatArray(recentVolumes)),
        "recentVolumesProcessed": StateValue(value: .floatArray(recentVolumesProcessed)),
        "midi": midiControls.javascriptStateValue(),
        "width": StateValue(value: .float(800.0)),
        "height": StateValue(value: .float(600.0))
    ]
    let currentSceneInputs = scene.inputs
    for input in currentSceneInputs {
        inputState[input.name] = input.toStateValue()
        inputState["audio_add_\(input.name)"] = StateValue(value: .float(Double(input.audioAmplificationAddition)))
        inputState["audio_multiply_\(input.name)"] = StateValue(value: .float(Double(input.audioAmplificationMultiplication)))
        inputState["audio_multiply_offset_\(input.name)"] = StateValue(value: .float(Double(input.audioAmplificationMultiplicationOffset)))
        inputState["audio_delay_\(input.name)"] = StateValue(value: .float(Double(input.audioDelay)))
        inputState["audio_smoothed_source_\(input.name)"] = StateValue(value: .float(Double(input.audioSmoothedSource)))
        inputState["frame_tick_\(input.name)"] = StateValue(value: .float(Double(input.tickValueAdjustment)))
        
    }
    return inputState
}


/// Builds the scene's base state: the same settable keys as `prepareScriptInput` emits for
/// each scene input, but holding the values the scene was authored with (what RESET restores).
private func prepareScriptBaseState(scene: GeometriesSceneBase) -> [String: StateValue] {
    var baseState: [String: StateValue] = [:]
    for input in scene.inputs {
        // A stateful float accumulates every frame; falling back to its initial value would
        // freeze it, so only its settings (tick / audio keys below) are part of the base state.
        if input.type != .statefulFloat {
            baseState[input.name] = input.initialStateValue()
        }
        baseState["audio_add_\(input.name)"] = StateValue(value: .float(Double(input.init_audioAmplificationAddition)))
        baseState["audio_multiply_\(input.name)"] = StateValue(value: .float(Double(input.init_audioAmplificationMultiplication)))
        baseState["audio_multiply_offset_\(input.name)"] = StateValue(value: .float(Double(input.init_audioAmplificationMultiplicationOffset)))
        baseState["audio_delay_\(input.name)"] = StateValue(value: .float(Double(input.init_audioDelay)))
        baseState["audio_smoothed_source_\(input.name)"] = StateValue(value: .float(Double(input.init_audioSmoothedSource)))
        baseState["frame_tick_\(input.name)"] = StateValue(value: .float(Double(input.init_tickValueAdjustment)))
    }
    return baseState
}


private func applyScriptOutput(inputState: [String: StateValue], outputState scriptOutput: [String: StateValue], baseState: [String: StateValue], scene: GeometriesSceneBase, bandFieldManager: BandFieldManager, scriptRenderOverrides: ScriptRenderOverrides, warningCache: ScriptOutputWarningCache) {
    // Compare outputState to inputState and print changes only (no scene mutation yet)
    let epsilon: Double = 1e-6
    // RESET: start this frame from the scene's base state. Any key the script did not return
    // falls back to its base value. This is merged here rather than resetting the inputs first,
    // so each input is written once with its final value and never passes through its base value
    // (which would land in the input history and briefly show up as a flash of the original scene).
    var outputState = scriptOutput
    if scriptOutput.keys.contains("RESET") {
        outputState = baseState.merging(scriptOutput) { _, scriptValue in scriptValue }
    }
    let inputsByName = Dictionary(scene.inputs.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
    if outputState["bands"] == nil {
        bandFieldManager.disable()
    }
    // Replaced as a whole each run: keys the script stopped returning fall back to the
    // Render Configurations values.
    scriptRenderOverrides.apply(from: outputState)
    for (key, outVal) in outputState {
        // print("Evaluating \(key)")

        if key == "bands" {
            bandFieldManager.apply(outVal)
            continue
        }

        if key == "RESET" {
            continue
        }

        // Camera/projection overrides: handled as a whole by scriptRenderOverrides.apply above.
        if ScriptRenderOverrides.keys.contains(key) {
            continue
        }
        
        guard let inVal = inputState[key] else {
            // print("[State Change] New key in output not present in input: \(key) => \(outVal)")
            print("inVal not available for key \(key)")
            continue
        }

        // Nothing to do when the value already matches. With RESET most keys come from
        // baseState and are unchanged frame to frame, so this keeps the per-frame main-thread
        // work proportional to what actually changed.
        if inVal.value == outVal.value {
            continue
        }
        
        // Integer scene inputs accept any output that can reasonably be read as an Int.
        if let input = inputsByName[key], input.type == .integer {
            if let intVal = outVal.coercedToInt() {
                input.value = intVal
            } else {
                warningCache.warnIntCoercionFailureOnce(key: key, output: outVal)
            }
            continue
        }

        switch (inVal.value, outVal.value) {
        case (.float, .bool):
            warningCache.warnBoolTypeMismatchOnce(key: key, input: inVal, output: outVal)
            continue
        case (.float(let a), .float(let b)):
            // Only apply state change above certain difference
            // if abs(Double(a) - Double(b)) > epsilon {
                // print("[State Change] \(key): \(a) -> \(b)")
                // if prefixed with audio_add
                if key.isEmpty == false, key.hasPrefix("audio_add_") {
                    // print("Audio add prefix")
                    // get key without prefix
                    let audioKey = String(key.dropFirst("audio_add_".count))
                    if let input = inputsByName[audioKey] {
                        input.audioAmplificationAddition = Float(b)
                    }
                } else if  key.isEmpty == false, key.hasPrefix("audio_multiply_offset_") {
                    // get key without prefix
                    let audioKey = String(key.dropFirst("audio_multiply_offset_".count))
                    if let input = inputsByName[audioKey] {
                        input.audioAmplificationMultiplicationOffset = Float(b)
                    }
                } else if  key.isEmpty == false, key.hasPrefix("audio_multiply_") {
                    // get key without prefix
                    let audioKey = String(key.dropFirst("audio_multiply_".count))
                    if let input = inputsByName[audioKey] {
                        input.audioAmplificationMultiplication = Float(b)
                    }
                }else if  key.isEmpty == false, key.hasPrefix("audio_delay_") {
                    // get key without prefix
                    let audioKey = String(key.dropFirst("audio_delay_".count))
                    if let input = inputsByName[audioKey] {
                        input.audioDelay = Float(b)
                    }
                } else if key.isEmpty == false, key.hasPrefix("frame_tick_") {
                    let audioKey = String(key.dropFirst("frame_tick_".count))
                    if let input = inputsByName[audioKey] {
                        input.tickValueAdjustment = Double(b)
                    }
                } else if key.isEmpty == false, key.hasPrefix("audio_smoothed_source_") {
                    let audioKey = String(key.dropFirst("audio_smoothed_source_".count))
                    if let input = inputsByName[audioKey] {
                        if let intVal = safeInt(b) {
                            input.audioSmoothedSource = intVal
                        } else {
                            print("[Script Output] Ignoring non-finite value for \(key): \(b)")
                        }
                    }
                } else {
                    // Update the matching input safely by name, avoiding optional-call and enum ambiguity
                    if let input = inputsByName[key] {
                        
                        if input.type == .float {
                            input.value = Double(b)
                        } else if input.type == .statefulFloat {
                            input.value = Double(b)
                        }
                    }
                }
        case (.vector4(let a), .vector4(let b)):
            if let input = inputsByName[key] {
                if input.type == .colorInput {
                    let nsColor = NSColor(deviceRed: b[0], green: b[1], blue: b[2], alpha: b[3])
                    input.value = Color(nsColor: nsColor)
                }
            }
        case (.string(_), .string(let b)):
            if let input = inputsByName[key] {
                if input.type == .string {
                    input.value = b
                }
            }
        case (.lineSegments(let a), .lineSegments(let b)):
            if let input = inputsByName[key] {
                var newLines: [Line] = []
                for scriptLine in b {
                    let start = SIMD3<Float>(Float(scriptLine.start.x), Float(scriptLine.start.y), Float(scriptLine.start.z))
                    let end = SIMD3<Float>(Float(scriptLine.end.x), Float(scriptLine.end.y), Float(scriptLine.end.z))
                    var newLine = Line(
                        startPoint: start,
                        endPoint: end,
                        lineWidthStart: Float(scriptLine.lineWidthStart),
                        lineWidthEnd: Float(scriptLine.lineWidthEnd)
                    )
                    newLine = newLine.setBasicEndPointColors(
                        startColor: SIMD4<Float>(
                            Float(scriptLine.colorStart.x),
                            Float(scriptLine.colorStart.y),
                            Float(scriptLine.colorStart.z),
                            Float(scriptLine.colorStart.w)
                        ),
                        endColor: SIMD4<Float>(
                            Float(scriptLine.colorEnd.x),
                            Float(scriptLine.colorEnd.y),
                            Float(scriptLine.colorEnd.z),
                            Float(scriptLine.colorEnd.w)
                        )
                    )
                    newLines.append(newLine)
                }
                input.value = newLines
            }
        default:
            // Different types or unhandled types
            print("[State Change] Type or value changed unhandled for key \(key): \(inVal) -> \(outVal)")
        }
    }
}


private struct OpenMainWindowCommand: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Open Main Window") { openWindow(id: "main") }
                .keyboardShortcut("0", modifiers: [.command])

            // Run once when commands initialize (app launch)
            .task {
                // openWindow(id: "main")
            }
        }
    }
}
