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

@main
struct HyperobjectsMacOSApp: App {
    @StateObject private var sceneManager = SceneManager(initialScene: generateGeometrySceneLine())
    @StateObject private var renderConfigurations = RenderConfigurations()
    @StateObject private var jsEngine = JSEngineManager()
    @StateObject private var fileMonitor = FileMonitor()
    @StateObject private var audioMonitor = AudioInputMonitor()
    @State private var selectedFile: URL?
    @State private var isFilePickerPresented = false
    @State private var appTime: Double = 0
    @State private var timer: Timer?
    
    @State private var latestScript: String = ""
    
    // A simple holder to avoid capturing self in the escaping closure during init
    
    
    private let timeBox: TimeBox
    
    
    init() {
        print("Application initialized")
        // Initialize a box to hold time without capturing self
        let timeBox = TimeBox(0)
        self.timeBox = timeBox
        
        // Build the FileMonitor without capturing self
        
    }
    
    var body: some Scene {
        WindowGroup("Main", id: "main") {
            ContentView()
                .environmentObject(sceneManager.currentScene)
                .environmentObject(renderConfigurations)
                .onAppear {
                    print("Main content view onappear")
                    fileMonitor.setCallback { [weak sceneManager, weak jsEngine] script in
                        guard let sceneManager = sceneManager, let jsEngine = jsEngine else { return }
                        
                        var inputState = prepareScriptInput(sceneManager: sceneManager, timeBox: timeBox)
                        
                        _ = jsEngine.executeScript(script, inputState: inputState)
                        
                        DispatchQueue.main.async {
                            latestScript = script
                            let outputState = jsEngine.outputState
                            applyScriptOutput(inputState: inputState, outputState: outputState, sceneManager: sceneManager)
                        }
                        
                    }
                    
                    
                    if timer == nil {
                        let newTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 120.0, repeats: true) { _ in
                            appTime += 1.0 / 120.0
                            timeBox.value = appTime
                            // print("Script timer: runScriptOnFrameChange: \(renderConfigurations.runScriptOnFrameChange)")
                            if renderConfigurations.runScriptOnFrameChange && latestScript.isEmpty == false {
                                
                                var inputState = prepareScriptInput(sceneManager: sceneManager, timeBox: timeBox)
                                
                                _ = jsEngine.executeScript(latestScript, inputState: inputState)
                                
                                DispatchQueue.main.async {
                                    let outputState = jsEngine.outputState
                                    // print("output state: \(outputState)")
                                    applyScriptOutput(inputState: inputState, outputState: outputState, sceneManager: sceneManager)
                                }
                            }
                        }
                        RunLoop.current.add(newTimer, forMode: .common)
                        timer = newTimer
                    }
                    
                    sceneManager.currentScene.setWrappedGeometries()
                }
                .onDisappear {
                    timer?.invalidate()
                    timer = nil
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
        }
        
        Window("\(sceneInputsWindowConfig.title) (scene: \(sceneManager.currentScene.name))", id: sceneInputsWindowConfig.id) {
            sceneInputsWindowConfig.content.environmentObject(sceneManager.currentScene)
                .environmentObject(jsEngine)
                .environmentObject(fileMonitor)
                .environmentObject(audioMonitor)
        }

        Window("\(renderConfigurationsWindowConfig.title) (scene: \(sceneManager.currentScene.name))", id: renderConfigurationsWindowConfig.id) {
            renderConfigurationsWindowConfig.content.environmentObject(sceneManager.currentScene)
                                                    .environmentObject(renderConfigurations)
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
    }
    
}


private func prepareScriptInput(sceneManager: SceneManager, timeBox: TimeBox) -> [String: StateValue] {
    var inputState: [String: StateValue] = [
        "time": StateValue(value: .float(timeBox.value)),
        "width": StateValue(value: .float(800.0)),
        "height": StateValue(value: .float(600.0))
    ]
    let currentSceneInputs = sceneManager.currentScene.inputs
    for input in currentSceneInputs {
        inputState[input.name] = input.toStateValue()
        inputState["audio_add_\(input.name)"] = StateValue(value: .float(Double(input.audioAmplificationAddition)))
        inputState["audio_multiply_\(input.name)"] = StateValue(value: .float(Double(input.audioAmplificationAddition)))
        inputState["audio_multiply_offset_\(input.name)"] = StateValue(value: .float(Double(input.audioAmplificationAddition)))
        inputState["audio_delay_\(input.name)"] = StateValue(value: .float(Double(input.audioAmplificationAddition)))
        
    }
    return inputState
}


func applyScriptOutput(inputState: [String: StateValue], outputState: [String: StateValue], sceneManager: SceneManager) {
    // Compare outputState to inputState and print changes only (no scene mutation yet)
    let epsilon: Double = 1e-6
    for (key, outVal) in outputState {
        // print("Evaluating \(key)")
        
        guard let inVal = inputState[key] else {
            // print("[State Change] New key in output not present in input: \(key) => \(outVal)")
            print("inVal not available for key \(key)")
            continue
        }
        switch (inVal.value, outVal.value) {
        case (.float(let a), .float(let b)):
            // Only apply state change above certain difference
            if abs(Double(a) - Double(b)) > epsilon {
                // print("[State Change] \(key): \(a) -> \(b)")
                // if prefixed with audio_add
                if key.isEmpty == false, key.hasPrefix("audio_add_") {
                    // print("Audio add prefix")
                    // get key without prefix
                    let audioKey = String(key.dropFirst("audio_add_".count))
                    if let input = sceneManager.currentScene.inputs.first(where: { $0.name == audioKey }) {
                        input.audioAmplificationAddition = Float(b)
                    }
                } else if  key.isEmpty == false, key.hasPrefix("audio_multiply_offset_") {
                    // get key without prefix
                    let audioKey = String(key.dropFirst("audio_multiply_offset_".count))
                    if let input = sceneManager.currentScene.inputs.first(where: { $0.name == audioKey }) {
                        input.audioAmplificationMultiplicationOffset = Float(b)
                    }
                } else if  key.isEmpty == false, key.hasPrefix("audio_multiply_") {
                    // get key without prefix
                    let audioKey = String(key.dropFirst("audio_multiply_".count))
                    if let input = sceneManager.currentScene.inputs.first(where: { $0.name == audioKey }) {
                        input.audioAmplificationMultiplication = Float(b)
                    }
                }else if  key.isEmpty == false, key.hasPrefix("audio_delay_") {
                    // get key without prefix
                    let audioKey = String(key.dropFirst("audio_delay_".count))
                    if let input = sceneManager.currentScene.inputs.first(where: { $0.name == audioKey }) {
                        input.audioDelay = Float(b)
                    }
                } else {
                    // Update the matching input safely by name, avoiding optional-call and enum ambiguity
                    if let input = sceneManager.currentScene.inputs.first(where: { $0.name == key }) {
                        if input.type == .float {
                            input.value = Double(b)
                        } else if input.type == .integer {
                            input.value = Int(b)
                        }
                    }
                }
                
                
                
            }
        case (.vector4(let a), .vector4(let b)):
            if let input = sceneManager.currentScene.inputs.first(where: { $0.name == key }) {
                if input.type == .colorInput {
                    let nsColor = NSColor(deviceRed: b[0], green: b[1], blue: b[2], alpha: b[3])
                    input.value = Color(nsColor: nsColor)
                }
            }
            
        default:
            // Different types or unhandled types
            print("[State Change] Type or value changed for key \(key): \(inVal) -> \(outVal)")
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

