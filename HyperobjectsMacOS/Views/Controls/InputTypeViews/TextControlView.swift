//
//  TextControlView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 02/08/2025.
//

import SwiftUI

struct StringInputControlView: View {
    @ObservedObject var input: SceneInput
    
    // Local state mirrors
    @State private var userValue: String = ""
    @State private var isEditing: Bool = false
    
    // Preset options - you can customize these or make them configurable
    var presetOptions: [String] {
            Array(input.presetValues.keys).sorted()
        }
    
    var body: some View {
        VStack(spacing: 16) {
            // Text input field
            VStack(alignment: .leading, spacing: 8) {
                Text("Input Value")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("Enter text...", text: $userValue, onEditingChanged: { editing in
                    isEditing = editing
                })
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: userValue) { oldValue, newValue in
                    input.value = newValue
                }
            }
            
            // Preset buttons
            VStack(alignment: .leading, spacing: 8) {
                Text("Presets")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(presetOptions, id: \.self) { key in
                        Button(action: {
                            if let presetValue = input.presetValues[key] as? String {
                                userValue = presetValue
                                input.value = presetValue
                            }
                        }) {
                            Text(key)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(isCurrentPreset(key: key) ? Color.accentColor : Color.secondary.opacity(0.2))
                                )
                                .foregroundColor(isCurrentPreset(key: key) ? .white : .primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .onAppear {
            // Initialize local state once
            userValue = input.value as? String ?? ""
        }
    }
    
    // Helper function to check if current value matches a preset
    private func isCurrentPreset(key: String) -> Bool {
        guard let presetValue = input.presetValues[key] as? String,
              let currentValue = input.value as? String else {
            return false
        }
        return currentValue == presetValue
    }
}
