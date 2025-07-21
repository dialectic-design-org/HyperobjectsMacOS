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

private let BIN_POW: UInt32 = 4
private let BIN_SIZE: UInt32 = 1 << BIN_POW
private let lineCount: UInt32 = 10000


class MetalRenderer {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var transformPSO: MTLComputePipelineState?
    var renderPSO: MTLComputePipelineState?
    var renderPipelineState: MTLRenderPipelineState?
    var computeToRenderPipelineState: MTLRenderPipelineState?
    var currentScene: GeometriesSceneBase?
    var renderConfigs: RenderConfigurations?
    var vertexBuffer: MTLBuffer?
    var indexBuffer: MTLBuffer?
    var uniformBuffer: MTLBuffer?
    var lineRenderTextureA: MTLTexture!
    var lineRenderTextureB: MTLTexture!
    
    private var linesBuffer: MTLBuffer!
    private var binCounts: MTLBuffer!
    private var binOffsets: MTLBuffer!
    private var binList: MTLBuffer!
    
    private var currentTextureWidth: Int = 0
    private var currentTextureHeight: Int = 0
    
    var rotation: Float = 0.0
    var drawCounter: Int = 0
    
    // Reference to the state
    weak var rendererState: RendererState?
    
    init?(rendererState: RendererState, currentScene: GeometriesSceneBase, renderConfigs: RenderConfigurations) {
        self.rendererState = rendererState
        self.currentScene = currentScene
        self.renderConfigs = renderConfigs
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
        
        let maxViewSize = 4096
        let binCols = (maxViewSize + Int(BIN_SIZE) - 1) / Int(BIN_SIZE)
        let binRows = (maxViewSize + Int(BIN_SIZE) - 1) / Int(BIN_SIZE)
        let totalBins = binCols * binRows
        
        
        linesBuffer = device.makeBuffer(length: MemoryLayout<Shader_Line>.stride * Int(lineCount), options: .storageModeShared)!
        binCounts = device.makeBuffer(length: MemoryLayout<UInt32>.stride * totalBins, options: .storageModeShared)!
        binOffsets = device.makeBuffer(length: MemoryLayout<UInt32>.stride * totalBins, options: .storageModeShared)!
        binList = device.makeBuffer(length: MemoryLayout<UInt32>.stride * Int(lineCount) * totalBins, options: .storageModeShared)!
        
        let linesPtr = linesBuffer.contents().bindMemory(to: Shader_Line.self, capacity: Int(lineCount))
        
//        linesPtr[0] = Shader_Line(
//            p0_world: SIMD3<Float>(-1.0, 0.0, 0.0),
//            p1_world: SIMD3<Float>(1.0, 0.0, 0.0),
//            p0_screen: SIMD2<Float>(0.0, 0.0),
//            p1_screen: SIMD2<Float>(0.0, 0.0),
//            halfWidth0: 1.0,
//            halfWidth1: 1.0,
//            antiAlias: 0.01,
//            depth: 0.0,
//            p0_depth: 0.0,
//            p1_depth: 0.0,
//            _pad0: 0.0,
//            colorPremul0: SIMD4<Float>(repeating: 1.0),
//            colorPremul1: SIMD4<Float>(repeating: 1.0)
//        )
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
        
        
        
        // Create compute to render pipeline state
        guard let computeVertexFunction = library?.makeFunction(name: "compute_vertex"),
              let computeFragmentFunction = library?.makeFunction(name: "compute_fragment") else {
            print("Failed to create shader functions")
            return
        }
        
        let computeRenderPipelineDescriptor = MTLRenderPipelineDescriptor()
        computeRenderPipelineDescriptor.vertexFunction = computeVertexFunction
        computeRenderPipelineDescriptor.fragmentFunction = computeFragmentFunction
        // computeRenderPipelineDescriptor.vertexDescriptor = vertexDescriptor
        computeRenderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Error creating render pipeline state: \(error)")
        }
        
        do {
            computeToRenderPipelineState = try device.makeRenderPipelineState(descriptor: computeRenderPipelineDescriptor)
        } catch {
            print("Error creating render pipeline state: \(error)")
        }
        
