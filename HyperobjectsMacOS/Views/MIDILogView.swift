//
//  MIDILogView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 24/05/2026.
//

import SwiftUI


struct MIDILogView: View {
    @EnvironmentObject var midiManager: MIDIManager
    var body: some View {
        VStack {
            HStack {
                Text("MIDI Logs")
                Spacer()
                Button("Clear Log") {
                    midiManager.clearLog()
                }
            }.padding()
            ScrollView {
                ScrollViewReader { proxy in
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(midiManager.logEntries.indices, id: \.self) { index in
                            Text(midiManager.logEntries[index])
                                .font(.system(.caption, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 1)
                                .background(index % 2 == 0 ? Color.clear : Color.gray.opacity(0.1))
                                .id(index)
                        }
                    }.onChange(of: midiManager.logEntries.count) { _ in
                        if let lastIndex = midiManager.logEntries.indices.last {
                            withAnimation {
                                proxy.scrollTo(lastIndex, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
    }
}
