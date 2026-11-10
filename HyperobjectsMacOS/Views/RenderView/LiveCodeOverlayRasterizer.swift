//
//  LiveCodeOverlayRasterizer.swift
//  HyperobjectsMacOS
//
//  Lays out and draws the live-code overlay into a BGRA texture off the render thread, for
//  the burned-in output mode (so the code also appears in the Syphon feed).
//
//  Threading: TextKit objects are confined to `queue`; the render thread only reads/swaps the
//  finished texture under `lock`. A new texture is created per build, so a texture the GPU
//  may still be reading is never mutated.
//

import AppKit
import Metal

final class LiveCodeOverlayRasterizer {
    private struct Key: Equatable {
        var version: UInt64
        var width: Int
        var height: Int
    }

    private let device: MTLDevice
    private let queue = DispatchQueue(label: "LiveCodeOverlayRasterizer", qos: .userInitiated)
    private let lock = NSLock()
    private var readyTexture: MTLTexture?
    private var renderedKey: Key?
    private var inFlight = false

    // queue-confined TextKit 1 stack (same layout engine as the editor's NSTextView)
    private let textStorage = NSTextStorage()
    private let layoutManager = NSLayoutManager()
    private let textContainer = NSTextContainer()

    init(device: MTLDevice) {
        self.device = device
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
    }

    /// Render thread. Cheap: returns the newest finished texture (nil if there is nothing to
    /// draw) and schedules a rebuild when the snapshot or drawable size changed.
    func texture(for state: LiveCodeOverlayState, width: Int, height: Int) -> MTLTexture? {
        guard let snapshot = state.current() else { return nil }
        let key = Key(version: snapshot.version, width: width, height: height)
        lock.lock()
        let needsBuild = key != renderedKey && !inFlight
        if needsBuild { inFlight = true }
        let current = readyTexture
        lock.unlock()
        if needsBuild {
            queue.async { [weak self] in self?.build(snapshot, key: key) }
        }
        return current
    }

    // MARK: - Build (queue)

    private func build(_ s: LiveCodeOverlaySnapshot, key: Key) {
        defer {
            lock.lock(); inFlight = false; lock.unlock()
        }
        let w = key.width, h = key.height
        guard w > 0, h > 0, s.viewSize.width > 0, s.viewSize.height > 0,
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        else { return }

        // Map editor points (top-left origin) to drawable pixels. Non-uniform if the aspect
        // ratios differ (e.g. a fixed render resolution in a non-square window).
        let sx = CGFloat(w) / s.viewSize.width
        let sy = CGFloat(h) / s.viewSize.height
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: sx, y: -sy)

        let nsContext = NSGraphicsContext(cgContext: ctx, flipped: true)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsContext

        draw(s, in: ctx)

        NSGraphicsContext.restoreGraphicsState()

        guard let data = ctx.data else { return }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
        descriptor.usage = .shaderRead
        descriptor.storageMode = device.hasUnifiedMemory ? .shared : .managed
        guard let texture = device.makeTexture(descriptor: descriptor) else { return }
        texture.replace(region: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0, withBytes: data, bytesPerRow: ctx.bytesPerRow)

