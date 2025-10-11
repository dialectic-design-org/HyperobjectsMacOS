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

struct SegAlloc {
    var next: uint32
    var capacity: uint32
}

let maxMicroSegPerQuad  = 16
let maxMicroSegPerCubic = 24


func binGrid(viewWidth: Int, viewHeight: Int) -> (cols: Int, rows: Int, bins: Int) {
    let cols = (UInt32(viewWidth) + BIN_SIZE - 1) / BIN_SIZE
    let rows = (UInt32(viewHeight) + BIN_SIZE - 1) / BIN_SIZE
    return (Int(cols), Int(rows), Int(cols * rows))
}

func computeOutSegsCapacity(linearCount: Int, quadCount: Int, cubicCount: Int) -> Int {
    let reserveLinear = linearCount
    let reserveQuads = quadCount * maxMicroSegPerQuad
    let reserveCubics = cubicCount * maxMicroSegPerCubic
    return Int(Double(reserveLinear + reserveQuads + reserveCubics) * 1.2)
}

private let BIN_POW: UInt32 = 5
private let BIN_SIZE: UInt32 = 1 << BIN_POW
private let lineCount: UInt32 = 10000


class MetalRenderer {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var transformLinear: MTLComputePipelineState?
    var transformQuad: MTLComputePipelineState?
    var transformCubic: MTLComputePipelineState?
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
    let maxViewSize = 4096 * 2
    
    
    private var linesBuffer: MTLBuffer!
    private var quadraticCurvesBuffer: MTLBuffer!
    private var cubicCurvesBuffer: MTLBuffer!
    
    private var linearLinesScreenSpaceBuffer: MTLBuffer!
    
    private var binCounts: MTLBuffer!
    private var binOffsets: MTLBuffer!
    private var binList: MTLBuffer!
    private var segAllocBuffer: MTLBuffer!
    
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
        let scalingFactor = 1.0
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
        
        
        let binCols = (maxViewSize + Int(BIN_SIZE) - 1) / Int(BIN_SIZE)
        let binRows = (maxViewSize + Int(BIN_SIZE) - 1) / Int(BIN_SIZE)
        let totalBins = binCols * binRows
        
        // TODO: set correct buffer sizes based on types of lines
        linesBuffer = device.makeBuffer(length: MemoryLayout<LinearSeg3D>.stride * Int(lineCount), options: .storageModeShared)!
        quadraticCurvesBuffer = device.makeBuffer(length: MemoryLayout<QuadraticSeg3D>.stride * Int(lineCount), options: .storageModeShared)!
        cubicCurvesBuffer = device.makeBuffer(length: MemoryLayout<CubicSeg3D>.stride * Int(lineCount), options: .storageModeShared)!
        linearLinesScreenSpaceBuffer = device.makeBuffer(length: MemoryLayout<LinearSegScreenSpace>.stride * Int(lineCount), options: .storageModeShared)!
        
        binCounts = device.makeBuffer(length: MemoryLayout<UInt32>.stride * totalBins, options: .storageModeShared)!
        binOffsets = device.makeBuffer(length: MemoryLayout<UInt32>.stride * totalBins, options: .storageModeShared)!
        binList = device.makeBuffer(length: MemoryLayout<UInt32>.stride * Int(lineCount) * totalBins, options: .storageModeShared)!
        
        // TODO: IMPLEMENT DYNAMIC CAPACITY ALLOCATION!
        
