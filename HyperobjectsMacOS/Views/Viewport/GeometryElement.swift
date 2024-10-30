//
//  GeometryElement.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 15/10/2024.
//

import SwiftUI


struct GeometryElement: View {
    var gWrapped: GeometryWrapped
    var direction: String
    var scale: CGFloat
    
    var body: some View {
        let g = gWrapped.geometry
        VStack {
            GeometryReader { proxy in
                self.geometryContent(g: g, proxy: proxy)
            }
        }
    }

    @ViewBuilder
    private func geometryContent(g: any Geometry, proxy: GeometryProxy) -> some View {
        switch g.type {
        case .line:
            let points = g.getPoints()
            VStack {  // Changed Group to VStack for more reliable rendering
                if points.count == 2 {
                    Path { path in
                        path.move(to: toCGPoint(inVec: points[0], direction: direction))
                        path.addLine(to: toCGPoint(inVec: points[1], direction: direction))
                        path.closeSubpath()
                    }
                    .stroke(Color.white, lineWidth: 3 / scale)
                } else {
                    EmptyView()
                        .onAppear {
                            print("Non-implemented geometry type attempted to be rendered in Viewport GeometryElement: \(g.type)")
                        }
                }
            }
            .onAppear {
                // print("Debug: Line case appeared")
                // print("Debug: getPoints() returned \(points)")
            }
        default:
            Text("Not implemented")
                .onAppear {
                    print("Debug: Default case appeared")
                }
        }
    }
}
