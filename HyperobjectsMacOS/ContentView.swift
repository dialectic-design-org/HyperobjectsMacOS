//
//  ContentView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 11/10/2024.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var currentScene: GeometriesSceneBase
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        VStack {
            RenderView()
        }.font(myFont)
        
    }
}
//
//    .onAppear() {
//        for window in allWindows {
//            if window.showOnLoad {
//                openWindow(id: window.id)
//            }
//        }
//    }


#Preview {
    ContentView()
}
