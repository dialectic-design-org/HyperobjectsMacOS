//
//  ContentView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 11/10/2024.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var currentScene: GeometriesSceneBase
    var body: some View {
        VStack {
            HStack {
                Text("Current scene:")
                Text("\(currentScene.name)")
                    .fontWeight(.bold)
            }
            WindowsManagerView()
            Spacer()
        }.font(myFont)
    }
}

#Preview {
    ContentView()
}
