//
//  AudioTimelineViewModel.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 25/05/2026.
//

import Combine
import SwiftUI

class AudioTimelineViewModel: ObservableObject {
    @Published private(set) var historySnapshot: [AudioDataPoint] = []
    
    private var cancellable: AnyCancellable?
    
    func bind(to scene: GeometriesSceneBase, windowSeconds:Double) {
        let latest = scene.audioHistory.suffix(1).first?.timestamp ?? 0.0
        historySnapshot = scene.historyData(since: latest - windowSeconds)
        
        cancellable = scene.objectWillChange
                    .throttle(for: .milliseconds(33), scheduler: DispatchQueue.main, latest: true)
                    .sink { [weak self, weak scene] _ in
                        guard let self, let scene else { return }
                        let latest = scene.audioHistory.suffix(1).first?.timestamp ?? 0.0
                        self.historySnapshot = scene.historyData(since: latest - windowSeconds)
                    }
    }
}
