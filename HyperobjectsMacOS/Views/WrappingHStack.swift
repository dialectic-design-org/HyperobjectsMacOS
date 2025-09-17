//
//  WrappingHStack.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 10/09/2025.
//
import SwiftUI

struct WrappingHStack: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func makeLines(_ sizes: [CGSize], maxWidth: CGFloat) -> [[Int]] {
        var lines: [[Int]] = []
        var current: [Int] = []
        var lineWidth: CGFloat = 0

        for (i, sz) in sizes.enumerated() {
            let add = current.isEmpty ? sz.width : (lineWidth + spacing + sz.width)
            if add > maxWidth, !current.isEmpty {
                lines.append(current)
                current = [i]
                lineWidth = sz.width
            } else {
                current.append(i)
                lineWidth = current.count == 1 ? sz.width : (lineWidth + spacing + sz.width)
            }
        }
        if !current.isEmpty { lines.append(current) }
        return lines
    }

    func sizeThatFits(proposal: ProposedViewSize,
                      subviews: Subviews,
                      cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        // Measure once, reuse everywhere
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let lines = makeLines(sizes, maxWidth: maxWidth)

        var height: CGFloat = 0
        for (li, line) in lines.enumerated() {
            let lineHeight = line.map { sizes[$0].height }.max() ?? 0
            height += lineHeight
            if li < lines.count - 1 { height += lineSpacing }
        }
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect,
                       proposal: ProposedViewSize,
                       subviews: Subviews,
                       cache: inout ()) {
        let maxWidth = bounds.width
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let lines = makeLines(sizes, maxWidth: maxWidth)

        var y: CGFloat = bounds.minY
        for (li, line) in lines.enumerated() {
            let lineHeight = line.map { sizes[$0].height }.max() ?? 0
            var x: CGFloat = bounds.minX
            for idx in line {
                let sz = sizes[idx]
                // Propose the exact measured size to avoid reflow differences
                subviews[idx].place(
                    at: CGPoint(x: x.rounded(.toNearestOrAwayFromZero),
                                y: y.rounded(.toNearestOrAwayFromZero)),
                    proposal: ProposedViewSize(sz)
                )
                x += sz.width + spacing
            }
            y += lineHeight
            if li < lines.count - 1 { y += lineSpacing }
        }
    }
}
