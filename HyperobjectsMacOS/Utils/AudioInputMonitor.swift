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
    @Published var lowpassVolume: Double = 0.0
    @Published var lowpassVolumeSmoothed: Double = 0.0

    @Published var smoothingSampleCount: Int = 10 {
        didSet {
            recentVolumes = []
        }
    }

    @Published var lowpassCutoffFrequency: Float = 200.0 // in Hz

    private var recentVolumes: [Float] = []
    private var lastLowpass: Double = 0.0
    private var sampleRate: Float = 44100.0

    init() {
        audioEngine = AVAudioEngine()
        setupAudioSinkNode()
    }

    private func setupAudioSinkNode() {
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        sampleRate = Float(format.sampleRate)

        sinkNode = AVAudioSinkNode { [weak self] (_, frameCount, audioBufferListPointer) -> OSStatus in
            guard let self = self else { return noErr }

            let mutableABLPointer = UnsafeMutablePointer(mutating: audioBufferListPointer)
            let ablPointer = UnsafeMutableAudioBufferListPointer(mutableABLPointer)

            guard let firstBuffer = ablPointer.first,
                  let dataPtr = firstBuffer.mData?.assumingMemoryBound(to: Float.self) else {
                return noErr
            }

            let count = Int(frameCount)
            let samples = Array(UnsafeBufferPointer(start: dataPtr, count: count))

            var sum: Float = 0.0
            vDSP_measqv(samples, 1, &sum, vDSP_Length(count))
            let rms = sqrt(sum)
            let avgPower = 20 * log10(rms)
            let normalizedVolume = min(max((avgPower + 80) / 80, 0), 1)

            // --- Lowpass filter as one-pole IIR ---
            let cutoff = max(self.lowpassCutoffFrequency, 1.0)
            let dt = 1.0 / self.sampleRate
            let rc = 1.0 / (2 * Float.pi * cutoff)
            let alpha = dt / (rc + dt)

            // For metering, lowpass the normalizedVolume, or you could filter the RMS directly.
            let filtered: Double = self.lastLowpass + Double(alpha) * (Double(normalizedVolume) - self.lastLowpass)
            self.lastLowpass = filtered

            DispatchQueue.main.async {
                self.volume = normalizedVolume
                self.lowpassVolume = filtered
                self.updateSmoothedVolume(newVolume: normalizedVolume)
            }

            return noErr
        }

        if let sinkNode = sinkNode {
            audioEngine.attach(sinkNode)
            audioEngine.connect(inputNode, to: sinkNode, format: format)
        }
    }

    private func updateSmoothedVolume(newVolume: Float) {
        recentVolumes.append(newVolume)
        if recentVolumes.count > smoothingSampleCount {
            recentVolumes.removeFirst()
        }
        let total = recentVolumes.reduce(0, +)
        smoothedVolume = total / Float(recentVolumes.count)
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
