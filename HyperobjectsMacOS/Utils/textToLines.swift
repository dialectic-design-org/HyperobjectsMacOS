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

func textToBezierPaths(_ text: String, font: Font, fontName: String = "", size: CGFloat, maxLineWidth: CGFloat) -> [[Line]] {
    guard let ctFont = resolveCTFont(from: font, fontName: fontName, size: size) else { return [] }

    // Helper: split into words but keep trailing spaces so spacing is preserved
    let wordsWithSpaces: [String] = {
        var words: [String] = []
        var current = ""
        for char in text {
            current.append(char)
            if char.isWhitespace {
                words.append(current)
                current = ""
            } else if current.last?.isWhitespace == false,
                      let next = current.last,
                      next == " " {
                // unlikely, just in case
                words.append(current)
                current = ""
            }
        }
        if !current.isEmpty { words.append(current) }
        return words
    }()

    // Font metrics for line height (ascent + descent + leading)
    let ascent = CTFontGetAscent(ctFont)
    let descent = CTFontGetDescent(ctFont)
    let leading = CTFontGetLeading(ctFont)
    let lineHeight = ascent + descent + leading

    // Precompute scalar UTF16 ranges for full text (used for mapping later)
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

    // Prepare result per scalar
    var resultPerCharacter: [[Line]] = Array(repeating: [], count: text.unicodeScalars.count)

    var cursorX: CGFloat = 0
    var cursorY: CGFloat = 0 // start baseline at y=0; subsequent lines go downward (negative)

    // We'll need to track the global scalar offset as we consume words
    var consumedScalars = text.unicodeScalars.makeIterator()
    var scalarIndexOrder: [String.UnicodeScalarView.Index] = Array(text.unicodeScalars.indices) // for mapping, not strictly needed here

    // Process each word (which may include whitespace)
    var processedPrefix = "" // to track how many scalars consumed for string indices
    for word in wordsWithSpaces {
        // Create attributed string for the word
        let attrString = NSAttributedString(string: word, attributes: [.font: ctFont])
        let lineRef = CTLineCreateWithAttributedString(attrString)
        let wordWidth = CGFloat(CTLineGetTypographicBounds(lineRef, nil, nil, nil))

        // Wrap if needed (if non-empty and would exceed)
        if cursorX > 0 && cursorX + wordWidth > maxLineWidth {
            cursorX = 0
            cursorY -= lineHeight
        }

        // Get glyph runs for this word
        let runs = CTLineGetGlyphRuns(lineRef) as? [CTRun] ?? []

        // We need to know the base UTF-16 index offset of this word within the full text
        // Compute prefix length in UTF16
        let prefixUTF16Count = processedPrefix.utf16.count

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
                let strIndexInWord = stringIndices[i] // UTF-16 index within word
                let globalUTF16Index = prefixUTF16Count + strIndexInWord

                // Map to scalar index in full text
                guard let mapping = scalarRanges.first(where: { $0.utf16Range.contains(globalUTF16Index) }) else {
                    continue
                }
                let scalarPos = mapping.scalarIndex
                if scalarPos >= resultPerCharacter.count { continue }

                // Path for glyph
                guard let glyphPath = CTFontCreatePathForGlyph(ctFont, glyph, nil) else { continue }
                var lines = decompose(path: glyphPath)

                // Compute translation: glyph position + current line offset
                let tx = Float(position.x + cursorX)
                let ty = Float(position.y + cursorY)
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

        // Advance cursor by word width
        cursorX += wordWidth
        processedPrefix += word
    }

    return resultPerCharacter
}


private func resolveCTFont(from font: Font, fontName: String, size: CGFloat) -> CTFont? {
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
    
    var catchingFontName = "SF Mono Heavy"
    
    if fontName != "" {
        catchingFontName = fontName
    }
    
    return CTFontCreateWithName(catchingFontName as CFString, size, nil)
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


// The purpose of this function is to find a certain number of cubes that will approximate the given lines with a certain accuracy.
func linesToCubes(lines: [Line], accuracy: Float) -> [Cube] {
    var cubes: [Cube] = []
    
    for line in lines {
        let segments = line.subdivide(accuracy: accuracy)
        for segment in segments {
            let midPoint = (segment.startPoint + segment.endPoint) / 2
            let length = simd_length(segment.endPoint - segment.startPoint)
            let direction = simd_normalize(segment.endPoint - segment.startPoint)
            
            // Create a cube centered at midPoint with size based on length
            let cubeSize = length * 0.1 // scale down for visual purposes
            let cube = Cube(center: midPoint, size: cubeSize, orientation: direction)
            cubes.append(cube)
        }
    }
    
    return cubes
}
