//
//  EdgeKey.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 05/01/2026.
//

struct EdgeKey: Hashable {
    let i1: Int
    let i2: Int
    
    init(_ i1: Int, _ i2: Int) {
        self.i1 = i1
        self.i2 = i2
    }
}
