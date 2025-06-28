//
//  FreeformEnvelope.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 28/06/2025.
//

import SwiftUI

class FreeformEnvelope: EnvelopeProcessor, ObservableObject {
    @Published var controlPoints: [ControlPoint] = [
        ControlPoint(x: 0.0, y: 0.0),
        ControlPoint(x: 0.5, y: 0.3),
        ControlPoint(x: 1.0, y: 1.0)
    ]
    
    func process(_ input: Double) -> Double {
        let clampedInput = max(0.0, min(1.0, input))
        let sortedPoints = controlPoints.sorted { $0.x < $1.x }
        
        // Find the two points to interpolate between
        for i in 0..<(sortedPoints.count - 1) {
            let p1 = sortedPoints[i]
            let p2 = sortedPoints[i + 1]
            
            if clampedInput >= p1.x && clampedInput <= p2.x {
                // Linear interpolation
                let t = (clampedInput - p1.x) / (p2.x - p1.x)
                return p1.y + t * (p2.y - p1.y)
            }
        }
        
        // If input is outside range, return closest point
        if clampedInput <= sortedPoints.first?.x ?? 0.0 {
            return sortedPoints.first?.y ?? 0.0
        } else {
            return sortedPoints.last?.y ?? 1.0
        }
    }
    
    func updateControlPoint(id: UUID, to newPosition: CGPoint, in size: CGSize) {
        if let index = controlPoints.firstIndex(where: { $0.id == id }) {
            let x = max(0.0, min(1.0, Double(newPosition.x / size.width)))
            let y = max(0.0, min(1.0, 1.0 - Double(newPosition.y / size.height)))
            controlPoints[index] = ControlPoint(x: x, y: y)
        }
    }
}