        do {
            self.transformPSO = try device.makeComputePipelineState(function: library!.makeFunction(name: "transformAndBin")!)
        } catch {
            fatalError("Failed to create transformAndBin pipeline state: \(error)")
        }
        do {
            self.renderPSO = try device.makeComputePipelineState(function: library!.makeFunction(name: "drawLines")!)
        } catch {
            fatalError("Failed to create drawLines pipeline state: \(error)")
        }
        
    }
    
    func createLineRenderTexture(width: Int, height: Int) {
        let textureDescriptorA = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptorA.usage = [.shaderWrite, .shaderRead, .renderTarget]
        textureDescriptorA.storageMode = .private
        lineRenderTextureA = device.makeTexture(descriptor: textureDescriptorA)
        
        let textureDescriptorB = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptorB.usage = [.shaderWrite, .shaderRead, .renderTarget]
        textureDescriptorB.storageMode = .private
        lineRenderTextureB = device.makeTexture(descriptor: textureDescriptorB)
    }
    
    func render(drawable: CAMetalDrawable) {
        guard let renderPipelineState = renderPipelineState,
              let computeToRenderPipelineState = computeToRenderPipelineState,
              let vertexBuffer = vertexBuffer,
              let indexBuffer = indexBuffer,
              let uniformBuffer = uniformBuffer,
              let scene = currentScene else { return }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        
        drawCounter += 1
        
        var writeTexture: MTLTexture?
        var readTexture: MTLTexture?
        
        if drawCounter.isMultiple(of: 2) {
            writeTexture = lineRenderTextureA
            readTexture = lineRenderTextureB
        } else {
            writeTexture = lineRenderTextureB
            readTexture = lineRenderTextureA
        }
        
        var testPoints: [SIMD3<Float>] = []
        
        let linesPtr = linesBuffer.contents().bindMemory(to: Shader_Line.self, capacity: Int(lineCount))
        // Wipe all lines in the buffer so new ones can be set.
        let byteCount = linesBuffer.length
        memset(linesBuffer.contents(), 0, byteCount)
        
        var gIndex: Int = 0
        
        var geometriesTime: Float = 0.0
        for gWrapped in scene.cachedGeometries {
            let geometry = gWrapped.geometry
            geometriesTime = Float(gIndex) / Float(scene.cachedGeometries.count)
            switch geometry.type {
            case .line:
                if let lineGeometry = geometry as? Line {
                    var scalingFactor:Float = 1.0;
                    var line = geometry.getPoints()
                    testPoints.append(line[0] * scalingFactor)
                    testPoints.append(line[1] * scalingFactor)
                    
                    let color = SIMD4<Float>(0.0, 1.0 - geometriesTime, geometriesTime, 1.0)
//                    linesPtr[gIndex] = Shader_Line(
//                        p0_world: line[0],
//                        p1_world: line[1],
//                        p0_screen: SIMD2<Float>(1000.0, 10000.0),
//                        p1_screen: SIMD2<Float>(10000.0, 10000.0),
//                        halfWidth0: lineGeometry.lineWidthStart,
//                        halfWidth1: lineGeometry.lineWidthEnd,
//                        antiAlias: 0.707,
//                        depth: 0.0,
//                        p0_depth: 0.0,
//                        p1_depth: 0.0,
//                        _pad0: 0.0,
//                        colorPremul0: lineGeometry.colorStart,
//                        colorPremul1: lineGeometry.colorEnd,
//                        p0_inv_w: 0.0,
//                        p1_inv_w: 0.0,
//                        p0_depth_over_w: 0.0,
//                        p1_depth_over_w: 0.0
//                    )
                    linesPtr[gIndex] = Shader_Line.initWithValues(
                        p0_world: line[0],
                        p1_world: line[1],
                        halfWidth0: lineGeometry.lineWidthStart,
                        halfWidth1: lineGeometry.lineWidthEnd,
                        colorPremul0: lineGeometry.colorStart,
                        colorPremul0OuterLeft: lineGeometry.colorStartOuterLeft,
                        colorPremul0OuterRight: lineGeometry.colorStartOuterRight,
                        sigmoidSteepness0: lineGeometry.sigmoidSteepness0,
                        sigmoidMidpoint0: lineGeometry.sigmoidMidpoint0,
                        colorPremul1: lineGeometry.colorEnd,
                        colorPremul1OuterLeft: lineGeometry.colorEndOuterLeft,
                        colorPremul1OuterRight: lineGeometry.colorEndOuterRight,
                        sigmoidSteepness1: lineGeometry.sigmoidSteepness1,
                        sigmoidMidpoint1: lineGeometry.sigmoidMidpoint1
                        
                        
                    )
                }
                
            default:
                let notImplementedError = "Not implemented yet"
            }
            gIndex += 1
        }
        
        
        
        
        
        
        let viewW = Int(drawable.texture.width)
        let viewH = Int(drawable.texture.height)
        
        if viewW != currentTextureWidth || viewH != currentTextureHeight {
            createLineRenderTexture(width: viewW, height: viewH)
            currentTextureWidth = viewW
            currentTextureHeight = viewH
        }
        
        // Clear binning data
        let binCols = (viewW + Int(BIN_SIZE) - 1) / Int(BIN_SIZE)
        let binRows = (viewH + Int(BIN_SIZE) - 1) / Int(BIN_SIZE)
        let totalBins = binCols * binRows
        
        let maxViewSize = 4096
        let maxBinCols = (maxViewSize + Int(BIN_SIZE) - 1) / Int(BIN_SIZE)
        let maxBinRows = (maxViewSize + Int(BIN_SIZE) - 1) / Int(BIN_SIZE)
        let maxTotalBins = maxBinCols * maxBinRows
        
        if totalBins > maxTotalBins {
            print("ERROR: totalBins (\(totalBins)) exceeds maxTotalBins (\(maxTotalBins))")
            print("View size: \(viewW)x\(viewH), Bin grid: \(binCols)x\(binRows)")
        }
        
        let binCountsPtr = binCounts.contents().bindMemory(to: UInt32.self, capacity: totalBins)
        let binOffsetsPtr = binOffsets.contents().bindMemory(to: UInt32.self, capacity: totalBins)
        var offset: UInt32 = 0
        for i in 0..<totalBins {
            binCountsPtr[i] = 0
            binOffsetsPtr[i] = offset
            offset += lineCount // Each bin can potentially hold all lines
        }
        
        // Create MVP matrix (identity for this example)
        var MVP = matrix_identity_float4x4
            
        let viewWidth = drawable.texture.width
        let viewHeight = drawable.texture.height
        let aspectRatio:Float = Float(drawable.texture.width) / Float(drawable.texture.height)
        
        let fieldOfView = Float.pi / 3
        let nearClippingPlane: Float = 0.1
        let farCplippingPlane: Float = 100.0
        
        let perspectiveMatrix = matrix_perspective(fovY: fieldOfView, aspect: aspectRatio, nearZ: nearClippingPlane, farZ: farCplippingPlane)
        // 1. Define the camera's properties
        
        let time = CACurrentMediaTime()
        var transitionFactor = Float(0.5 + 0.5 * sin(time))
        transitionFactor = 1.0
        
        var cameraDistance = renderConfigs?.cameraDistance ?? 5.0
        
        let cameraPosition = simd_float3(x: 0.0, y: 0.0, z: cameraDistance)
        let targetPosition = simd_float3(x: 0.0, y: 0.0, z: 0.0) // Look at the object
        let upDirection = simd_float3(x: 0.0, y: 1.0, z: 0.0) // World's "up" is Y

        // 2. Create the view matrix
        let viewMatrix = matrix_lookAt(eye: cameraPosition, target: targetPosition, up: upDirection)
        
        let focalDistance: Float = 1.0
        let orthoHeight: Float = 2.0 // * focalDistance * tan((Float.pi / 3) / 2.0)
        let orthoWidth = orthoHeight * aspectRatio
        
        let orthographicMatrix = matrix_orthographic(left: -orthoWidth / 2.0,
                                                  right: orthoWidth / 2.0,
                                                  bottom: -orthoHeight / 2.0,
                                                  top: orthoHeight / 2.0,
                                                  nearZ: 0.1,
                                                  farZ: 100.0)
        
        let projectionMatrix = (1.0 - transitionFactor) * orthographicMatrix + transitionFactor * perspectiveMatrix
        
        MVP = projectionMatrix * viewMatrix
        
        let backgroundColor = renderConfigs?.backgroundColor ?? ColorInput()
        
        // Convert to vector_float3
        
        var transformUniforms: TransformUniforms = TransformUniforms(
            viewWidth: Int32(viewW),
            viewHeight: Int32(viewH),
            cameraPosition: cameraPosition,
            backgroundColor: colorToVector(backgroundColor.color)
        )
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .load
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        
        let renderSDFLines = renderConfigs?.renderSDFLines ?? false
        
        if renderSDFLines {
            if let transformEncoder = commandBuffer.makeComputeCommandEncoder() {
                transformEncoder.setComputePipelineState(transformPSO!)
                transformEncoder.setBuffer(linesBuffer,      offset:0, index:0)
                transformEncoder.setBytes(&MVP,           length:MemoryLayout<float4x4>.stride, index:1)
                transformEncoder.setBytes(&transformUniforms,      length:MemoryLayout<TransformUniforms>.stride, index:2)
                transformEncoder.setBuffer(binCounts,     offset:0, index:3)
                transformEncoder.setBuffer(binOffsets,    offset:0, index:4)
                transformEncoder.setBuffer(binList,       offset:0, index:5)
                let tg = MTLSize(width: transformPSO!.threadExecutionWidth,
                                 height: 1,
                                 depth: 1)
                transformEncoder.dispatchThreads(MTLSize(width: Int(lineCount), height: 1, depth: 1),
                                                 threadsPerThreadgroup: tg)
                transformEncoder.endEncoding()          // ← guarantees completion before the next encoder
            }
            
            if let drawLinesEncoder = commandBuffer.makeComputeCommandEncoder() {
                drawLinesEncoder.setComputePipelineState(renderPSO!)
                drawLinesEncoder.setTexture(writeTexture, index: 0)
                drawLinesEncoder.setBuffer(linesBuffer,      offset:0, index:0)
                drawLinesEncoder.setBuffer(binCounts,     offset:0, index:1)
                drawLinesEncoder.setBuffer(binOffsets,    offset:0, index:2)
                drawLinesEncoder.setBuffer(binList,       offset:0, index:3)
                drawLinesEncoder.setBytes(&transformUniforms,      length:MemoryLayout<TransformUniforms>.stride, index:4)
                
                let w  = renderPSO!.threadExecutionWidth
                let h  = renderPSO!.maxTotalThreadsPerThreadgroup / w
                let tg2 = MTLSize(width: w, height: h, depth: 1)
                drawLinesEncoder.dispatchThreads(MTLSize(width: viewW, height: viewH, depth: 1),
                                                 threadsPerThreadgroup: tg2)
                drawLinesEncoder.endEncoding()
            }
        }
        
        
        // FURTHER RENDER PASS
        let computeToRenderRenderPassDescriptor = MTLRenderPassDescriptor()
        computeToRenderRenderPassDescriptor.colorAttachments[0].texture = drawable.texture
        computeToRenderRenderPassDescriptor.colorAttachments[0].loadAction = .clear
        computeToRenderRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        // computeToRenderRenderPassDescriptor.colorAttachments[0].storeAction = .store
        
        guard let computeToRenderRenderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: computeToRenderRenderPassDescriptor) else { return }
        
        computeToRenderRenderEncoder.setRenderPipelineState(computeToRenderPipelineState)
        computeToRenderRenderEncoder.setFragmentTexture(readTexture, index: 0)
        
        computeToRenderRenderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)

        
        computeToRenderRenderEncoder.endEncoding()
        
        
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        
        renderEncoder.setRenderPipelineState(renderPipelineState)

        // Update rotation based on speed
        let rotationSpeed:Float = 0.5
        rotation += 0.01 * rotationSpeed
        if rotation > Float.pi * 2 {
            rotation -= Float.pi * 2
        }
        
        
        
        // Update uniform buffer with new rotation
        var uniforms = [VertexUniforms(
            projectionMatrix: identity_matrix_float4x4(),
            viewMatrix: identity_matrix_float4x4(),
            rotationAngle: rotation
        )]
        
        
        
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
//        
//        renderEncoder.drawIndexedPrimitives(type: .triangle,
//                                           indexCount: 3,
//                                           indexType: .uint16,
//                                           indexBuffer: indexBuffer,
//                                           indexBufferOffset: 0)
        
        
        
        let renderPoints = renderConfigs?.renderPoints ?? false
        if renderPoints {
            renderEncoder.drawPrimitives(type: .point,
                                         vertexStart: 0,
                                         vertexCount: testPoints.count)
        }
        
        let renderLinesOverlay = renderConfigs?.renderLinesOverlay ?? false
        
        if renderLinesOverlay {
            renderEncoder.drawPrimitives(type: .line,
                                         vertexStart: 0,
                                         vertexCount: testPoints.count)
        }
        
        // renderEncoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: testPoints.count)

        
        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
}
