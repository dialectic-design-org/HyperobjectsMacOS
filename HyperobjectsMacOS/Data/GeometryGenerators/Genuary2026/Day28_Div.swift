//
//  Day28_Div.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 27/01/2026.
//

import Foundation
import simd

struct CSSBoxModel: Identifiable {
    var id: UUID = UUID()
    var top: Double = 0.0
    var right: Double = 0.0
    var bottom: Double = 0.0
    var left: Double = 0.0
}

struct CSSBox {
    var padding: CSSBoxModel
    var margin: CSSBoxModel
}

struct Day28_Div: GenuaryDayGenerator {
    let dayNumber = "28"
    let sinePower: Double = 0.1

    private func powerSin(_ angle: Double) -> Double {
        let s = sin(angle)
        return copysign(pow(abs(s), sinePower), s)
    }

    private func powerCos(_ angle: Double) -> Double {
        return powerSin(angle + .pi / 2)
    }

    private func createArrow(tip: SIMD3<Float>, direction: SIMD3<Float>, size: Float = 0.05, lineWidth: Float = 0.5) -> [Line] {
        var lines: [Line] = []
        // Orthogonal vector for arrow wings
        // Assume direction is mostly axis aligned, take arbitrary cross
        let up = (abs(direction.z) < 0.9) ? SIMD3<Float>(0, 0, 1) : SIMD3<Float>(1, 0, 0)
        let right = normalize(cross(direction, up))
        
        // Wing 1
        let back = tip - direction * size
        let w1 = back + right * (size * 0.5)
        var l1 = Line(startPoint: tip, endPoint: w1)
        l1.lineWidthStart = lineWidth; l1.lineWidthEnd = lineWidth
        lines.append(l1)
        
        // Wing 2
        let w2 = back - right * (size * 0.5)
        var l2 = Line(startPoint: tip, endPoint: w2)
        l2.lineWidthStart = lineWidth; l2.lineWidthEnd = lineWidth
        lines.append(l2)
        
        return lines
    }

    private func createDimension(from start: SIMD3<Float>, to end: SIMD3<Float>, offset: SIMD3<Float>, color: SIMD4<Float> = SIMD4<Float>(1,1,1,1), traceToZ: Float? = nil, lineWidth: Float = 0.5, arrowSize: Float = 0.05, gap: Float = 0.0) -> [Line] {
        var lines: [Line] = []
        let overshoot = normalize(offset) * 0.05
        
        // Extend inwards as well ("into the cube") so it visually meets the object body
        let extStart1 = start - overshoot
        let extStart2 = end - overshoot
        
        let p1 = start + offset
        let p2 = end + offset
        
        // 1. Extension Lines
        var ext1 = Line(startPoint: extStart1, endPoint: p1 + overshoot)
        ext1.lineWidthStart = lineWidth; ext1.lineWidthEnd = lineWidth
        ext1.colorStart = color; ext1.colorEnd = color
        lines.append(ext1)
        
        var ext2 = Line(startPoint: extStart2, endPoint: p2 + overshoot)
        ext2.lineWidthStart = lineWidth; ext2.lineWidthEnd = lineWidth
        ext2.colorStart = color; ext2.colorEnd = color
        lines.append(ext2)
        
        // 1b. Z-Trace (Projection)
        if let zVal = traceToZ {
             // Trace from the anchor point (start) to the target Z
             var trace = Line(startPoint: start, endPoint: SIMD3<Float>(start.x, start.y, zVal))
             trace.lineWidthStart = lineWidth; trace.lineWidthEnd = lineWidth
             trace.colorStart = color; trace.colorEnd = color
             lines.append(trace)
             
             // Also trace the "start" extension line at the zVal depth?
             // The user mentioned "extend even more into the cube until they meet the other cube"
             // Maybe ensuring the extension line exists at the zVal level too:
             // Let's add a small 'corner' mark at the zVal layer to be sure.
             var traceExt = Line(startPoint: SIMD3<Float>(extStart1.x, extStart1.y, zVal),
                                 endPoint: SIMD3<Float>(start.x, start.y, zVal))
             traceExt.lineWidthStart = lineWidth; traceExt.lineWidthEnd = lineWidth
             traceExt.colorStart = color; traceExt.colorEnd = color
             lines.append(traceExt)
        }
        
        // 2. Main Line & Arrows
        if distance(p1, p2) > 0.001 {
            let dir = normalize(p2 - p1)
            let tip1 = p1 + dir * gap
            let tip2 = p2 - dir * gap
            
            // Main Line covers the distance between the arrow tips
             var main = Line(startPoint: tip1, endPoint: tip2)
            main.lineWidthStart = lineWidth; main.lineWidthEnd = lineWidth
            main.colorStart = color; main.colorEnd = color
            lines.append(main)
            
            // 3. Arrows
            // Tip is offset by gap. Direction is outwards (p1-p2 or p2-p1) so arrow head points to extension line.
            var a1 = createArrow(tip: tip1, direction: normalize(p1 - p2), size: arrowSize, lineWidth: lineWidth)
            applyStyle(&a1, color: color, width: lineWidth)
            lines.append(contentsOf: a1)
            
            var a2 = createArrow(tip: tip2, direction: normalize(p2 - p1), size: arrowSize, lineWidth: lineWidth)
            applyStyle(&a2, color: color, width: lineWidth)
            lines.append(contentsOf: a2)
        }
        
        return lines
    }

