//
//  SceneGeometryViewModel.swift
//  HyperobjectsMacOS
//
//  Polls the scene's renderBuffer at a bounded rate so SwiftUI views displaying
//  geometry don't re-evaluate at audio-tick rate (~86 Hz) or render-loop rate.
//

import Combine
import SwiftUI

@MainActor
final class SceneGeometryViewModel: ObservableObject {
    @Published private(set) var geometries: [GeometryWrapped] = []

    private var pollTimer: AnyCancellable?

    func bind(to scene: GeometriesSceneBase, hz: Double = 30.0) {
        pollTimer?.cancel()

        // Prime immediately so the first frame after a scene swap shows the new geometry.
        geometries = scene.renderBuffer.peek().geometries

        pollTimer = Timer.publish(every: 1.0 / hz, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self, weak scene] _ in
                guard let self, let scene else { return }
                let snap = scene.renderBuffer.peek()
                // Identity check: same array storage = nothing to do, avoid SwiftUI invalidation.
                if !snap.geometries.elementsEqualByIdentity(self.geometries) {
                    self.geometries = snap.geometries
                }
            }
    }
}

private extension Array where Element == GeometryWrapped {
    /// Cheap "is this the same array we already have?" check by ID, avoiding
    /// a full equatable comparison of every geometry payload.
    func elementsEqualByIdentity(_ other: [GeometryWrapped]) -> Bool {
        guard count == other.count else { return false }
        for i in 0..<count {
            if self[i].id != other[i].id { return false }
        }
        return true
    }
}
