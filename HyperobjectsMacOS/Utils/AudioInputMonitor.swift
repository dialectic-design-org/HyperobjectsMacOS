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
    private var audioEngine: AVAudioEngine
    private var sinkNode: AVAudioSinkNode?

    @Published var volume: Float = 0.0
    @Published var smoothedVolume: Float = 0.0
    @Published var smoothedVolumes: [Int:Float] = [:]
    @Published var lowpassVolume: Double = 0.0
    @Published var lowpassVolumeSmoothed: Double = 0.0

    @Published var smoothingSampleCount: Int = 10 {
        didSet {
            recentVolumes = []
        }
    }

    @Published var lowpassCutoffFrequency: Float = 200.0 // in Hz

    @Published var recentVolumes: [Float] = []
    @Published var recentVolumesPerSmoothing: [Int:[Float]] = [:]
    
    private var smoothingSteps: [Int] = [1, 2, 5, 20, 50]
    
    private var lastLowpass: Double = 0.0
    private var sampleRate: Float = 44100.0

    init() {
        audioEngine = AVAudioEngine()
        setupAudioSinkNode()
        for step in smoothingSteps {
            recentVolumesPerSmoothing[step] = []
            smoothedVolumes[step] = 0.0
        }
    }

    private func setupAudioSinkNode() {
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        sampleRate = Float(format.sampleRate)

        sinkNode = AVAudioSinkNode { [weak self] (_, frameCount, audioBufferListPointer) -> OSStatus in
            guard let self = self else { return noErr }

            // Access the interleaved/non-interleaved first channel directly; no copy.
            let ablPtr = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: audioBufferListPointer))
            guard let buf = ablPtr.first,
                  let base = buf.mData?.assumingMemoryBound(to: Float.self) else {
                return noErr
            }

            let count = Int(frameCount)

            // Compute mean square (vDSP_measqv) then sqrt for RMS, directly on the buffer.
            var ms: Float = 0
            vDSP_measqv(base, 1, &ms, vDSP_Length(count))
            var rms = sqrtf(ms)

            // --- FIX 1: guard against silence producing -∞/NaN ---
            if !rms.isFinite || rms <= 0 {
                rms = 0
            }

            // Compute a normalized linear volume robustly.
            // If you want a "VU" style with dB mapping, keep it but make it safe:
            var normalizedVolume: Float
            if rms <= 0 {
                normalizedVolume = 0
            } else {
                //  --- FIX 2: safe dB mapping (avoid -∞) ---
                // Reference floor at -80 dB, clamp to [0,1].
                let db = 20 * log10f(max(rms, 1e-12))   // epsilon prevents -∞
                normalizedVolume = min(max((db + 80) / 80, 0), 1)
                
            }
            
            if normalizedVolume == 0.0 {
                normalizedVolume = Float.random(in: 0..<1) / 10000.0
            }

            // --- One-pole low-pass (per callback), correct dt ---
            let cutoff = max(self.lowpassCutoffFrequency, 1.0)
            let dt = Float(frameCount) / self.sampleRate          // FIX 3: use frameCount
            let rc = 1.0 / (2 * Float.pi * cutoff)
            let alpha = dt / (rc + dt)

            var filtered = self.lastLowpass + Double(alpha) * (Double(normalizedVolume) - self.lastLowpass)

            // --- FIX 4: sanitize non-finite state ---
            if !filtered.isFinite { filtered = 0 }
            self.lastLowpass = filtered
            

            // Publish on main.
            DispatchQueue.main.async {
                // Extra paranoia: sanitize before publishing to UI.
                self.volume = normalizedVolume.isFinite ? normalizedVolume : 0
                self.lowpassVolume = filtered.isFinite ? filtered : 0
                self.updateSmoothedVolume(newVolume: self.volume) // uses finite value only
            }

            return noErr
        }

        if let sinkNode = sinkNode {
            audioEngine.attach(sinkNode)
            audioEngine.connect(inputNode, to: sinkNode, format: format)
        }
    }

    private func updateSmoothedVolume(newVolume: Float) {
        // print("updateSmoothedVolume")
        recentVolumes.append(newVolume)
        if recentVolumes.count > smoothingSampleCount {
            recentVolumes.removeFirst()
        }
        let total = recentVolumes.reduce(0, +)
        smoothedVolume = total / Float(recentVolumes.count)
        
        for (index, volumeDict) in recentVolumesPerSmoothing.enumerated() {
            // print("index \(index), key: \(volumeDict.key) volumes \(volumeDict.value)")
            // print(recentVolumesPerSmoothing[index])
            recentVolumesPerSmoothing[volumeDict.key]!.append(newVolume)
            if volumeDict.value.count > volumeDict.key {
                recentVolumesPerSmoothing[volumeDict.key]!.removeFirst()
            }
            let total = recentVolumesPerSmoothing[volumeDict.key]!.reduce(0, +)
            smoothedVolumes[volumeDict.key] = total / Float(volumeDict.key)
        }
    }

    func startMonitoring() {
        do {
            try audioEngine.start()
        } catch {
            print("Error starting audio engine: \(error)")
        }
    }

    func stopMonitoring() {
        audioEngine.stop()
    }
}
