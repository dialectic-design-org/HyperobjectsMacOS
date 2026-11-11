//
//  AudioEnvelopePreview.swift
//  HyperobjectsMacOS
//
//  Small white plot in the top right corner of the main render view: the current audio
//  envelope (sigmoid or freeform) as an input -> output curve, with a marker at the live
//  audio level. A quick check of the audio processing while performing.
//
//  Built for low overhead: Core Animation layers updated by a 30 Hz timer that reads the
//  scene directly. No SwiftUI observation and no redrawing per tick: the curve path is rebuilt
//  only when the envelope settings change, and the live level only moves existing layers.
//

import SwiftUI
import AppKit
import QuartzCore

/// What determines the shape of the envelope curve. The curve is redrawn only when this changes.
enum AudioEnvelopeCurveSignature: Equatable {
    case sigmoid(steepness: Double, threshold: Double, outputGain: Double)
    case freeform([ControlPoint])

    /// Main thread: reads the scene's envelope settings.
    init(scene: GeometriesSceneBase) {
        switch scene.selectedEnvelopeType {
        case .sigmoid:
            let envelope = scene.sigmoidEnvelope
            self = .sigmoid(steepness: envelope.steepness, threshold: envelope.threshold, outputGain: envelope.outputGain)
        case .freeform:
            self = .freeform(scene.freeformEnvelope.controlPoints)
        }
    }

    var caption: String {
        switch self {
        case .sigmoid(let steepness, let threshold, let outputGain):
            return String(format: "steep %.1f  thr %.2f  gain %.2f", steepness, threshold, outputGain)
        case .freeform(let points):
            return "freeform, \(points.count) points"
        }
    }
}

enum AudioEnvelopePreviewMath {
    /// Number of segments of the curve. Enough for a steep sigmoid to still read as a step.
    static let segmentCount = 96

    /// The envelope's output for inputs 0...1, `segmentCount + 1` values.
    static func samples(of processor: EnvelopeProcessor, segmentCount: Int = segmentCount) -> [Double] {
        (0...segmentCount).map { i in
            let output = processor.process(Double(i) / Double(segmentCount))
            return output.isFinite ? output : 0
        }
    }

    /// Top of the output axis: 1, or more when the envelope's gain pushes the curve above 1.
    static func outputRange(for samples: [Double]) -> Double {
        max(1.0, samples.max() ?? 1.0)
    }

    /// Position of an (input, output) pair in `plot` (origin bottom left, y up), kept inside it.
    static func point(input: Double, output: Double, outputRange: Double, in plot: CGRect) -> CGPoint {
        let x = input.isFinite ? min(max(input, 0), 1) : 0
        let range = outputRange > 0 ? outputRange : 1
        let y = output.isFinite ? min(max(output / range, 0), 1) : 0
        return CGPoint(x: plot.minX + CGFloat(x) * plot.width, y: plot.minY + CGFloat(y) * plot.height)
    }

    static func curvePath(samples: [Double], outputRange: Double, in plot: CGRect) -> CGPath {
        let path = CGMutablePath()
        guard samples.count > 1 else { return path }
        for (i, output) in samples.enumerated() {
            let input = Double(i) / Double(samples.count - 1)
            let p = point(input: input, output: output, outputRange: outputRange, in: plot)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        return path
    }
}

/// SwiftUI wrapper. Give it a fixed frame of `AudioEnvelopePreviewView.preferredSize`.
struct AudioEnvelopePreview: NSViewRepresentable {
    let scene: GeometriesSceneBase

    func makeNSView(context: Context) -> AudioEnvelopePreviewView {
        let view = AudioEnvelopePreviewView(frame: CGRect(origin: .zero, size: AudioEnvelopePreviewView.preferredSize))
        view.scene = scene
        return view
    }

    func updateNSView(_ view: AudioEnvelopePreviewView, context: Context) {
        if view.scene !== scene { view.scene = scene }
    }
}

final class AudioEnvelopePreviewView: NSView {
    static let preferredSize = CGSize(width: 150, height: 116)
    /// 30 Hz is smooth enough to read a level and far below the render and audio rates.
    static let updateInterval: TimeInterval = 1.0 / 30.0

    weak var scene: GeometriesSceneBase? {
        didSet {
            guard scene !== oldValue else { return }
            appliedSignature = nil
            refresh()
        }
    }

    private let axesLayer = CAShapeLayer()
    private let curveLayer = CAShapeLayer()
    private let inputGuide = CALayer()
    private let outputGuide = CALayer()
    private let marker = CALayer()
    private let captionLayer = CATextLayer()
    private let inputLabel = CATextLayer()
    private let outputLabel = CATextLayer()

    private var timer: Timer?
    private var appliedSignature: AudioEnvelopeCurveSignature?
    private var appliedPlot: CGRect = .null
    private var appliedMarker: CGPoint?
    private var outputRange = 1.0

    /// How often the curve was rebuilt, and where the live marker sits (for tests).
    private(set) var curveRevision = 0
    var markerPosition: CGPoint { marker.position }

    private static let captionHeight: CGFloat = 14
    private static let markerSize: CGFloat = 7

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        buildLayers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        timer?.invalidate()
    }