        segAllocBuffer = device.makeBuffer(length: MemoryLayout<SegAlloc>.stride, options: .storageModeShared)!
        
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
        
        
        func makePSO(_ name: String) throws -> MTLComputePipelineState {
            do {
                return try device.makeComputePipelineState(function: library!.makeFunction(name: name)!)
            } catch {
                fatalError("Failed to create \(name) pipeline state: \(error)")
            }
            
        }
        
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
            self.transformLinear = try makePSO("transformAndBinLinear")
            self.transformQuad = try makePSO("transformAndBinQuadratic")
            self.transformCubic = try makePSO("transformAndBinCubic")
            self.renderPSO = try makePSO("drawLines")
        } catch {
            fatalError("Failed to create pipelines: \(error)")
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
        
        let linesPtr = linesBuffer.contents().bindMemory(to: LinearSeg3D.self, capacity: Int(lineCount))
        
        let quadraticCurvesPtr = quadraticCurvesBuffer.contents().bindMemory(to: QuadraticSeg3D.self, capacity: Int(lineCount))
        
        let cubicCurvesPtr = cubicCurvesBuffer.contents().bindMemory(to: CubicSeg3D.self, capacity: Int(lineCount))
        
        // Wipe all lines in the buffer so new ones can be set.
        let byteCount = linesBuffer.length
        memset(linesBuffer.contents(), 0, byteCount)
        
        let byteCountQuadratic = quadraticCurvesBuffer.length
        memset(quadraticCurvesBuffer.contents(), 0, byteCountQuadratic)
        
        let byteCountCubic = cubicCurvesBuffer.length
        memset(cubicCurvesBuffer.contents(), 0, byteCountCubic)
        
        
        var gIndex: Int = 0
        
        var geometriesTime: Float = 0.0
        
        var linearLinesIndex: Int = 0
        var quadraticLinesIndex: Int = 0
        var cubicLinesIndex: Int = 0
        
        for gWrapped in scene.cachedGeometries {
            let geometry = gWrapped.geometry
            geometriesTime = Float(gIndex) / Float(scene.cachedGeometries.count)
            switch geometry.type {
            case .line:
                if let lineGeometry = geometry as? Line {
                    let line = geometry.getPoints()
                    
                    testPoints.append(line[0])
                    testPoints.append(line[1])
                    
                    if lineGeometry.degree == 1 {
                        linesPtr[linearLinesIndex] = createShaderLinearSeg(
                            pathID: Int32(lineGeometry.pathID),
                            p0_world: line[0],
                            p1_world: line[1],
                            p0_width: lineGeometry.lineWidthStart,
                            p1_width: lineGeometry.lineWidthEnd,
                            colorStartCenter: lineGeometry.colorStart,
                            colorEndCenter: lineGeometry.colorEnd,
                            line: lineGeometry
                        )
                        linearLinesIndex += 1
                        
                    } else if lineGeometry.degree == 2 {
                        testPoints.append(lineGeometry.controlPoints[0])
                        
                        quadraticCurvesPtr[quadraticLinesIndex] = QuadraticSeg3D(
                            pathID: Int32(lineGeometry.pathID),
                            p0_world: SIMD4<Float>(line[0], 1.0),
                            p1_world: SIMD4<Float>(lineGeometry.controlPoints[0], 1.0),
                            p2_world: SIMD4<Float>(line[1], 1.0),
                            halfWidthStartPx: lineGeometry.lineWidthStart,
                            halfWidthEndPx: lineGeometry.lineWidthEnd,
                            aaPx: 0.707,
                            colorStartCenter: lineGeometry.colorStart,
                            colorEndCenter: lineGeometry.colorEnd
                        )
                        
                        quadraticLinesIndex += 1
                        
                    } else if lineGeometry.degree == 3 {
                        testPoints.append(lineGeometry.controlPoints[0])
                        testPoints.append(lineGeometry.controlPoints[1])
                        
                        cubicCurvesPtr[cubicLinesIndex] = CubicSeg3D(
                            pathID: Int32(lineGeometry.pathID),
                            p0_world: SIMD4<Float>(line[0], 1.0),
                            p1_world: SIMD4<Float>(lineGeometry.controlPoints[0], 1.0),
                            p2_world: SIMD4<Float>(lineGeometry.controlPoints[1], 1.0),
                            p3_world: SIMD4<Float>(line[1], 1.0),
                            halfWidthStartPx: lineGeometry.lineWidthStart,
                            halfWidthEndPx: lineGeometry.lineWidthEnd,
                            aaPx: 0.707,
                            colorStartCenter: lineGeometry.colorStart,
                            colorEndCenter: lineGeometry.colorEnd
                        )
                        
                        cubicLinesIndex += 1
                        
                    }
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
        
        
        // 1. Define the camera's properties
        
        let time = CACurrentMediaTime()
        var transitionFactor = Float(0.5 + 0.5 * sin(time))
        transitionFactor = renderConfigs?.projectionMix ?? transitionFactor
        
        let cameraDistance = renderConfigs?.cameraDistance ?? 5.0
        
        let FOVDivision: Float = renderConfigs?.FOVDivision ?? 3
        let fovY: Float = .pi / FOVDivision
        let nearZ: Float = 0.1
        let farZ:  Float = 100.0

        let eye = SIMD3<Float>(0, 0, cameraDistance)   // +Z
        let ctr = SIMD3<Float>(0, 0, 0)
        let up  = SIMD3<Float>(0, 1, 0)
        
        let V = matrix_lookAt_rh(eye: eye, target: ctr, up: up)
        let P = matrix_perspective_metal_rh(fovY: fovY, aspect: aspectRatio, nearZ: nearZ, farZ: farZ)

        //  // * focalDistance * tan((Float.pi / 3) / 2.0)
        let orthoHeight: Float = renderConfigs?.orthographicProjectionHeight ?? 2.0
        let orthoWidth = orthoHeight * aspectRatio
        
        let orthographicMatrix = matrix_orthographic(left: -orthoWidth / 2.0,
                                                  right: orthoWidth / 2.0,
                                                  bottom: -orthoHeight / 2.0,
                                                  top: orthoHeight / 2.0,
                                                  nearZ: -100.0,
                                                  farZ: 100.0)
        
        let projectionMatrix = (1.0 - transitionFactor) * orthographicMatrix + transitionFactor * P
        
        let flipY = float4x4(SIMD4<Float>( 1,  0, 0, 0),
                             SIMD4<Float>( 0, -1, 0, 0),
                             SIMD4<Float>( 0,  0, 1, 0),
                             SIMD4<Float>( 0,  0, 0, 1))
        
        // MVP = projectionMatrix * viewMatrix
        MVP = flipY * (projectionMatrix * V)
        
        let backgroundColor = renderConfigs?.backgroundColor ?? ColorInput()
        
        let lineDebugGradientStart = renderConfigs?.lineTimeDebugStartGradientColor ?? ColorInput()
        let lineDebugGradientEnd = renderConfigs?.lineTimeDebugEndGradientColor ?? ColorInput()
        
        // Convert to vector_float3
        
        let binDepthSource = renderConfigs?.binDepth ?? 16
        
        var uniforms: Uniforms = Uniforms(
            viewWidth: Int32(viewW),
            viewHeight: Int32(viewH),
            backgroundColor: colorToVector(backgroundColor.color),
            antiAliasPx: 0.808,
            debugBins: renderConfigs?.binGridVisibility ?? 0.0,
            binVisibility: renderConfigs?.binVisibility ?? 0.0,
            boundingBoxVisibility: renderConfigs?.boundingBoxVisibility ?? 0.0,
            lineColorStrength: renderConfigs?.lineColorStrength ?? 1.0,
            lineDebugGradientStrength: renderConfigs?.lineTimeDebugGradientStrength ?? 0.0,
            lineDebugGradientStartColor: colorToVector(lineDebugGradientStart.color),
            lineDebugGradientEndColor: colorToVector(lineDebugGradientEnd.color),
            blendRadius: renderConfigs?.blendRadius ?? 0.0,
            blendIntensity: renderConfigs?.blendIntensity ?? 0.0,
            previousColorVisibility: renderConfigs?.previousColorVisibility ?? 0.0
        )
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .load
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        
        let renderSDFLines = renderConfigs?.renderSDFLines ?? false
        
        var segCount: Int32 = Int32(gIndex)
        
        
        var segAlloc = SegAlloc(next: 0, capacity: uint32(10000));
        var segAllocPtr = segAllocBuffer.contents().bindMemory(to: SegAlloc.self, capacity: Int(1))
        // Reset to 0 for each frame
        segAllocPtr[0] = segAlloc
        
        if renderSDFLines {
            if let transformLinearEncoder = commandBuffer.makeComputeCommandEncoder() {
                transformLinearEncoder.setComputePipelineState(transformLinear!)
                transformLinearEncoder.setBuffer(linesBuffer,      offset:0, index:0)
                transformLinearEncoder.setBytes(&MVP,           length:MemoryLayout<float4x4>.stride, index:1)
                transformLinearEncoder.setBytes(&uniforms,      length:MemoryLayout<Uniforms>.stride, index:2)
                transformLinearEncoder.setBuffer(linearLinesScreenSpaceBuffer,      offset:0, index:3)
                transformLinearEncoder.setBuffer(binCounts,     offset:0, index:4)
                transformLinearEncoder.setBuffer(binOffsets,    offset:0, index:5)
                transformLinearEncoder.setBuffer(binList,       offset:0, index:6)
                transformLinearEncoder.setBytes(&segCount,       length: MemoryLayout<Int32>.stride, index:7)
                transformLinearEncoder.setBuffer(segAllocBuffer, offset: 0, index: 8);
                
                let tg = MTLSize(width: transformLinear!.threadExecutionWidth,
                                 height: 1,
                                 depth: 1)
                
                transformLinearEncoder.dispatchThreads(MTLSize(width: Int(lineCount), height: 1, depth: 1),
                                                 threadsPerThreadgroup: tg)
                transformLinearEncoder.endEncoding()          // ← guarantees completion before the next encoder
            }
            
            if let transformQuadraticEncoder = commandBuffer.makeComputeCommandEncoder() {
                transformQuadraticEncoder.setComputePipelineState(transformQuad!)
                transformQuadraticEncoder.setBuffer(quadraticCurvesBuffer, offset: 0, index: 0)
                transformQuadraticEncoder.setBytes(&MVP,           length:MemoryLayout<float4x4>.stride, index:1)
                transformQuadraticEncoder.setBytes(&uniforms,      length:MemoryLayout<Uniforms>.stride, index:2)
                transformQuadraticEncoder.setBuffer(linearLinesScreenSpaceBuffer,      offset:0, index:3)
                transformQuadraticEncoder.setBuffer(binCounts,     offset:0, index:4)
                transformQuadraticEncoder.setBuffer(binOffsets,    offset:0, index:5)
                transformQuadraticEncoder.setBuffer(binList,       offset:0, index:6)
                transformQuadraticEncoder.setBytes(&segCount,       length: MemoryLayout<Int32>.stride, index:7)
                transformQuadraticEncoder.setBuffer(segAllocBuffer, offset: 0, index: 8);
                
                let tg = MTLSize(width: transformLinear!.threadExecutionWidth,
                                 height: 1,
                                 depth: 1)
                
                transformQuadraticEncoder.dispatchThreads(MTLSize(width: Int(lineCount), height: 1, depth: 1),
                                                 threadsPerThreadgroup: tg)
                transformQuadraticEncoder.endEncoding()          // ← guarantees completion before the next encoder
            }
            
            if let transformCubicEncoder = commandBuffer.makeComputeCommandEncoder() {
                transformCubicEncoder.setComputePipelineState(transformCubic!)
                transformCubicEncoder.setBuffer(cubicCurvesBuffer, offset: 0, index: 0)
                transformCubicEncoder.setBytes(&MVP,           length:MemoryLayout<float4x4>.stride, index:1)
                transformCubicEncoder.setBytes(&uniforms,      length:MemoryLayout<Uniforms>.stride, index:2)
                transformCubicEncoder.setBuffer(linearLinesScreenSpaceBuffer,      offset:0, index:3)
                transformCubicEncoder.setBuffer(binCounts,     offset:0, index:4)
                transformCubicEncoder.setBuffer(binOffsets,    offset:0, index:5)
                transformCubicEncoder.setBuffer(binList,       offset:0, index:6)
                transformCubicEncoder.setBytes(&segCount,       length: MemoryLayout<Int32>.stride, index:7)
                transformCubicEncoder.setBuffer(segAllocBuffer, offset: 0, index: 8);
                
                let tg = MTLSize(width: transformLinear!.threadExecutionWidth,
                                 height: 1,
                                 depth: 1)
                
                transformCubicEncoder.dispatchThreads(MTLSize(width: Int(lineCount), height: 1, depth: 1),
                                                 threadsPerThreadgroup: tg)
                transformCubicEncoder.endEncoding()          // ← guarantees completion before the next encoder
            }
            
            
            
            
            if let drawLinesEncoder = commandBuffer.makeComputeCommandEncoder() {
                drawLinesEncoder.setComputePipelineState(renderPSO!)
                drawLinesEncoder.setTexture(writeTexture, index: 0)
                drawLinesEncoder.setBuffer(linearLinesScreenSpaceBuffer,      offset:0, index:0)
                drawLinesEncoder.setBuffer(binCounts,     offset:0, index:1)
                drawLinesEncoder.setBuffer(binOffsets,    offset:0, index:2)
                drawLinesEncoder.setBuffer(binList,       offset:0, index:3)
                drawLinesEncoder.setBytes(&uniforms,      length:MemoryLayout<Uniforms>.stride, index:4)
                
                let w  = renderPSO!.threadExecutionWidth
                let h  = renderPSO!.maxTotalThreadsPerThreadgroup / w
                
                // let tg2 = MTLSize(width: w, height: h, depth: 1)
                
                let tgsDrawLines = MTLSize(width: Int(BIN_SIZE), height: Int(BIN_SIZE), depth: 1)
                
                drawLinesEncoder.dispatchThreads(MTLSize(width: viewW, height: viewH, depth: 1),
                                                 threadsPerThreadgroup: tgsDrawLines)
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
        var vertexUniforms = [VertexUniforms(
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
        
        
        
        
        memcpy(uniformBuffer.contents(), vertexUniforms, MemoryLayout<VertexUniforms>.size)
        
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
