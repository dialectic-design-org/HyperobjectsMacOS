//
//  AudioInputMonitor.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 22/06/2025.
//


import Foundation
import AVFoundation
import Accelerate

class AudioInputMonitor: ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var inputFormat: AVAudioFormat?
    @Published var volume: Float = 0.0
    @Published var smoothedVolume: Float = 0.0
    
    @Published var lowBandVolume: Float = 0.0
    @Published var midBandVolume: Float = 0.0
    @Published var highBandVolume: Float = 0.0
    
    private let fftSetup: vDSP_DFT_Setup
    private let fftSize = vDSP_Length(1024)
    private var window: [Float]
    
    init() {
        window = vDSP.window(ofType: Float.self, usingSequence: .hanningDenormalized, count: Int(fftSize), isHalfWindow: false)
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, fftSize, .FORWARD)!
        setupAudio()
    }
    
    deinit {
        vDSP_DFT_DestroySetup(fftSetup)
    }
    
    func setupAudio() {
        print("Setting up audio engine")
        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode
        inputFormat = inputNode?.outputFormat(forBus: 0)
        
        let recordingFormat = inputFormat
        inputNode?.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] (buffer, _) in
            self?.updateVolume(from: buffer)
        }
//
//        try? AVAudioSession.sharedInstance().setCategory(.record)
//        try? AVAudioSession.sharedInstance().setActive(true)
    }
    
    func updateVolume(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let channelDataValue = channelData.pointee
        let channelDataValues = stride(from: 0,
                                       to: Int(buffer.frameLength),
                                       by: buffer.stride).map { channelDataValue[$0] }
        let rms = sqrt(channelDataValues.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
        let avgPower = 20 * log10(rms)
        let normalizedValue = min(max((avgPower + 80) / 80, 0), 1)
        DispatchQueue.main.async { [weak self] in
            // print("Setting new volume value: \(normalizedValue)")
            self?.volume = normalizedValue
        }
        
        let currentVolume = self.volume
        let smoothingSize = 10
        let volumeStep = (normalizedValue - currentVolume) / Float(smoothingSize)
        for step in 1...smoothingSize {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * 0.01) {
                self.smoothedVolume = currentVolume + volumeStep * Float(step)
            }
        }
        
        // Further fourier transform frequency band analysis
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
    }
    
    func startMonitoring() {
        do {
            try print("Starting monitoring audio engine")
            try audioEngine?.start()
        } catch {
            print("Error starting audio engine: \(error)")
        }
        
        print("Started monitoring audio engine")
    }
    
    func stopMonitoring() {
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
    }
    

}
