//
//  MetalRenderer.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 01/01/2025.
//

import Foundation
import SwiftUI
import MetalKit
import simd

struct VertexUniforms {
    var projectionMatrix: simd_float4x4   // 64 bytes
    var viewMatrix: simd_float4x4         // 64 bytes
    var rotationAngle: Float              // 4 bytes
    var _padding: SIMD3<Float> = SIMD3<Float>(0, 0, 0) // 12 bytes padding
}

func identity_matrix_float4x4() -> matrix_float4x4 {
    return matrix_float4x4(
        vector_float4(1.0, 0.0, 0.0, 0.0),  // column 0
        vector_float4(0.0, 1.0, 0.0, 0.0),  // column 1
        vector_float4(0.0, 0.0, 1.0, 0.0),  // column 2
        vector_float4(0.0, 0.0, 0.0, 1.0)   // column 3
    )
}


class MetalRenderer {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var renderPipelineState: MTLRenderPipelineState?
    var currentScene: GeometriesSceneBase?
    var vertexBuffer: MTLBuffer?
    var indexBuffer: MTLBuffer?
    var uniformBuffer: MTLBuffer?
    
    var rotation: Float = 0.0
    var drawCounter: Int = 0
    
    // Reference to the state
    weak var rendererState: RendererState?
    
    init?(rendererState: RendererState, currentScene: GeometriesSceneBase) {
        self.rendererState = rendererState
        self.currentScene = currentScene
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return nil
        }
        self.device = device
        
        guard let commandQueue = device.makeCommandQueue() else {
            print("Failed to create command queue")
            return nil
        }
        self.commandQueue = commandQueue
        
