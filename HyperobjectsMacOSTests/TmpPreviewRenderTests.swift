import Testing
import Foundation
import AppKit
@testable import HyperobjectsMacOS

@MainActor
struct TmpPreviewRenderTests {
    private func render(_ scene: GeometriesSceneBase, name: String) -> String {
        let size = AudioEnvelopePreviewView.preferredSize
        let view = AudioEnvelopePreviewView(frame: CGRect(origin: .zero, size: size))
        view.scene = scene
        view.refresh()
        let scale: CGFloat = 3
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let ctx = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: size.width * scale, height: size.height * scale))
        ctx.scaleBy(x: scale, y: scale)
        view.layer!.render(in: ctx)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? rep.representation(using: .png, properties: [:])!.write(to: url)
        return url.path
    }

    @Test func renderPreviews() {
        let a = generateGeometrySceneLiveCoding()
        a.audioState.signal = 0.62
        a.audioState.signalProcessed = a.sigmoidEnvelope.process(0.62)
        let p1 = render(a, name: "envelope-default.png")

        let b = generateGeometrySceneLiveCoding()
        b.sigmoidEnvelope.steepness = 40; b.sigmoidEnvelope.threshold = 0.3; b.sigmoidEnvelope.outputGain = 1.6
        b.audioState.signal = 0.33
        b.audioState.signalProcessed = b.sigmoidEnvelope.process(0.33)
        let p2 = render(b, name: "envelope-steep-gain.png")
        Issue.record("PATHS \(p1) \(p2)")
    }
}
