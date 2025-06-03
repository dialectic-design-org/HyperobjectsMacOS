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
                    Text(window.title).font(myFont)
                    Spacer()
                    Button("Open") {
                        openWindow(id: window.id)
                    }.font(myFont)
                }
            }
        }
    }
}

#Preview {
    WindowsManagerView()
}
