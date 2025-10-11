//
//  FileMonitor.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 08/10/2025.
//


import SwiftUI
import Combine

class FileMonitor: ObservableObject {
    @Published var isMonitoring = false
    private var fileURL: URL?
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var callback: ((String) -> Void)?
    
    init() {
        print("Initialising FileMonitor")
    }
    
    func startMonitoring(url: URL) {
        print("Starting file monitor")
        stopMonitoring()
        
        fileURL = url
        
        guard url.startAccessingSecurityScopedResource() else {
            print("Failed to access security-scoped resource")
            return
        }
        
        
        print("Attempting to open file")
        fileDescriptor = open(url.path, O_EVTONLY)
        
        guard fileDescriptor >= 0 else {
            print("Failed to open file for monitoring: \(url.path)")
            print("Error: \(String(cString: strerror(errno)))")
            url.stopAccessingSecurityScopedResource()
            return
        }
        
        let queue = DispatchQueue(label: "file.monitor")
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: queue
        )
        
        source?.setEventHandler { [weak self] in
            self?.handleFileChange()
        }
        
        source?.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
            }
        }
        
        source?.resume()
        isMonitoring = true
        
        // Initial load
        handleFileChange()
    }
    
    private func handleFileChange() {
        guard let url = fileURL else { return }
        
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            DispatchQueue.main.async {
                self.callback?(content)
            }
        } catch {
            print("Error reading file: \(error)")
        }
    }
    
    func stopMonitoring() {
        source?.cancel()
        source = nil
        if let url = fileURL {
            url.stopAccessingSecurityScopedResource()
        }
        fileURL = nil
        isMonitoring = false
    }
    
    func setCallback(_ callback: @escaping(String) -> Void) {
        self.callback = callback
    }
    
    deinit {
        stopMonitoring()
    }
}