    /// The preview is display only: clicks go to whatever is underneath.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    /// The plot area inside the view (layer coordinates: origin bottom left).
    var plotRect: CGRect {
        CGRect(x: 1, y: Self.captionHeight + 2, width: max(bounds.width - 2, 1), height: max(bounds.height - Self.captionHeight - 3, 1))
    }

    private func buildLayers() {
        guard let root = layer else { return }
        let white = NSColor.white

        axesLayer.fillColor = nil
        axesLayer.strokeColor = white.withAlphaComponent(0.6).cgColor
        axesLayer.lineWidth = 1

        curveLayer.fillColor = nil
        curveLayer.strokeColor = white.cgColor
        curveLayer.lineWidth = 1.5
        curveLayer.lineJoin = .round

        inputGuide.backgroundColor = white.withAlphaComponent(0.5).cgColor
        outputGuide.backgroundColor = white.withAlphaComponent(0.5).cgColor

        marker.backgroundColor = white.cgColor
        marker.bounds = CGRect(x: 0, y: 0, width: Self.markerSize, height: Self.markerSize)
        marker.cornerRadius = Self.markerSize / 2

        configure(captionLayer, size: 9, alpha: 0.85)
        configure(inputLabel, size: 8, alpha: 0.6)
        configure(outputLabel, size: 8, alpha: 0.6)
        inputLabel.string = "in"
        inputLabel.alignmentMode = .right
        outputLabel.string = "out"

        for sublayer in [axesLayer, curveLayer, inputGuide, outputGuide, marker, inputLabel, outputLabel, captionLayer] {
            root.addSublayer(sublayer)
        }
    }

    private func configure(_ text: CATextLayer, size: CGFloat, alpha: CGFloat) {
        text.font = NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        text.fontSize = size
        text.foregroundColor = NSColor.white.withAlphaComponent(alpha).cgColor
        text.truncationMode = .end
    }

    // MARK: - Lifecycle

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        timer?.invalidate()
        timer = nil
        guard window != nil else { return }
        updateContentsScale()
        refresh()
        let timer = Timer(timeInterval: Self.updateInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        timer.tolerance = Self.updateInterval / 4
        RunLoop.main.add(timer, forMode: .common)   // keep updating while sliders are dragged
        self.timer = timer
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateContentsScale()
    }

    override func layout() {
        super.layout()
        refresh()
    }

    private func updateContentsScale() {
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        for text in [captionLayer, inputLabel, outputLabel] {
            text.contentsScale = scale
        }
    }

    // MARK: - Updating

    /// Brings the layers up to date with the scene. Cheap when nothing changed: three
    /// comparisons and no Core Animation transaction.
    func refresh() {
        guard let scene else { return }
        let plot = plotRect
        let signature = AudioEnvelopeCurveSignature(scene: scene)
        let curveChanged = signature != appliedSignature || plot != appliedPlot

        var samples: [Double] = []
        if curveChanged {
            samples = AudioEnvelopePreviewMath.samples(of: scene.currentProcessor)
            outputRange = AudioEnvelopePreviewMath.outputRange(for: samples)
        }
        let position = AudioEnvelopePreviewMath.point(
            input: Double(scene.audioSignal),
            output: scene.audioSignalProcessed,
            outputRange: outputRange,
            in: plot
        )
        guard curveChanged || position != appliedMarker else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)   // no implicit animations: they lag and cost
        if curveChanged {
            rebuildCurve(samples: samples, signature: signature, plot: plot)
        }
        marker.position = position
        inputGuide.frame = CGRect(x: position.x - 0.5, y: plot.minY, width: 1, height: position.y - plot.minY)
        outputGuide.frame = CGRect(x: plot.minX, y: position.y - 0.5, width: position.x - plot.minX, height: 1)
        CATransaction.commit()
        appliedMarker = position
    }

    private func rebuildCurve(samples: [Double], signature: AudioEnvelopeCurveSignature, plot: CGRect) {
        curveLayer.path = AudioEnvelopePreviewMath.curvePath(samples: samples, outputRange: outputRange, in: plot)

        // Axes: output up the left side, input along the bottom. When the gain lifts the
        // curve above 1, a tick on the output axis marks where 1 is.
        let axes = CGMutablePath()
        axes.move(to: CGPoint(x: plot.minX, y: plot.maxY))
        axes.addLine(to: CGPoint(x: plot.minX, y: plot.minY))
        axes.addLine(to: CGPoint(x: plot.maxX, y: plot.minY))
        if outputRange > 1 {
            let unity = AudioEnvelopePreviewMath.point(input: 0, output: 1, outputRange: outputRange, in: plot)
            axes.move(to: unity)
            axes.addLine(to: CGPoint(x: unity.x + 6, y: unity.y))
        }
        axesLayer.path = axes

        if signature.caption != (captionLayer.string as? String) {
            captionLayer.string = signature.caption
        }
        if plot != appliedPlot {
            captionLayer.frame = CGRect(x: plot.minX, y: 0, width: plot.width, height: Self.captionHeight)
            outputLabel.frame = CGRect(x: plot.minX + 4, y: plot.maxY - 12, width: 30, height: 11)
            inputLabel.frame = CGRect(x: plot.maxX - 34, y: plot.minY + 2, width: 30, height: 11)
        }

        appliedSignature = signature
        appliedPlot = plot
        curveRevision += 1
    }
}
