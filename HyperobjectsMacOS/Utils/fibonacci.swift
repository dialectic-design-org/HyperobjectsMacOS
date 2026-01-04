//
//  fibonacci.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 03/01/2026.
//

import simd

func fibonacciSquares(count: Int, firstSquareSize: Double = 0.1) -> [[SIMD2<Double>]] {
    guard count > 0 else { return [] }
    
    var fib = Array(repeating: 0, count: count)
    for i in 0..<count {
        if i == 0 || i == 1 { fib[i] = 1 }
        else { fib[i] = fib[i - 1] + fib[i - 2] }
    }
    
    func corners(x:Double, y: Double, s: Double) -> [SIMD2<Double>] {
        let bl = SIMD2<Double>(x, y)
        let br = SIMD2<Double>(x + s, y)
        let tr = SIMD2<Double>(x + s, y + s)
        let tl = SIMD2<Double>(x, y + s)
        return [bl, br, tr, tl]
    }
    
    var out: [[SIMD2<Double>]] = []
    let s0 = firstSquareSize * Double(fib[0])
    
    var minX = 0.0, minY = 0.0, maxX = s0, maxY = s0
    out.append(corners(x: 0.0, y: 0.0, s: s0))
    if count == 1 { return out }
    
    let s1 = firstSquareSize * Double(fib[1])
    out.append(corners(x: maxX, y: minY, s: s1))
    maxX += s1
    if count == 2 { return out }
    
    var dir = 1
    
    for i in 2..<count {
        let s = firstSquareSize * Double(fib[i])
        
        var x = 0.0, y = 0.0
        switch dir {
        case 0: // right: align bottom to minY
            x = maxX
            y = minY
        case 1: // up: align left to minX
            x = minX
            y = maxY
        case 2: // left: align top to maxY
            x = minX - s
            y = maxY - s
        default: // down: align right to maxX
            x = maxX - s
            y = minY - s
        }
        
        out.append(corners(x: x, y: y, s: s))
        
        minX = min(minX, x)
        minY = min(minY, y)
        maxX = max(maxX, x + s)
        maxY = max(maxY, y + s)
        
        dir = (dir + 1) % 4
    }
    return out
}
