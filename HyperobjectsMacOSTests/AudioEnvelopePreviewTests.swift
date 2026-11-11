//
//  AudioEnvelopePreviewTests.swift
//  HyperobjectsMacOSTests
//

import Testing
import Foundation
import AppKit
@testable import HyperobjectsMacOS

@MainActor
struct AudioEnvelopePreviewTests {

    private let plot = CGRect(x: 10, y: 20, width: 100, height: 50)

    @Test func envelopeSamplesCoverTheInputRange() {
        let envelope = SigmoidEnvelope()
        let samples = AudioEnvelopePreviewMath.samples(of: envelope, segmentCount: 10)
        #expect(samples.count == 11)
        #expect(samples.first == envelope.process(0))
        #expect(samples.last == envelope.process(1))
        // A sigmoid rises monotonically.
        #expect(zip(samples, samples.dropFirst()).allSatisfy { $0 <= $1 })
    }

    @Test func outputRangeGrowsWithGainAboveOne() {
        let envelope = SigmoidEnvelope()
        #expect(AudioEnvelopePreviewMath.outputRange(for: AudioEnvelopePreviewMath.samples(of: envelope)) == 1)
        envelope.outputGain = 2
        envelope.steepness = 50
        let range = AudioEnvelopePreviewMath.outputRange(for: AudioEnvelopePreviewMath.samples(of: envelope))
        #expect(range > 1.9 && range <= 2)
    }

    @Test func levelMapsIntoThePlotAndIsClamped() {
        let math = AudioEnvelopePreviewMath.self
        #expect(math.point(input: 0, output: 0, outputRange: 1, in: plot) == CGPoint(x: 10, y: 20))
        #expect(math.point(input: 1, output: 1, outputRange: 1, in: plot) == CGPoint(x: 110, y: 70))
        #expect(math.point(input: 0.5, output: 1, outputRange: 2, in: plot) == CGPoint(x: 60, y: 45))
        // Out of range and non-finite levels stay inside the plot.
        #expect(math.point(input: 3, output: 9, outputRange: 1, in: plot) == CGPoint(x: 110, y: 70))
        #expect(math.point(input: -1, output: -1, outputRange: 1, in: plot) == CGPoint(x: 10, y: 20))
        #expect(math.point(input: .nan, output: .infinity, outputRange: 1, in: plot) == CGPoint(x: 10, y: 20))
    }

    @Test func curveSignatureFollowsTheSelectedEnvelope() {
        let scene = generateGeometrySceneLiveCoding()
        let initial = AudioEnvelopeCurveSignature(scene: scene)
        #expect(initial == AudioEnvelopeCurveSignature(scene: scene))
        #expect(initial.caption.hasPrefix("steep "))

        scene.sigmoidEnvelope.threshold = 0.2
        #expect(AudioEnvelopeCurveSignature(scene: scene) != initial)

        scene.selectedEnvelopeType = .freeform
        #expect(AudioEnvelopeCurveSignature(scene: scene).caption == "freeform, 3 points")
    }

    @Test func previewRedrawsTheCurveOnlyWhenTheEnvelopeChanges() {
        let scene = generateGeometrySceneLiveCoding()
        let view = AudioEnvelopePreviewView(frame: CGRect(origin: .zero, size: AudioEnvelopePreviewView.preferredSize))
        view.scene = scene
        #expect(view.curveRevision == 1)

        // A changing audio level moves the marker and leaves the curve alone.
        scene.audioState.signal = 0.5
        scene.audioState.signalProcessed = scene.sigmoidEnvelope.process(0.5)
        view.refresh()
        #expect(view.curveRevision == 1)
        let expected = AudioEnvelopePreviewMath.point(input: 0.5, output: scene.sigmoidEnvelope.process(0.5),
                                                      outputRange: 1, in: view.plotRect)
        #expect(view.markerPosition == expected)
        #expect(abs(view.markerPosition.x - view.plotRect.midX) < 0.001)

        view.refresh()
        #expect(view.curveRevision == 1)

        // Changing the sigmoid redraws the curve once.
        scene.sigmoidEnvelope.steepness = 40
        view.refresh()
        view.refresh()
        #expect(view.curveRevision == 2)

        scene.selectedEnvelopeType = .freeform
        view.refresh()
        #expect(view.curveRevision == 3)

        // The preview never takes clicks from the render view or the editor.
        #expect(view.hitTest(CGPoint(x: 20, y: 20)) == nil)
    }

    @Test func previewIsOffByDefault() {
        #expect(RenderConfigurations().showAudioEnvelopePreview == false)
    }
}
