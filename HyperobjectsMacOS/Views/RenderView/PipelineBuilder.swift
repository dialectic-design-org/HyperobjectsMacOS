//
//  PipelineBuilder.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 03/01/2025.
//

import Metal

func build_pipeline(device: MTLDevice) -> MTLRenderPipelineState {
    let pipeline: MTLRenderPipelineState
    
    let library = device.makeDefaultLibrary()
    let vertexFunction = library?.makeFunction(name: "vertex_main")
    let fragmentFunction = library?.makeFunction(name: "fragment_main")
    let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
    pipelineStateDescriptor.vertexFunction = vertexFunction
    pipelineStateDescriptor.fragmentFunction = fragmentFunction
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    
    do {
        try pipeline = device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        return pipeline
    } catch {
        print("failed")
        fatalError("Failed to create pipeline")
    }
}
