//
//  ContentView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 11/10/2024.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Text("Hyperobjects MacOS")
            WindowsManagerView()
            Spacer()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
