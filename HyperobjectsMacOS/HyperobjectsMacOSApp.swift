//
//  HyperobjectsMacOSApp.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 11/10/2024.
//

import SwiftUI

@main
struct HyperobjectsMacOSApp: App {
    @StateObject private var sceneManager = SceneManager(initialScene: generateGeometrySceneLine())
    @StateObject private var renderConfigurations = RenderConfigurations()
    @StateObject private var jsEngine = JSEngineManager()
    @StateObject private var fileMonitor = FileMonitor()
    @State private var selectedFile: URL?
    @State private var isFilePickerPresented = false
    @State private var appTime: Double = 0
    @State private var timer: Timer?
    
    @State private var latestScript: String = ""
    
    // A simple holder to avoid capturing self in the escaping closure during init
    private final class TimeBox {
        var value: Double
        init(_ value: Double) { self.value = value }
    }
    
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
                        
                        var inputState: [String: StateValue] = [
                            "time": StateValue(value: .float(timeBox.value)),
                            "width": StateValue(value: .float(800.0)),
                            "height": StateValue(value: .float(600.0))
                        ]
                        let currentSceneInputs = sceneManager.currentScene.inputs
                        for input in currentSceneInputs {
                            inputState[input.name] = input.toStateValue()
                        }
                        _ = jsEngine.executeScript(script, inputState: inputState)
                        
                        DispatchQueue.main.async {
                            latestScript = script
                            let outputState = jsEngine.outputState
                            // print("output state: \(outputState)")
                            
                            // Compare outputState to inputState and print changes only (no scene mutation yet)
                            let epsilon: Double = 1e-6
                            for (key, outVal) in outputState {
                                // print("Evaluating \(key)")
                                guard let inVal = inputState[key] else {
                                    // print("[State Change] New key in output not present in input: \(key) => \(outVal)")
                                    continue
                                }
                                switch (inVal.value, outVal.value) {
                                case (.float(let a), .float(let b)):
                                    if abs(Double(a) - Double(b)) > epsilon {
                                        print("[State Change] \(key): \(a) -> \(b)")
                                        // Update the matching input safely by name, avoiding optional-call and enum ambiguity
                                        if let input = sceneManager.currentScene.inputs.first(where: { $0.name == key }) {
                                            print("updating input value for \(key)")
                                            input.value = Double(b)
                                        }
                                    }
                                default:
                                    // Different types or unhandled types
                                    print("[State Change] Type or value changed for key \(key): \(inVal) -> \(outVal)")
                                }
                            }
                        }
                        
                    }
                    
                    
                    if timer == nil {
                        let newTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 120.0, repeats: true) { _ in
                            appTime += 1.0 / 120.0
                            timeBox.value = appTime
                            if renderConfigurations.runScriptOnFrameChange && latestScript.isEmpty == false {
                                var inputState: [String: StateValue] = [
                                    "time": StateValue(value: .float(timeBox.value)),
                                    "width": StateValue(value: .float(800.0)),
                                    "height": StateValue(value: .float(600.0))
                                ]
                                let currentSceneInputs = sceneManager.currentScene.inputs
                                for input in currentSceneInputs {
                                    inputState[input.name] = input.toStateValue()
                                }
                                _ = jsEngine.executeScript(latestScript, inputState: inputState)
                                
                                DispatchQueue.main.async {
                                    let outputState = jsEngine.outputState
                                    // print("output state: \(outputState)")
                                    
                                    // Compare outputState to inputState and print changes only (no scene mutation yet)
                                    let epsilon: Double = 1e-6
                                    for (key, outVal) in outputState {
                                        // print("Evaluating \(key)")
                                        guard let inVal = inputState[key] else {
                                            // print("[State Change] New key in output not present in input: \(key) => \(outVal)")
                                            continue
                                        }
                                        switch (inVal.value, outVal.value) {
                                        case (.float(let a), .float(let b)):
                                            if abs(Double(a) - Double(b)) > epsilon {
                                                print("[State Change] \(key): \(a) -> \(b)")
                                                // Update the matching input safely by name, avoiding optional-call and enum ambiguity
                                                if let input = sceneManager.currentScene.inputs.first(where: { $0.name == key }) {
                                                    print("updating input value for \(key)")
                                                    input.value = Double(b)
                                                }
                                            }
                                        default:
                                            // Different types or unhandled types
                                            print("[State Change] Type or value changed for key \(key): \(inVal) -> \(outVal)")
                                        }
                                    }
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
    
    func processScript() {
        
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

