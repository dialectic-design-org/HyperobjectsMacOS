//
//  AudioLevelBar.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 28/06/2025.
//

import SwiftUI

struct AudioLevelBar: View {
    let label: String
    let value: Double
    let color: Color
    
    var body: some View {
        HStack {
            Text(label)
                .frame(width: 80, alignment: .leading)
                .font(.caption)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 8)
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(value), height: 8)
                }
            }.frame(height: 8)
            Text(String(format: "%.2f", value))
                .frame(width: 40, alignment: .trailing)
                .font(.caption.monospaced())
        }
    }
}
