//
//  InputGroupColumn.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 05/09/2025.
//

import SwiftUI

struct InputGroupColumn: View, Equatable {
    static func == (l: Self, r: Self) -> Bool {
        return false
    }
    
    @Binding var group: SceneInputGroup
    let inputs: [SceneInput]
    let titleOverride: String?
    
    var body: some View {
        if group.isVisible {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack(spacing: 8) {
                    Button(action: {group.isExpanded.toggle() }) {
                        Image(systemName: group.isExpanded ? "chevron.down" : "chevron.right")
                    }.buttonStyle(PlainButtonStyle())
                        .frame(width: 30)
                    Text(titleOverride ?? group.name)
                        .font(.headline)
                        .fontDesign(.monospaced)
                    if let note = group.note, !note.isEmpty {
                        Text(note).font(.subheadline)
                            .fontDesign(.monospaced)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
                
                if group.isExpanded {
                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(inputs) { input in
                                InputControlView(input: input)
                            }
                        }
                    }
                }
            }
        }
    }
}
