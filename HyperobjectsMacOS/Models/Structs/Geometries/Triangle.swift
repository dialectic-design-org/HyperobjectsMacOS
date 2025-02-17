//
//  Triangle.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 05/02/2025.
//

struct Triangle {
    var vertices: [SIMD3<Float>]
    var color: SIMD4<Float> = .init(1, 1, 1, 1)
    
    func toShader() -> Shader_Triangle {
        var triangle: Shader_Triangle = .init()
        return triangle
    }
}