        createBuffers()
        createRenderPipelineState()
    }
    
    func updateCurrentScene(_ newScene: GeometriesSceneBase) {
        currentScene = newScene
        // createBuffers()
        // createRenderPipelineState()
    }
    
    private func createBuffers() {
        // Define a simple triangle
        var vertices: [Float] = [
            // Position (x, y, z)       // Color (r, g, b, a)
             0.0,  0.5, 0.0,            1.0, 0.0, 0.0, 1.0,
            -0.5, -0.5, 0.0,            0.0, 1.0, 0.0, 1.0,
             0.5, -0.5, 0.0,            0.0, 0.0, 1.0, 1.0
        ]
        // Apply scaling to the vertices with a factor variable
        var scalingFactor = 1.0
        for i in stride(from: 0, to: vertices.count, by: 3) {
            vertices[i] *= Float(scalingFactor)
            vertices[i+1] *= Float(scalingFactor)
            vertices[i+2] *= Float(scalingFactor)
        }
        
        // Create vertex buffer
        vertexBuffer = device.makeBuffer(bytes: vertices,
                                        length: vertices.count * MemoryLayout<Float>.size,
                                        options: .storageModeShared)
        
        // Create index buffer for drawing
        let indices: [UInt16] = [0, 1, 2]
        indexBuffer = device.makeBuffer(bytes: indices,
                                       length: indices.count * MemoryLayout<UInt16>.size,
                                       options: .storageModeShared)
        
        // Create uniform buffer for rotation
        let uniforms = [VertexUniforms(
            projectionMatrix: identity_matrix_float4x4(),
            viewMatrix: identity_matrix_float4x4(),
            rotationAngle: 0.0
        )] // Initial rotation angle
        uniformBuffer = device.makeBuffer(bytes: uniforms,
                                         length: MemoryLayout<VertexUniforms>.size,
                                         options: .storageModeShared)
    }
    
    func createRenderPipelineState() {
        // Create shader library
        let library = device.makeDefaultLibrary()

        
        // Get shader functions
        guard let vertexFunction = library?.makeFunction(name: "vertex_main"),
              let fragmentFunction = library?.makeFunction(name: "fragment_main") else {
            print("Failed to create shader functions")
            return
        }
        
        // Create vertex descriptor
        let vertexDescriptor = MTLVertexDescriptor()
        
        // Position attribute
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        
        // Color attribute
        vertexDescriptor.attributes[1].format = .float4
        vertexDescriptor.attributes[1].offset = 3 * MemoryLayout<Float>.size
        vertexDescriptor.attributes[1].bufferIndex = 0
        
        // Layout
        vertexDescriptor.layouts[0].stride = 7 * MemoryLayout<Float>.size
        vertexDescriptor.layouts[0].stepRate = 1
        vertexDescriptor.layouts[0].stepFunction = .perVertex
        
        // Configure pipeline descriptor
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Error creating render pipeline state: \(error)")
        }
    }
    
    func render(drawable: CAMetalDrawable) {
        guard let renderPipelineState = renderPipelineState,
              let vertexBuffer = vertexBuffer,
              let indexBuffer = indexBuffer,
              let uniformBuffer = uniformBuffer,
              let scene = currentScene else { return }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.01, alpha: 1.0)
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        
        renderEncoder.setRenderPipelineState(renderPipelineState)

        // Update rotation based on speed
        let rotationSpeed:Float = 0.5
        rotation += 0.01 * rotationSpeed
        if rotation > Float.pi * 2 {
            rotation -= Float.pi * 2
        }
        
        drawCounter += 1
        
        // Update uniform buffer with new rotation
        var uniforms = [VertexUniforms(
            projectionMatrix: identity_matrix_float4x4(),
            viewMatrix: identity_matrix_float4x4(),
            rotationAngle: rotation
        )]
        
        var testPoints: [SIMD3<Float>] = [
            SIMD3<Float>(-1.0, -1.0, 0.0),  // Bottom left
            SIMD3<Float>(1.0, -1.0, 0.0),   // Bottom right
            SIMD3<Float>(-1.0, 1.0, 0.0),   // Top left
            SIMD3<Float>(1.0, 1.0, 0.0),    // Top Right
            SIMD3<Float>(0.0, 1.0, 0.0),    // Top center
            SIMD3<Float>(0.0, 0.0, 0.0),    // Center
        ]
        
        testPoints = []
        
        for gWrapped in scene.cachedGeometries {
            let geometry = gWrapped.geometry
            switch geometry.type {
            case .line:
                var scalingFactor:Float = 1.0;
                var line = geometry.getPoints()
                testPoints.append(line[0] * scalingFactor)
                testPoints.append(line[1] * scalingFactor)
            default:
                let notImplementedError = "Not implemented yet"
            }
        }
        
        let applyRotationEffect = false
        
        
        if applyRotationEffect {
            for (index, point) in testPoints.enumerated() {
                // testPoints[index] = translateWaveEffect(vec: testPoints[index], index: index, drawCounter: drawCounter)
                testPoints[index] = rotationEffect(vec: testPoints[index], drawCounter: drawCounter, rotationSpeed: 0.3, axis: 0)
                testPoints[index] = rotationEffect(vec: testPoints[index], drawCounter: drawCounter, rotationSpeed: 0.5, axis: 1)
                testPoints[index] = rotationEffect(vec: testPoints[index], drawCounter: drawCounter, rotationSpeed: 0.66, axis: 2)
                testPoints[index].z += 10.0
            }
        }
        
        let rescaleToAspectRatio:Bool = true
        
        if rescaleToAspectRatio {
            let aspectRatio:Float = Float(drawable.texture.width) / Float(drawable.texture.height)
            for (index, point) in testPoints.enumerated() {
                testPoints[index].x /= aspectRatio
                
            }
        }
        
        
        guard let vertexBuffer = device.makeBuffer(
            bytes: testPoints,
            length: testPoints.count * MemoryLayout<SIMD3<Float>>.stride,
            options: []
        ) else { return }
        
        
        
        
        memcpy(uniformBuffer.contents(), uniforms, MemoryLayout<VertexUniforms>.size)
        
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        
//        renderEncoder.drawIndexedPrimitives(type: .triangle,
//                                           indexCount: 3,
//                                           indexType: .uint16,
//                                           indexBuffer: indexBuffer,
//                                           indexBufferOffset: 0)
        
        renderEncoder.drawPrimitives(type: .point,
                                     vertexStart: 0,
                                     vertexCount: testPoints.count)
        renderEncoder.drawPrimitives(type: .line,
                                     vertexStart: 0,
                                     vertexCount: testPoints.count)
        // renderEncoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: testPoints.count)

        
        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