        lock.lock()
        readyTexture = texture
        renderedKey = key
        lock.unlock()
    }

    private func draw(_ s: LiveCodeOverlaySnapshot, in ctx: CGContext) {
        let backdrop = NSColor.black.withAlphaComponent(s.backdropOpacity)
        let infoFontSize = max(9, s.fontSize * 0.6)

        textStorage.setAttributedString(s.attributedText)
        textContainer.lineFragmentPadding = s.lineFragmentPadding
        textContainer.size = CGSize(width: max(s.containerWidth, 1), height: .greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: textContainer)

        let origin = CGPoint(x: s.textRect.minX + s.textInset.width,
                             y: s.textRect.minY + s.textInset.height - s.scrollOffsetY)

        // Line-number gutter, left of the text area.
        if s.gutterWidth > 0 {
            let gutter = CGRect(x: s.textRect.minX - s.gutterWidth, y: s.textRect.minY,
                                width: s.gutterWidth, height: s.textRect.height)
            drawGutter(in: gutter, origin: origin, errorLine: s.errorLine, fontSize: s.fontSize * 0.75,
                       textOpacity: CGFloat(s.textOpacity), backdrop: backdrop, ctx: ctx)
        }

        // Panels around the text area; the SwiftUI placeholders reserve exactly this space.
        let panelX = s.textRect.minX - s.gutterWidth
        let panelWidth = s.textRect.width + s.gutterWidth
        if !s.inputReadout.isEmpty {
            let height = LiveCodePanelMetrics.height(lineCount: s.inputReadout.count, fontSize: infoFontSize)
            let rect = CGRect(x: panelX, y: s.textRect.minY - LiveCodePanelMetrics.spacing - height, width: panelWidth, height: height)
            let lines = s.inputReadout.map { row -> NSAttributedString in
                let line = NSMutableAttributedString(string: row.key + "  ", attributes: infoAttributes(infoFontSize, NSColor(white: 0.6, alpha: 1)))
                line.append(NSAttributedString(string: row.value, attributes: infoAttributes(infoFontSize, .white)))
                return line
            }
            drawPanel(lines, in: rect, fontSize: infoFontSize, background: backdrop)
        }

        var bottomLines: [NSAttributedString] = []
        if let message = s.errorMessage {
            let text = s.errorLine.map { "line \($0): \(message)" } ?? message
            bottomLines.append(NSAttributedString(string: "⚠ " + text, attributes: infoAttributes(infoFontSize, .white)))
        }
        bottomLines += s.consoleTail.map { NSAttributedString(string: "› " + $0, attributes: infoAttributes(infoFontSize, NSColor(white: 0.85, alpha: 1))) }
        if !bottomLines.isEmpty {
            let height = LiveCodePanelMetrics.height(lineCount: bottomLines.count, fontSize: infoFontSize)
            let rect = CGRect(x: panelX, y: s.textRect.maxY + LiveCodePanelMetrics.spacing, width: panelWidth, height: height)
            drawPanel(bottomLines, in: rect, fontSize: infoFontSize, background: backdrop,
                      firstLineBackground: s.errorMessage != nil ? NSColor.systemRed.withAlphaComponent(0.75) : nil)
        }

        // The code itself, clipped to the visible text area.
        ctx.saveGState()
        ctx.clip(to: s.textRect)
        let glyphs = layoutManager.glyphRange(for: textContainer)

        // 1. per-line backdrops (.backgroundColor attributes)
        layoutManager.drawBackground(forGlyphRange: glyphs, at: origin)

        // 2. error line highlight
        if let line = s.errorLine, let rect = lineRect(line) {
            NSColor.systemRed.withAlphaComponent(0.35).setFill()
            rect.offsetBy(dx: origin.x, dy: origin.y).fill(using: .sourceOver)
        }

        // 3. glyphs
        layoutManager.drawGlyphs(forGlyphRange: glyphs, at: origin)

        // 4. selection / caret
        if let caret = s.caretRange {
            if caret.length > 0 {
                NSColor.systemBlue.withAlphaComponent(0.45).setFill()
                let clamped = NSIntersectionRange(caret, NSRange(location: 0, length: textStorage.length))
                let glyphRange = layoutManager.glyphRange(forCharacterRange: clamped, actualCharacterRange: nil)
                layoutManager.enumerateEnclosingRects(forGlyphRange: glyphRange,
                                                      withinSelectedGlyphRange: glyphRange,
                                                      in: textContainer) { rect, _ in
                    rect.offsetBy(dx: origin.x, dy: origin.y).fill(using: .sourceOver)
                }
            } else {
                NSColor.white.setFill()
                caretRect(at: caret.location).offsetBy(dx: origin.x, dy: origin.y).fill()
            }
        }

        // 5. evaluation flash: tint only what has been drawn (source-atop)
        if let tint = s.flashTint {
            tint.setFill()
            s.textRect.fill(using: .sourceAtop)
        }
        ctx.restoreGState()
    }

    // MARK: - Helpers (queue)

    private func infoAttributes(_ size: CGFloat, _ color: NSColor) -> [NSAttributedString.Key: Any] {
        [.font: LiveCodePanelMetrics.font(size: size), .foregroundColor: color]
    }

    private func drawPanel(_ lines: [NSAttributedString], in rect: CGRect, fontSize: CGFloat,
                           background: NSColor, firstLineBackground: NSColor? = nil) {
        background.setFill()
        rect.fill(using: .sourceOver)
        let lineHeight = LiveCodePanelMetrics.lineHeight(fontSize: fontSize)
        let padding = LiveCodePanelMetrics.padding
        for (index, line) in lines.enumerated() {
            let lineRect = CGRect(x: rect.minX + padding,
                                  y: rect.minY + padding + CGFloat(index) * lineHeight,
                                  width: rect.width - 2 * padding,
                                  height: lineHeight)
            if index == 0, let firstLineBackground {
                firstLineBackground.setFill()
                lineRect.insetBy(dx: -padding, dy: 0).fill(using: .sourceOver)
            }
            line.draw(with: lineRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
        }
    }

    private func drawGutter(in gutter: CGRect, origin: CGPoint, errorLine: Int?, fontSize: CGFloat,
                            textOpacity: CGFloat, backdrop: NSColor, ctx: CGContext) {
        ctx.saveGState()
        ctx.clip(to: gutter)
        backdrop.setFill()
        gutter.fill(using: .sourceOver)

        let font = LiveCodePanelMetrics.font(size: fontSize)
        let ns = textStorage.string as NSString

        func drawLabel(_ number: Int, fragment: CGRect) {
            let y = origin.y + fragment.minY
            guard y + fragment.height >= gutter.minY, y <= gutter.maxY else { return }
            let color = number == errorLine ? NSColor.systemRed.withAlphaComponent(textOpacity)
                                            : NSColor(white: 0.65, alpha: textOpacity)
            let label = NSAttributedString(string: "\(number)", attributes: [.font: font, .foregroundColor: color])
            let size = label.size()
            label.draw(at: CGPoint(x: gutter.maxX - size.width - 8, y: y + (fragment.height - size.height) / 2))
        }

        if ns.length == 0 {
            drawLabel(1, fragment: layoutManager.extraLineFragmentRect)
        } else {
            var line = 1
            var index = 0
            while index < ns.length {
                let lineRange = ns.lineRange(for: NSRange(location: index, length: 0))
                let glyph = layoutManager.glyphIndexForCharacter(at: lineRange.location)
                drawLabel(line, fragment: layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil))
                line += 1
                index = NSMaxRange(lineRange)
            }
            if ns.character(at: ns.length - 1) == 10, !layoutManager.extraLineFragmentRect.isEmpty {
                drawLabel(line, fragment: layoutManager.extraLineFragmentRect)
            }
        }
        ctx.restoreGState()
    }

    private func caretRect(at location: Int) -> CGRect {
        let length = textStorage.length
        if length == 0 || (location >= length && !layoutManager.extraLineFragmentRect.isEmpty) {
            var rect = layoutManager.extraLineFragmentRect
            rect.origin.x += textContainer.lineFragmentPadding
            rect.size.width = 2
            return rect
        }
        let charIndex = min(location, length - 1)
        let glyph = layoutManager.glyphIndexForCharacter(at: charIndex)
        var rect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: textContainer)
        if location >= length { rect.origin.x = rect.maxX }
        // Use the full line height so the caret matches NSTextView's insertion point.
        let fragment = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        rect.origin.y = fragment.minY
        rect.size.height = fragment.height
        rect.size.width = 2
        return rect
    }

    private func lineRect(_ line: Int) -> CGRect? {
        guard let range = LiveCodeEditorView.Coordinator.characterRange(ofLine: line, in: textStorage.string) else { return nil }
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        rect.origin.x = 0
        rect.size.width = textContainer.size.width
        return rect
    }
}
