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
                    selectedFile = url
                    print("starting fileMonitor.startMonitoring")
                    fileMonitor.startMonitoring(url: url)
                }
            case .failure(let error):
                print("File selection error: \(error)")
            }
        }
    }
}