    func generateLines(
        inputs: [String: Any],
        scene: GeometriesSceneBase,
        time: Double,
        lineWidthBase: Float,
        state: Genuary2026State
    ) -> (lines: [Line], replacementProbability: Float) {
        var outputLines: [Line] = []
        
        // Allow values to go negative as requested
        var box = CSSBox(
            padding: CSSBoxModel(
                top: 0.5 * powerSin(time * 0.19) + 0.25 * powerSin(time * 0.53),
                right: 0.5 * powerCos(time * 0.31) + 0.25 * powerCos(time * 0.71),
                bottom: 0.5 * powerSin(time * 0.23) + 0.25 * powerSin(time * 0.61),
                left: 0.5 * powerCos(time * 0.17) + 0.25 * powerCos(time * 0.47)
            ),
            margin: CSSBoxModel(
                top: 0.5 * powerCos(time * 0.11) + 0.25 * powerCos(time * 0.29),
                right: 0.5 * powerSin(time * 0.073) + 0.25 * powerSin(time * 0.191),
                bottom: 0.5 * powerCos(time * 0.101) + 0.25 * powerCos(time * 0.271),
                left: 0.5 * powerSin(time * 0.137) + 0.25 * powerSin(time * 0.373)
            )
        )
        
        // 1. Source (Content) Box
        // Flattened z to 5% of initial size (1.0) -> 0.05
        let thickness: Float = 0.2
        let contentSize = SIMD3<Float>(1.0, 1.0, thickness)
        
        let guideLW = lineWidthBase * 0.4
        let arrowSz: Float = 0.02
        let arrowGap: Float = 0.01

        // Case A: Just Content
        let posA = SIMD3<Float>(0, 0, 0)
        let cubeA = Cube(center: posA, size: 1.0, axisScale: contentSize)
        var linesA = cubeA.wallOutlines()
        applyStyle(&linesA, color: SIMD4<Float>(0.4, 0.4, 0.4, 1.0), width: lineWidthBase)
        outputLines.append(contentsOf: linesA)
        
        
        // Case B: Content + Padding
        let pTop = Float(box.padding.top)
        let pRight = Float(box.padding.right)
        let pBottom = Float(box.padding.bottom)
        let pLeft = Float(box.padding.left)
        
        let widthB = contentSize.x + pLeft + pRight
        let heightB = contentSize.y + pTop + pBottom
        let depthB = thickness
        
        let centerXB = (pRight - pLeft) / 2.0
        let centerYB = (pTop - pBottom) / 2.0
        
        let posB = SIMD3<Float>(centerXB, centerYB, posA.z + thickness)
        let cubeB = Cube(center: posB, size: 1.0, axisScale: SIMD3<Float>(widthB, heightB, depthB))
        var linesB = cubeB.wallOutlines()
        applyStyle(&linesB, color: SIMD4<Float>(0.5, 0.5, 0.5, 1.0), width: lineWidthBase)
        outputLines.append(contentsOf: linesB)
        
        
        // Case C: Content + Margin (No Padding)
        let mTop = Float(box.margin.top)
        let mRight = Float(box.margin.right)
        let mBottom = Float(box.margin.bottom)
        let mLeft = Float(box.margin.left)
        
        let widthC = contentSize.x + mLeft + mRight
        let heightC = contentSize.y + mTop + mBottom
        let depthC = thickness
        
        let centerXC = (mRight - mLeft) / 2.0
        let centerYC = (mTop - mBottom) / 2.0
        
        let posC = SIMD3<Float>(centerXC, centerYC, posB.z + thickness)
        let cubeC = Cube(center: posC, size: 1.0, axisScale: SIMD3<Float>(widthC, heightC, depthC))
        var linesC = cubeC.wallOutlines()
        applyStyle(&linesC, color: SIMD4<Float>(0.6, 0.6, 0.6, 1.0), width: lineWidthBase)
        outputLines.append(contentsOf: linesC)
        
        
        // Case D: Content + Padding + Margin
        let widthD = widthB + mLeft + mRight
        let heightD = heightB + mTop + mBottom
        let depthD = thickness
        
        let centerXD = (pRight + mRight - (pLeft + mLeft)) / 2.0
        let centerYD = (pTop + mTop - (pBottom + mBottom)) / 2.0
        
        let posD = SIMD3<Float>(centerXD, centerYD, posC.z + thickness)
        let cubeD = Cube(center: posD, size: 1.0, axisScale: SIMD3<Float>(widthD, heightD, depthD))
        var linesD = cubeD.wallOutlines()
        applyStyle(&linesD, color: SIMD4<Float>(1.0, 1.0, 1.0, 1.0), width: lineWidthBase * 2.5) // Bright white
        outputLines.append(contentsOf: linesD)
        
        // --- Technical Guide Lines ---
        let dimColor = SIMD4<Float>(0.8, 0.8, 0.8, 1.0)
        let baseOff: Float = 0.2
        
        let zA = posA.z
        
        // Cube B: Padding Dimensions
        // We need dynamic offsets so lines clear the growing box.
        // For vertical dims (Top/Bottom) placed on Right, we need to clear pRight.
        // For horizontal dims (Left/Right) placed on Top, we need to clear pTop.
        
        let offX_B = SIMD3<Float>(baseOff + Float(max(0, box.padding.right)), 0, 0)
        let offY_B = SIMD3<Float>(0, baseOff + Float(max(0, box.padding.top)), 0)
        let offNX_B = SIMD3<Float>(-(baseOff + Float(max(0, box.padding.left))), 0, 0)
        let offNY_B = SIMD3<Float>(0, -(baseOff + Float(max(0, box.padding.bottom))), 0)
        
        let zB = posB.z
        if abs(pTop) > 0.001 {
            // Anchor at Top-Right (0.5, 0.5)
            outputLines.append(contentsOf: createDimension(from: SIMD3<Float>(0.5, 0.5, zB), to: SIMD3<Float>(0.5, 0.5 + pTop, zB), offset: offX_B, color: dimColor, traceToZ: zA, lineWidth: guideLW, arrowSize: arrowSz, gap: arrowGap))
        }
        if abs(pRight) > 0.001 {
            // Anchor at Top-Right (0.5, 0.5)
            outputLines.append(contentsOf: createDimension(from: SIMD3<Float>(0.5, 0.5, zB), to: SIMD3<Float>(0.5 + pRight, 0.5, zB), offset: offY_B, color: dimColor, traceToZ: zA, lineWidth: guideLW, arrowSize: arrowSz, gap: arrowGap))
        }
        if abs(pBottom) > 0.001 {
            // Anchor at Bottom-Right (0.5, -0.5) - Place on Right side -> use offX_B
            outputLines.append(contentsOf: createDimension(from: SIMD3<Float>(0.5, -0.5, zB), to: SIMD3<Float>(0.5, -0.5 - pBottom, zB), offset: offX_B, color: dimColor, traceToZ: zA, lineWidth: guideLW, arrowSize: arrowSz, gap: arrowGap))
        }
        if abs(pLeft) > 0.001 {
            // Anchor at Top-Left (-0.5, 0.5) - Place on Top side -> use offY_B
            outputLines.append(contentsOf: createDimension(from: SIMD3<Float>(-0.5, 0.5, zB), to: SIMD3<Float>(-0.5 - pLeft, 0.5, zB), offset: offY_B, color: dimColor, traceToZ: zA, lineWidth: guideLW, arrowSize: arrowSz, gap: arrowGap))
        }

        // Cube C: Margin Dimensions (Relative to Content)
        // Similar dynamic offsets but using Margin values implies clearing the margin area?
        // Note: The visualization usually stacks these. Cube C is "Margin only",
        // implying it sits around Content similar to Padding.
        
        let offX_C = SIMD3<Float>(baseOff + Float(max(0, box.margin.right)), 0, 0)
        let offY_C = SIMD3<Float>(0, baseOff + Float(max(0, box.margin.top)), 0)
        let offNX_C = SIMD3<Float>(-(baseOff + Float(max(0, box.margin.left))), 0, 0)
        let offNY_C = SIMD3<Float>(0, -(baseOff + Float(max(0, box.margin.bottom))), 0)

        let zC = posC.z
        if abs(mTop) > 0.001 {
            // Anchor at Top-Left (-0.5, 0.5) - Place on LEFT side? Original used offNX (Left).
            // Original: Anchor Top-Left (-0.5, 0.5) -> offset offNX (Left).
            // Measures vertical mTop segment?
            // createDimension(from: (-0.5, 0.5), to: (-0.5, 0.5 + mTop)) is vertical.
            // Placed at Left (-0.5 - off).
            // Needs to clear mLeft.
            outputLines.append(contentsOf: createDimension(from: SIMD3<Float>(-0.5, 0.5, zC), to: SIMD3<Float>(-0.5, 0.5 + mTop, zC), offset: offNX_C, color: dimColor, traceToZ: zA, lineWidth: guideLW, arrowSize: arrowSz, gap: arrowGap))
        }
        if abs(mRight) > 0.001 {
            // Anchor at Bottom-Right (0.5, -0.5) -> offset offNY (Bottom).
            // Measures Horizontal mRight segment?
            // createDimension(from: (0.5, -0.5), to: (0.5 + mRight, -0.5)) is horizontal.
            // Placed at Bottom (-0.5 - off).
            // Needs to clear mBottom.
            outputLines.append(contentsOf: createDimension(from: SIMD3<Float>(0.5, -0.5, zC), to: SIMD3<Float>(0.5 + mRight, -0.5, zC), offset: offNY_C, color: dimColor, traceToZ: zA, lineWidth: guideLW, arrowSize: arrowSz, gap: arrowGap))
        }
        if abs(mBottom) > 0.001 {
            // Anchor at Bottom-Left (-0.5, -0.5) -> offset offNX (Left).
            // Measures Vertical mBottom.
            // Needs to clear mLeft.
            outputLines.append(contentsOf: createDimension(from: SIMD3<Float>(-0.5, -0.5, zC), to: SIMD3<Float>(-0.5, -0.5 - mBottom, zC), offset: offNX_C, color: dimColor, traceToZ: zA, lineWidth: guideLW, arrowSize: arrowSz, gap: arrowGap))
        }
        if abs(mLeft) > 0.001 {
            // Anchor at Bottom-Left (-0.5, -0.5) -> offset offNY (Bottom).
            // Measures Horizontal mLeft.
            // Needs to clear mBottom.
            outputLines.append(contentsOf: createDimension(from: SIMD3<Float>(-0.5, -0.5, zC), to: SIMD3<Float>(-0.5 - mLeft, -0.5, zC), offset: offNY_C, color: dimColor, traceToZ: zA, lineWidth: guideLW, arrowSize: arrowSz, gap: arrowGap))
        }

        // Cube D: Margin Dimensions (Relative to Padding)
        let zD = posD.z
        // Padding boundaries
        let pbTop = 0.5 + pTop
        let pbRight = 0.5 + pRight
        let pbBottom = 0.5 + pBottom
        let pbLeft = 0.5 + pLeft
        
        // For Cube D, lines are placed relative to the padded box.
        // To clear the margin area which is added ON TOP of padding:
        // Top/Bottom lines (on Right side) need to clear (pRight + mRight).
        // Since we anchor at pbRight (0.5 + pRight), the additional clearance needed is mRight.
        
        let offX_D = SIMD3<Float>(baseOff + Float(max(0, box.margin.right)), 0, 0)
        let offY_D = SIMD3<Float>(0, baseOff + Float(max(0, box.margin.top)), 0)
        
        if abs(mTop) > 0.001 {
            // Placed on Right (offX). Needs to clear mRight.
            outputLines.append(contentsOf: createDimension(from: SIMD3<Float>(pbRight, pbTop, zD), to: SIMD3<Float>(pbRight, pbTop + mTop, zD), offset: offX_D, color: dimColor, traceToZ: zB))
        }
        if abs(mRight) > 0.001 {
            // Placed on Top (offY). Needs to clear mTop.
            outputLines.append(contentsOf: createDimension(from: SIMD3<Float>(pbRight, pbTop, zD), to: SIMD3<Float>(pbRight + mRight, pbTop, zD), offset: offY_D, color: dimColor, traceToZ: zB))
        }
        if abs(mBottom) > 0.001 {
            let yBottom = -(0.5 + pBottom)
            // Placed on Right (offX). Needs to clear mRight.
            outputLines.append(contentsOf: createDimension(from: SIMD3<Float>(pbRight, yBottom, zD), to: SIMD3<Float>(pbRight, yBottom - mBottom, zD), offset: offX_D, color: dimColor, traceToZ: zB))
        }
        if abs(mLeft) > 0.001 {
            let xLeft = -(0.5 + pLeft)
            // Placed on Top (offY). Needs to clear mTop.
            outputLines.append(contentsOf: createDimension(from: SIMD3<Float>(xLeft, pbTop, zD), to: SIMD3<Float>(xLeft - mLeft, pbTop, zD), offset: offY_D, color: dimColor, traceToZ: zB))
        }
        
        var finalScaling = matrix_scale(scale: SIMD3<Float>(repeating: 0.4))
        
        var finalRotateY = matrix_rotation(
            angle: Float(powerSin(time * 0.3) * 0.3) + Float(powerSin(time * 0.5132) * 0.3)  + Float(powerSin(time * 0.1132)) * Float.pi
            , axis: SIMD3<Float>(0.0, 1.0, 0.0))
        var finalRotateX = matrix_rotation(
            angle: Float(powerSin(time * 0.12373) * 0.1) + Float(powerSin(time * 0.296754) * 0.2) + Float(powerSin(time * 0.198796754)) * Float.pi
            , axis: SIMD3<Float>(1.0, 0.0, 0.0))
        
        
        var finalMat = finalScaling * finalRotateY * finalRotateX
        
        
        for i in outputLines.indices {
            outputLines[i] = outputLines[i].applyMatrix(finalMat)
        }

        
        return (outputLines, 0.0) // default replacement probability
    }
    
    private func applyStyle(_ lines: inout [Line], color: SIMD4<Float>, width: Float) {
        for i in 0..<lines.count {
            lines[i].colorStart = color
            lines[i].colorEnd = color
            lines[i].lineWidthStart = width
            lines[i].lineWidthEnd = width
        }
    }
}
