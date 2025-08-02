//
//  textToLines.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 02/08/2025.
//

import Foundation
import SwiftUI
import AppKit
import CoreText
import CoreGraphics
import simd

func textToBezierPaths(_ text: String, font: Font, size: CGFloat) -> [[Line]] {
    guard let ctFont = resolveCTFont(from: font, size: size) else { return [] }

    
    
    // Precompute mapping from unicode scalars to their UTF-16 ranges
    struct ScalarUTF16Range {
        let scalarIndex: Int
        let utf16Range: Range<Int>
    }
    func buildScalarUTF16Ranges(from text: String) -> [ScalarUTF16Range] {
        var ranges: [ScalarUTF16Range] = []
        var utf16Cursor = 0
        for (i, scalar) in text.unicodeScalars.enumerated() {
            let utf16Count = String(scalar).utf16.count
            let range = utf16Cursor ..< (utf16Cursor + utf16Count)
            ranges.append(.init(scalarIndex: i, utf16Range: range))
            utf16Cursor += utf16Count
        }
        return ranges
    }
    let scalarRanges = buildScalarUTF16Ranges(from: text)
    
    // Create attributed string so CoreText applies kerning and positioning
    let attributes: [NSAttributedString.Key: Any] = [.font: ctFont]
    let attrString = NSAttributedString(string: text, attributes: attributes)
    let line = CTLineCreateWithAttributedString(attrString)
    let runs = CTLineGetGlyphRuns(line) as? [CTRun] ?? []

    var resultPerCharacter: [[Line]] = Array(repeating: [], count: text.unicodeScalars.count)

    for run in runs {
        let glyphCount = CTRunGetGlyphCount(run)
        if glyphCount == 0 { continue }

        var glyphs = Array<CGGlyph>(repeating: 0, count: glyphCount)
        var positions = Array<CGPoint>(repeating: .zero, count: glyphCount)
        var stringIndices = Array<CFIndex>(repeating: 0, count: glyphCount)

        CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
        CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
        CTRunGetStringIndices(run, CFRange(location: 0, length: 0), &stringIndices)

        for i in 0..<glyphCount {
            let glyph = glyphs[i]
            let position = positions[i]
            let strIndex = stringIndices[i]  // UTF-16 based index

            // Map to scalar index
            guard let mapping = scalarRanges.first(where: { $0.utf16Range.contains(strIndex) }) else {
                continue
            }
            let scalarPos = mapping.scalarIndex
            if scalarPos >= resultPerCharacter.count { continue }

            // Glyph path
            guard let glyphPath = CTFontCreatePathForGlyph(ctFont, glyph, nil) else {
                continue
            }
            var lines = decompose(path: glyphPath)

            // Translation matrix for glyph position
            let tx = Float(position.x)
            let ty = Float(position.y)
            let translation = simd_float4x4(
                SIMD4<Float>(1, 0, 0, 0),
                SIMD4<Float>(0, 1, 0, 0),
                SIMD4<Float>(0, 0, 1, 0),
                SIMD4<Float>(tx, ty, 0, 1)
            )

            for idx in lines.indices {
                lines[idx] = lines[idx].applyMatrix(translation)
            }

            resultPerCharacter[scalarPos].append(contentsOf: lines)
        }
    }

    // Fallback: ensure spaces / missing glyphs don't break layout (no geometry to add)
    // Positioning was applied via CTLine; empty buckets are acceptable for e.g. space.

    return resultPerCharacter
}


private func resolveCTFont(from font: Font, size: CGFloat) -> CTFont? {
    let mirror = Mirror(reflecting: font)
    for child in mirror.children {
        if let label = child.label, label.contains("provider") {
            let innerMirror = Mirror(reflecting: child.value)
            for inner in innerMirror.children {
                if inner.label == "base" {
                    
                }
                if inner.label == "name", let fontName = inner.value as? String {
                    return CTFontCreateWithName(fontName as CFString, size, nil)
                }
            }
        }
    }
    return CTFontCreateWithName("SF Mono Semibold" as CFString, size, nil)
}

private func decompose(path: CGPath) -> [Line] {
    var lines: [Line] = []
    var currentPoint = CGPoint.zero
    var startSubpath = CGPoint.zero
    
    path.applyWithBlock { elementPtr in
        
        let element = elementPtr.pointee
        switch element.type {
        case .moveToPoint:
            currentPoint = element.points[0]
            startSubpath = currentPoint
        case .addLineToPoint:
            let next = element.points[0]
            let line = Line(
                startPoint: pointToSIMD(currentPoint),
                endPoint: pointToSIMD(next)
            )
            lines.append(line)
            currentPoint = next
        case .addQuadCurveToPoint:
            let control = element.points[0]
            let end = element.points[1]
            let line = Line(
                startPoint: pointToSIMD(currentPoint),
                endPoint: pointToSIMD(end),
                degree: 2,
                controlPoints: [pointToSIMD(control)]
            )
            lines.append(line)
            currentPoint = end
        
        case .addCurveToPoint:
            let control1 = element.points[0]
            let control2 = element.points[1]
            let end = element.points[2]
            let line = Line(
                startPoint: pointToSIMD(currentPoint),
                endPoint: pointToSIMD(end),
                degree: 3,
                controlPoints: [
                    pointToSIMD(control1),
                    pointToSIMD(control2)
                ]
            )
            lines.append(line)
            currentPoint = end
        case .closeSubpath:
            if currentPoint != startSubpath {
                let line = Line(
                    startPoint: pointToSIMD(currentPoint),
                    endPoint: pointToSIMD(startSubpath)
                )
                lines.append(line)
            }
            currentPoint = startSubpath
        default:
            break
        }
    }
    return lines
}

private func pointToSIMD(_ p: CGPoint) -> SIMD3<Float> {
    return SIMD3<Float>(Float(p.x), Float(p.y), 0)
}
