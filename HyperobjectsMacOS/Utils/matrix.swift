//
//  matrix.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 23/08/2025.
//

import simd


func identity_matrix_float4x4() -> matrix_float4x4 {
    return matrix_float4x4(
        vector_float4(1.0, 0.0, 0.0, 0.0),  // column 0
        vector_float4(0.0, 1.0, 0.0, 0.0),  // column 1
        vector_float4(0.0, 0.0, 1.0, 0.0),  // column 2
        vector_float4(0.0, 0.0, 0.0, 1.0)   // column 3
    )
}
