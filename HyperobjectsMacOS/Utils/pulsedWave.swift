//
//  pulsedWave.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 04/01/2026.
//

import Foundation

/// Generates a wave value based on time, frequency, and peak steepness.
/// - Parameters:
///   - t: The time or input parameter.
///   - frequency: how many cycles occur per unit of t.
///   - steepness: Higher values make the peaks sharper and the valleys flatter.
/// - Returns: A Float representing the wave height at time t.
func pulsedWave(t: Float, frequency: Float = 1.0, steepness: Float = 3.0) -> Float {
    // 1. Calculate the standard sine position
    // We use 2 * PI to ensure frequency represents "cycles per second/unit"
    let angle = 2.0 * Float.pi * t * frequency
    let sineValue = sin(angle)
    
    // 2. Adjust for steepness
    // We take the absolute value to apply the power,
    // then restore the sign (positive/negative) so it stays a wave.
    let absoluteSine = abs(sineValue)
    let pulsedValue = pow(absoluteSine, steepness)
    
    // 3. Return the value with the original sign
    return sineValue >= 0 ? pulsedValue : -pulsedValue
}
