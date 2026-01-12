//
//  CA1DQuines.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 11/01/2026.
//

private func ruleToBits(_ rule: Int) -> [Int] {
    (0..<8).map { (rule >> $0) & 1}
}

private func neighborhoodIndex(left: Int, center: Int, right: Int) -> Int {
    (left << 2) | (center << 1) | right
}

private func applyRule(bits: [Int], ruleBits: [Int]) -> [Int] {
    let n = bits.count
    return (0..<n).map { i in
        let left = bits[(i - 1 + n) % n]
        let center = bits[i]
        let right = bits[(i + 1) % n]
        return ruleBits[neighborhoodIndex(left: left, center: center, right: right)]
    }
}

private func isQuineRule(_ rule: Int) -> Bool {
    let bits = ruleToBits(rule)
    return bits == applyRule(bits: bits, ruleBits: bits)
}

private func findQuineRules() -> [[Int]] {
    (0..<256)
        .filter(isQuineRule)
        .map(ruleToBits)
}

let quines1DCA = findQuineRules()


