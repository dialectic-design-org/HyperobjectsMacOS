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

@main
struct HyperobjectsMacOSApp: App {
    @StateObject private var sceneManager = SceneManager(initialScene: generateGeometrySceneSwarm())
    @StateObject private var renderConfigurations = RenderConfigurations()
    @StateObject private var jsEngine = JSEngineManager()
    @StateObject private var fileMonitor = FileMonitor()
    @StateObject private var audioMonitor = AudioInputMonitor()
    @StateObject private var videoStreamManager = VideoStreamManager()
    @StateObject private var midiManager = MIDIManager()
    @State private var selectedFile: URL?
    @State private var isFilePickerPresented = false
    @State private var jsTimer: DispatchSourceTimer?
    
    @State private var latestScript: String = ""
    private let timeBox: TimeBox
    private let scriptInputCache = ScriptInputCache()
    
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
                    jsEngine.reset()
                    scriptInputCache.update(prepareScriptInput(sceneManager: sceneManager, timeBox: timeBox, audioMonitor: audioMonitor, midiControls: midiManager.controls))
                    sceneManager.currentScene.refreshSceneInputSnapshot()
                }
                .onAppear {
                    print("Main content view onappear")
                    audioMonitor.startMonitoring()
                    fileMonitor.setCallback { [weak sceneManager, weak jsEngine, weak midiManager] script in
                        guard let sceneManager = sceneManager, let jsEngine = jsEngine, let midiManager = midiManager else { return }
                        
                        let targetScene = sceneManager.currentScene
                        let inputState = prepareScriptInput(scene: targetScene, timeBox: timeBox, audioMonitor: audioMonitor, midiControls: midiManager.controls)
                        
                        _ = jsEngine.executeScript(script, inputState: inputState) { outputState in
                            latestScript = script
                            applyScriptOutput(inputState: inputState, outputState: outputState, scene: targetScene)
                            targetScene.refreshSceneInputSnapshot()
                        }
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
                                _ = jsEngine.executeScript(latestScript, inputState: inputState) { outputState in
                                    if outputState.keys.contains("RESET") {
                                        targetScene.resetAllInputsToInitialValues()
                                    }
                                    applyScriptOutput(inputState: inputState, outputState: outputState, scene: targetScene)
                                    targetScene.refreshSceneInputSnapshot()
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
        }
        
        Window("\(windowsManagerWindowConfig.title) (scene: \(sceneManager.currentScene.name))", id: windowsManagerWindowConfig.id) {
            windowsManagerWindowConfig.content.environmentObject(sceneManager.currentScene)
        }
        
        Window("\(secondaryRenderWindowConfig.title) (scene: \(sceneManager.currentScene.name))", id: secondaryRenderWindowConfig.id) {
            secondaryRenderWindowConfig.content.environmentObject(sceneManager.currentScene)
                                               .environmentObject(renderConfigurations)
                                               .environmentObject(videoStreamManager)
        }
        
        Window("\(sceneInputsWindowConfig.title) (scene: \(sceneManager.currentScene.name))", id: sceneInputsWindowConfig.id) {
            sceneInputsWindowConfig.content.environmentObject(sceneManager.currentScene)
                .environmentObject(renderConfigurations)
                .environmentObject(jsEngine)
                .environmentObject(fileMonitor)
                .environmentObject(audioMonitor)
        }

        Window("\(renderConfigurationsWindowConfig.title) (scene: \(sceneManager.currentScene.name))", id: renderConfigurationsWindowConfig.id) {
            renderConfigurationsWindowConfig.content.environmentObject(sceneManager.currentScene)
                                                    .environmentObject(renderConfigurations)
                                                    .environmentObject(videoStreamManager)
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


func applyScriptOutput(inputState: [String: StateValue], outputState: [String: StateValue], scene: GeometriesSceneBase) {
    // Compare outputState to inputState and print changes only (no scene mutation yet)
    let epsilon: Double = 1e-6
    for (key, outVal) in outputState {
        // print("Evaluating \(key)")
        
        guard let inVal = inputState[key] else {
            // print("[State Change] New key in output not present in input: \(key) => \(outVal)")
            if key != "RESET" {
                print("inVal not available for key \(key)")
            }
            continue
        }
        
        switch (inVal.value, outVal.value) {
        case (.float(let a), .float(let b)):
            // Only apply state change above certain difference
            // if abs(Double(a) - Double(b)) > epsilon {
                // print("[State Change] \(key): \(a) -> \(b)")
                // if prefixed with audio_add
                if key.isEmpty == false, key.hasPrefix("audio_add_") {
                    // print("Audio add prefix")
                    // get key without prefix
                    let audioKey = String(key.dropFirst("audio_add_".count))
                    if let input = scene.inputs.first(where: { $0.name == audioKey }) {
                        input.audioAmplificationAddition = Float(b)
                    }
                } else if  key.isEmpty == false, key.hasPrefix("audio_multiply_offset_") {
                    // get key without prefix
                    let audioKey = String(key.dropFirst("audio_multiply_offset_".count))
                    if let input = scene.inputs.first(where: { $0.name == audioKey }) {
                        input.audioAmplificationMultiplicationOffset = Float(b)
                    }
                } else if  key.isEmpty == false, key.hasPrefix("audio_multiply_") {
                    // get key without prefix
                    let audioKey = String(key.dropFirst("audio_multiply_".count))
                    if let input = scene.inputs.first(where: { $0.name == audioKey }) {
                        input.audioAmplificationMultiplication = Float(b)
                    }
                }else if  key.isEmpty == false, key.hasPrefix("audio_delay_") {
                    // get key without prefix
                    let audioKey = String(key.dropFirst("audio_delay_".count))
                    if let input = scene.inputs.first(where: { $0.name == audioKey }) {
                        input.audioDelay = Float(b)
                    }
                } else if key.isEmpty == false, key.hasPrefix("frame_tick_") {
                    let audioKey = String(key.dropFirst("frame_tick_".count))
                    if let input = scene.inputs.first(where: { $0.name == audioKey }) {
                        input.tickValueAdjustment = Double(b)
                    }
                } else if key.isEmpty == false, key.hasPrefix("audio_smoothed_source_") {
                    let audioKey = String(key.dropFirst("audio_smoothed_source_".count))
                    if let input = scene.inputs.first(where: { $0.name == audioKey }) {
                        input.audioSmoothedSource = Int(b)
                    }
                } else {
                    // Update the matching input safely by name, avoiding optional-call and enum ambiguity
                    if let input = scene.inputs.first(where: { $0.name == key }) {
                        
                        if input.type == .float {
                            input.value = Double(b)
                        } else if input.type == .statefulFloat {
                            input.value = Double(b)
                        } else if input.type == .integer {
                            input.value = Int(b)
                        }
                    }
                }
        case (.vector4(let a), .vector4(let b)):
            if let input = scene.inputs.first(where: { $0.name == key }) {
                if input.type == .colorInput {
                    let nsColor = NSColor(deviceRed: b[0], green: b[1], blue: b[2], alpha: b[3])
                    input.value = Color(nsColor: nsColor)
                }
            }
        case (.string(_), .string(let b)):
            if let input = scene.inputs.first(where: { $0.name == key }) {
                if input.type == .string {
                    input.value = b
                }
            }
        case (.lineSegments(let a), .lineSegments(let b)):
            if let input = scene.inputs.first(where: { $0.name == key }) {
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
