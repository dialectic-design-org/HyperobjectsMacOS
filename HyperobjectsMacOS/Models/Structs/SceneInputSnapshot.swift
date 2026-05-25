//
//  SceneInputSnapshot.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 25/05/2026.
//

import Foundation

struct SceneInputSnapshot {
    var entries: [SceneInputView] = []
    var changedInputs: Set<String> = []
    var generators: [any GeometryGenerator] = []

    // For extractHistoricAudioValue:
    var audioHistorySuffix120: [AudioDataPoint] = []
    var audioSignalProcessed: Double = 0.0

    // For makeOverrideContext:
    var audioSignal: Float = 0.0
    var frameStamp: Int = 0

    // Populated by the producer; replayed on main after publish.
    var pendingValueHistoryRecords: [(name: String, value: Float)] = []
}
