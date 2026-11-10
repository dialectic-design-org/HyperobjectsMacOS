//
//  CodeFileSelector.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 08/10/2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct CodeFileSelector: View {
    @EnvironmentObject var fileMonitor: FileMonitor
    @EnvironmentObject var jsEngine: JSEngineManager
    @EnvironmentObject var liveCodeSession: LiveCodeSession
    @State private var selectedFile: URL?
    @State private var isFilePickerPresented = false
    @State private var appTime: Double = 0
    @State private var timer: Timer?
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                HStack {
                    Button(action: { isFilePickerPresented = true }) {
                        Label("Select JS File", systemImage: "doc.text")
                    }

                    Button(role: .destructive) {
                        selectedFile = nil
                        fileMonitor.unloadScript()
                    } label: {
                        Label("Unload Script", systemImage: "xmark.circle")
                    }
                    .disabled(selectedFile == nil && !fileMonitor.isMonitoring && jsEngine.outputState.isEmpty && jsEngine.errorMessage == nil)

                    Button {
                        // Unloading stops monitoring and resets the engine (via unloadToken);
                        // the session then starts an in-memory buffer for the overlay.
                        selectedFile = nil
                        fileMonitor.unloadScript()
                        DispatchQueue.main.async {
                            liveCodeSession.startScratch("outputState = {};\n")
                        }
                    } label: {
                        Label("New Scratch", systemImage: "square.and.pencil")
                    }
                    
                    Button {
                        jsEngine.resetInternalState()
                    } label: {
                        Label("Reset State", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(!fileMonitor.isMonitoring)

                    Button {
                        jsEngine.inspectInternalState()
                    } label: {
                        Label("Inspect State", systemImage: "eye")
                    }
                    .disabled(!fileMonitor.isMonitoring)
                    
                    if jsEngine.outputState.isEmpty && jsEngine.errorMessage == nil {
                        Text("Select a file")
                    }
                    
                    if let file = selectedFile {
                        Text(file.lastPathComponent)
                            .foregroundColor(.secondary)
                        
                        if fileMonitor.isMonitoring {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("Monitoring")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        
                        if let time = jsEngine.lastExecutionTime {
                            Text("Last update: \(time, style: .time)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(String(format: "Execution: %.2f ms", jsEngine.executionDuration))
                            .font(.caption)
                            .foregroundColor(jsEngine.executionDuration > 16 ? .orange : .secondary)

                    }
                }.padding(.horizontal)
                
                if let error = jsEngine.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.1))
                }
                
                if let description = jsEngine.internalStateDescription {
                    ScrollView {
                        Text(description)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 160)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 4)
            .background(Color(nsColor: .windowBackgroundColor))
            
        }.fileImporter(
            isPresented: $isFilePickerPresented,
            allowedContentTypes: [UTType(filenameExtension: "js") ?? .text],
            allowsMultipleSelection: false
        ) { result in
            print("Processing file selection result")
            switch result {
            case .success(let urls):
                print("fileImporter reports success, opening first url")
                if let url = urls.first {
                    print("first url is: \(url)")
                    
                    if url != selectedFile {
                        jsEngine.resetInternalState()
                    }
                    
                    selectedFile = url
                    // Attach before monitoring: the monitor's initial load fills the buffer.
                    liveCodeSession.attach(url: url)
                    print("starting fileMonitor.startMonitoring")
                    fileMonitor.startMonitoring(url: url)
                }
            case .failure(let error):
                print("File selection error: \(error)")
            }
        }
    }
}
