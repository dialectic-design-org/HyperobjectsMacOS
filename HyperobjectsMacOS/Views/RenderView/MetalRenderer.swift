//
//  MetalRenderer.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 01/01/2025.
//

import Foundation
import SwiftUI
import MetalKit


struct VertexUniforms {
    var projectionMatrix: matrix_float4x4
    var viewMatrix: matrix_float4x4
}


// Serves as coordinator for MetalView
class MetalRenderer: NSObject, MTKViewDelegate {
    private(set) var currentScene: GeometriesSceneBase
    var parent: MetalView
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var pipelineState: MTLRenderPipelineState!
    var projectionMatrix: matrix_float4x4!
    var viewMatrix: matrix_float4x4!
    var frameNumber: Int = 0
    var drawCounter: Int = 0
    
    init(_ parent: MetalView, currentSceneFromParent: GeometriesSceneBase) {
        print("MetalRenderer init()")
        self.parent = parent
        self.currentScene = currentSceneFromParent
        super.init()
        setupCamera()
    }
    
    func updateCurrentScene(_ newScene: GeometriesSceneBase) {
        self.currentScene = newScene
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        print("MetalRenderer mtkView(drawableSizeWillChange: \(size) {\(currentScene.name)}")
    }
    
    func setup(device: MTLDevice) {
        print("MetalRenderer setup()")
        guard let device = MTLCreateSystemDefaultDevice() else { fatalError("GPU not available") }
        self.device = device
        commandQueue = device.makeCommandQueue()
        pipelineState = build_pipeline(device: device)
    }
    
    private func setupCamera() {
//        let cameraPosition = SIMD3<Float>(0, -60, 0)
//        let target = SIMD3<Float>(0, 0, 0)
//        let up = SIMD3<Float>(0, 0, 1)
        
        let cameraPosition = SIMD3<Float>(0, 0, 100) // Z = 100
        let target = SIMD3<Float>(0, 0, 0)           // Looking at the origin
        let up = SIMD3<Float>(0, 1, 0)               // Y-axis as up direction

        
        viewMatrix = matrix_lookAt(eye: cameraPosition, target: target, up: up)
        updateProjectionMatrix(for: CGSize(width: 800, height: 600))
    }
    
    private func updateCamera(position: SIMD3<Float>, target: SIMD3<Float>, up: SIMD3<Float>) {
        viewMatrix = matrix_lookAt(eye: position, target: target, up: up)
        updateProjectionMatrix(for: CGSize(width: 800, height: 600))
    }
    
    private func updateProjectionMatrix(for size: CGSize) {
        let aspectRatio = Float(size.width / size.height)
        // let fov = 2.0 * atan(0.024 / (2.0 * 0.5)) // Approx 50mm lens
        let fov = Float.pi / 4 // 45-degree vertical field of view

        projectionMatrix = matrix_perspective(fovY: Float(fov), aspect: aspectRatio, nearZ: 0.1, farZ: 1000.0)
    }
    
    func draw(in view: MTKView) {
        if (drawCounter % 120 == 0) {
            print("MetalRenderer draw() currentScene: \(currentScene.name) {drawCounter: \(drawCounter)}")
        }
        drawCounter += 1
 
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        renderEncoder.setRenderPipelineState(pipelineState)
        
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 1, blue: 0, alpha: 1)
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        var testPoints: [SIMD3<Float>] = [
                    SIMD3<Float>(-1.0, -1.0, 0.0),  // Bottom left
                    SIMD3<Float>(1.0, -1.0, 0.0),   // Bottom right
                    SIMD3<Float>(-1.0, 1.0, 0.0),   // Top left
                    SIMD3<Float>(1.0, 1.0, 0.0),    // Top Right
                    SIMD3<Float>(0.0, 1.0, 0.0),    // Top center
                    SIMD3<Float>(0.0, 0.0, 0.0),    // Center
                ]
        
        for gWrapped in currentScene.cachedGeometries {
            let geometry = gWrapped.geometry
            switch geometry.type {
            case .line:
                var line = geometry.getPoints()
                testPoints.append(line[0] * 0.1)
                testPoints.append(line[1] * 0.1)
            default:
                let notImplementedError = "Not implemented yet"
                
            }
        }
        
        for (index, point) in testPoints.enumerated() {
            // testPoints[index] = translateWaveEffect(vec: testPoints[index], index: index, drawCounter: drawCounter)
            testPoints[index] = rotationEffect(vec: testPoints[index], drawCounter: drawCounter, rotationSpeed: 0.3, axis: 0)
            testPoints[index] = rotationEffect(vec: testPoints[index], drawCounter: drawCounter, rotationSpeed: 0.5, axis: 1)
            testPoints[index] = rotationEffect(vec: testPoints[index], drawCounter: drawCounter, rotationSpeed: 0.66, axis: 2)
            testPoints[index].z -= 1.0

        }
        
        
        guard let vertexBuffer = device.makeBuffer(bytes: testPoints, length: testPoints.count * MemoryLayout<SIMD3<Float>>.stride, options: []) else {
            print("Failed to create vertex buffer")
            return
        }
        
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        var uniforms = VertexUniforms(
            projectionMatrix: matrix_identity_float4x4,
            viewMatrix: matrix_identity_float4x4
        )
        
        renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<VertexUniforms>.size, index: 1)
        
        var color = SIMD4<Float>(0, 1, 1, 1)
        renderEncoder.setFragmentBytes(&color, length: MemoryLayout<SIMD4<Float>>.size, index: 0)
        
        renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: testPoints.count)
        renderEncoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: testPoints.count)
        renderEncoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: testPoints.count)
        // renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: testPoints.count)
        // renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: testPoints.count)

        
        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    private func generateQuadVertices(for line: Line) -> [SIMD3<Float>] {
        let direction = normalize(line.endPoint - line.startPoint)
        let perpendicular = SIMD3<Float>(-direction.y, direction.x, 0) * (line.lineWidth / 2 * 2)

        let topLeft = line.startPoint + perpendicular
        let topRight = line.endPoint + perpendicular
        let bottomLeft = line.startPoint - perpendicular
        let bottomRight = line.endPoint - perpendicular

        // Return two triangles as a quad
        return [topLeft, bottomLeft, topRight, topRight, bottomLeft, bottomRight]
    }
}
