//
//  AudioDataPoint.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 28/06/2025.
//

import SwiftUI

struct AudioDataPoint {
    let timestamp: TimeInterval
    let rawVolume: Double
    let smoothedVolume: Double
    let processedVolume: Double
}
