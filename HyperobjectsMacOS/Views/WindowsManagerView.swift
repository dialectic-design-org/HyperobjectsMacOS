//
//  WindowsManagerView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 11/10/2024.
//

import SwiftUI

struct WindowsManagerView: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        VStack {
            List(allWindows) { window in
                HStack {
                    Text(window.title)
                    Spacer()
                    Button("Open") {
                        openWindow(id: window.id)
                    }
                }
            }
        }
        .onAppear() {
            print("WindowsManagerView appeared")
            for window in allWindows {
                if window.showOnLoad {
                    openWindow(id: window.id)
                }
            }
        }
    }
}
