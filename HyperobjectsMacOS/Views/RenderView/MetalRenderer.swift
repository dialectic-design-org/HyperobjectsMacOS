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

struct ChromaticAberrationParams {
    var intensity: Float
    var redOffset: Float
    var greenOffset: Float
    var blueOffset: Float
    var radialPower: Float
    var useRadialMode: Int32
    var direction: SIMD2<Float>
    var useSpectralMode: Int32
    var dispersionStrength: Float
    var referenceWavelength: Float
}

struct SegAlloc {
    var next: uint32
    var capacity: uint32
}

let maxMicroSegPerQuad  = 16
let maxMicroSegPerCubic = 24

// MARK: - Render Override Helpers

extension MetalRenderer {
    /// Resolves a config value: returns override if non-nil, otherwise UI value
    func resolve<T>(_ override: T?, _ uiValue: T) -> T {
        override ?? uiValue
    }

    /// Gets effective overrides by merging geometry-time and render-time
    func getEffectiveOverrides(base: RenderConfigurationOverrides) -> RenderConfigurationOverrides {
        guard let scene = currentScene else { return .none }

        var combined = base

        if let renderTimeClosure = scene.renderTimeOverride {
            let context = scene.makeOverrideContext()
            combined = combined.merged(with: renderTimeClosure(context))
        }

        return combined
    }
}

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
// private let lineCount: UInt32 = 10000 // REMOVED: Now an instance variable


// ADD: helper to compute a legal, efficient threadsPerThreadgroup for this pipeline
private func safeThreadsPerThreadgroup(_ pso: MTLComputePipelineState,
                                       preferred: MTLSize = MTLSize(width: 32, height: 32, depth: 1)) -> MTLSize {
    // Keep width a multiple of SIMD width for best occupancy.
    var w = max(1, pso.threadExecutionWidth)
    var maxTotal = max(1, pso.maxTotalThreadsPerThreadgroup) // e.g. 896 for your kernel

    // If the kernel is so heavy that maxTotal < threadExecutionWidth, clamp width to maxTotal.
    if maxTotal < w { w = maxTotal }

    // Start from preferred height but clamp to what fits under the cap.
    let hCap = max(1, maxTotal / w)                // maximum legal height for chosen width
    var h = min(preferred.height, hCap)

    // Also respect per-dimension limits that some GPUs enforce (defensive).
    let perDimLimit = 1024                         // safe conservative cap per axis on Apple GPUs
    w = min(w, perDimLimit)
    h = min(h, perDimLimit)

    // If preferred width was smaller than SIMD width (unlikely), lift it to SIMD width.
    var width = max(w, preferred.width - (preferred.width % w == 0 ? 0 : preferred.width % w))
    if width == 0 { width = w }                    // ensure non-zero and multiple of SIMD width

    // Ensure total threads <= cap; reduce height if needed.
    while width * h > maxTotal && h > 1 { h -= 1 }
    if h < 1 { h = 1 }                             // final guard

    return MTLSize(width: width, height: h, depth: 1)
}


private struct FrameResources {
    var linesBuffer: MTLBuffer
    var quadraticCurvesBuffer: MTLBuffer
    var cubicCurvesBuffer: MTLBuffer
    var linearLinesScreenSpaceBuffer: MTLBuffer
    var randomValuesBuffer: MTLBuffer
    var binCounts: MTLBuffer
    var binOffsets: MTLBuffer
    var binList: MTLBuffer
    var segAllocBuffer: MTLBuffer
}

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

    // DYNAMIC BUFFER SIZING
    private var lineCount: Int = 10000

    // TRIPLE BUFFERING
    private let maxFramesInFlight = 3
    private let frameSemaphore = DispatchSemaphore(value: 3)
    private var frameResourceRing: [FrameResources] = []
    private var currentFrameIndex = 0
    
    
    
    private var currentTextureWidth: Int = 0
    private var currentTextureHeight: Int = 0
    
    var rotation: Float = 0.0
    var drawCounter: Int = 0
    
    // Reference to the state
    weak var rendererState: RendererState?

    // Video streaming (Syphon / NDI)
    var videoStreamManager: VideoStreamManager?
    
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
    
    private func createLineBuffers() {
        let binCols = (maxViewSize + Int(BIN_SIZE) - 1) / Int(BIN_SIZE)
        let binRows = (maxViewSize + Int(BIN_SIZE) - 1) / Int(BIN_SIZE)
        let totalBins = binCols * binRows

        frameResourceRing = (0..<maxFramesInFlight).map { _ in
            FrameResources(
                linesBuffer: device.makeBuffer(length: MemoryLayout<LinearSeg3D>.stride * lineCount, options: .storageModeShared)!,
                quadraticCurvesBuffer: device.makeBuffer(length: MemoryLayout<QuadraticSeg3D>.stride * lineCount, options: .storageModeShared)!,
                cubicCurvesBuffer: device.makeBuffer(length: MemoryLayout<CubicSeg3D>.stride * lineCount, options: .storageModeShared)!,
                linearLinesScreenSpaceBuffer: device.makeBuffer(length: MemoryLayout<LinearSegScreenSpace>.stride * lineCount, options: .storageModeShared)!,
                randomValuesBuffer: device.makeBuffer(length: MemoryLayout<SIMD4<Float>>.stride * 1000, options: .storageModeShared)!,
                binCounts: device.makeBuffer(length: MemoryLayout<UInt32>.stride * totalBins, options: .storageModeShared)!,
                binOffsets: device.makeBuffer(length: MemoryLayout<UInt32>.stride * totalBins, options: .storageModeShared)!,
                binList: device.makeBuffer(length: MemoryLayout<UInt32>.stride * lineCount * totalBins, options: .storageModeShared)!,
                segAllocBuffer: device.makeBuffer(length: MemoryLayout<SegAlloc>.stride, options: .storageModeShared)!
            )
        }
        print("Allocated triple-buffered resources for \(lineCount) lines.")
    }
    
    private func updateBufferCapacity(required: Int) {
        let minCapacity = 10000

        if required > lineCount {
            let oldLineCount = lineCount
            lineCount = max(required, lineCount * 2)
            print("⚠️ Growing buffers: \(oldLineCount) -> \(lineCount) lines (Required: \(required))")
            drainFrameSemaphore()
            createLineBuffers()
        } else if required < lineCount / 4 && lineCount > minCapacity {
            let oldLineCount = lineCount
            lineCount = max(minCapacity, required * 2)
            print("♻️ Shrinking buffers: \(oldLineCount) -> \(lineCount) lines (Required: \(required))")
            drainFrameSemaphore()
            createLineBuffers()
        }
    }

    /// Wait for all in-flight frames to complete before resizing buffers
    private func drainFrameSemaphore() {
        for _ in 0..<maxFramesInFlight {
            frameSemaphore.wait()
        }
        for _ in 0..<maxFramesInFlight {
            frameSemaphore.signal()
        }
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

        // Create triple-buffered line resources
        createLineBuffers()
        
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
        // Block if 3 frames are already in flight
        frameSemaphore.wait()

        guard let renderPipelineState = renderPipelineState,
              let computeToRenderPipelineState = computeToRenderPipelineState,
              let vertexBuffer = vertexBuffer,
              let indexBuffer = indexBuffer,
              let uniformBuffer = uniformBuffer,
              !frameResourceRing.isEmpty,
              let scene = currentScene else {
            frameSemaphore.signal()
            return
        }

        // Request fresh geometry generation for the next frame
        scene.requestGeometryGeneration()

        let snapshot = scene.renderBuffer.consume()

        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            frameSemaphore.signal()
            return
        }

        // Get effective overrides (merged geometry-time + render-time)
        let overrides = getEffectiveOverrides(base: snapshot.renderOverrides)

        // DYNAMIC BUFFER SIZING: Ensure we have enough space (must happen before frame selection)
        let totalLineCount = snapshot.geometries.count
        updateBufferCapacity(required: totalLineCount)

        // Select this frame's buffer set (after potential resize)
        let frame = frameResourceRing[currentFrameIndex % maxFramesInFlight]
        currentFrameIndex += 1
        
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
        
        let linesPtr = frame.linesBuffer.contents().bindMemory(to: LinearSeg3D.self, capacity: lineCount)

        let quadraticCurvesPtr = frame.quadraticCurvesBuffer.contents().bindMemory(to: QuadraticSeg3D.self, capacity: lineCount)

        let cubicCurvesPtr = frame.cubicCurvesBuffer.contents().bindMemory(to: CubicSeg3D.self, capacity: lineCount)

        let randomValuesPtr = frame.randomValuesBuffer.contents().bindMemory(to: SIMD4<Float>.self, capacity: Int(1000))

        
        
        var gIndex: Int = 0
        
        var geometriesTime: Float = 0.0
        
        var linearLinesIndex: Int = 0
        var quadraticLinesIndex: Int = 0
        var cubicLinesIndex: Int = 0
        
        for gWrapped in snapshot.geometries {
            let geometry = gWrapped.geometry
            geometriesTime = Float(gIndex) / Float(snapshot.geometries.count)
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
                            noiseFloor: lineGeometry.noiseFloor,
                            colorStartCenter: lineGeometry.colorStart,
                            colorEndCenter: lineGeometry.colorEnd,
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
                            noiseFloor: lineGeometry.noiseFloor,
                            colorStartCenter: lineGeometry.colorStart,
                            colorEndCenter: lineGeometry.colorEnd,
                        )
                        
                        cubicLinesIndex += 1
                        
                    }
                }
                
            default:
                let notImplementedError = "Not implemented yet"
            }
            gIndex += 1
        }
        
        if (testPoints.count == 0) {
            print("TEST POINTS IS ZERO!")
            // Temporarily set to ensure buffer isn't empty
            testPoints = [
                SIMD3<Float>(0.0, 0.0, 0.0),
                SIMD3<Float>(-0.1, 0.0, 0.0),
                SIMD3<Float>(-0.05, 0.1, 0.0)
            ]
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
        
        let binCountsPtr = frame.binCounts.contents().bindMemory(to: UInt32.self, capacity: totalBins)
        let binOffsetsPtr = frame.binOffsets.contents().bindMemory(to: UInt32.self, capacity: totalBins)
        var offset: UInt32 = 0
        for i in 0..<totalBins {
            binCountsPtr[i] = 0
            binOffsetsPtr[i] = offset
            offset += UInt32(lineCount) // Each bin can potentially hold all lines
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
        
        
        for i in 0..<1000 {
            let r = {
                Float(arc4random_uniform(10000)) / 10000.0
            }
            // randomVecs = vector_float4(r(), r(), r(), r())
            randomValuesPtr[i] = SIMD4<Float>(r(), r(), r(), r())
        }
        
        var backgroundColorVector: SIMD3<Float> = {
            if let override = overrides.backgroundColor {
                return override
            }
            if scene.sceneHasBackgroundColor {
                return scene.backgroundColor
            }
            return colorToVector(backgroundColor.color)
        }()

        var uniforms: Uniforms = Uniforms(
            viewWidth: Int32(viewW),
            viewHeight: Int32(viewH),
            backgroundColor: backgroundColorVector,
            antiAliasPx: 0.808,
            debugBins: renderConfigs?.binGridVisibility ?? 0.0,
            binVisibility: renderConfigs?.binVisibility ?? 0.0,
            boundingBoxVisibility: renderConfigs?.boundingBoxVisibility ?? 0.0,
            lineColorStrength: resolve(overrides.lineColorStrength, renderConfigs?.lineColorStrength ?? 1.0),
            lineDebugGradientStrength: renderConfigs?.lineTimeDebugGradientStrength ?? 0.0,
            lineDebugGradientStartColor: colorToVector(lineDebugGradientStart.color),
            lineDebugGradientEndColor: colorToVector(lineDebugGradientEnd.color),
            blendRadius: resolve(overrides.blendRadius, renderConfigs?.blendRadius ?? 0.0),
            blendIntensity: resolve(overrides.blendIntensity, renderConfigs?.blendIntensity ?? 0.0),
            previousColorVisibility: resolve(overrides.previousColorVisibility, renderConfigs?.previousColorVisibility ?? 0.0)
        )
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .load
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        
        let renderSDFLines = renderConfigs?.renderSDFLines ?? false
        
        var linearCount: Int32 = Int32(linearLinesIndex)
        var quadraticCount: Int32 = Int32(quadraticLinesIndex)
        var cubicCount: Int32 = Int32(cubicLinesIndex)
        
        
        var segAlloc = SegAlloc(next: 0, capacity: uint32(lineCount));
        var segAllocPtr = frame.segAllocBuffer.contents().bindMemory(to: SegAlloc.self, capacity: Int(1))
        // Reset to 0 for each frame
        segAllocPtr[0] = segAlloc
        
        if renderSDFLines {
            if linearLinesIndex > 0, let transformLinearEncoder = commandBuffer.makeComputeCommandEncoder() {
                transformLinearEncoder.setComputePipelineState(transformLinear!)
                transformLinearEncoder.setBuffer(frame.linesBuffer,      offset:0, index:0)
                transformLinearEncoder.setBytes(&MVP,           length:MemoryLayout<float4x4>.stride, index:1)
                transformLinearEncoder.setBytes(&uniforms,      length:MemoryLayout<Uniforms>.stride, index:2)
                transformLinearEncoder.setBuffer(frame.linearLinesScreenSpaceBuffer,      offset:0, index:3)
                transformLinearEncoder.setBuffer(frame.binCounts,     offset:0, index:4)
                transformLinearEncoder.setBuffer(frame.binOffsets,    offset:0, index:5)
                transformLinearEncoder.setBuffer(frame.binList,       offset:0, index:6)
                transformLinearEncoder.setBytes(&linearCount,       length: MemoryLayout<Int32>.stride, index:7)
                transformLinearEncoder.setBuffer(frame.segAllocBuffer, offset: 0, index: 8)
                transformLinearEncoder.setBuffer(frame.randomValuesBuffer, offset: 0, index: 9)

                let tg = MTLSize(width: transformLinear!.threadExecutionWidth,
                                 height: 1,
                                 depth: 1)

                transformLinearEncoder.dispatchThreads(MTLSize(width: linearLinesIndex, height: 1, depth: 1),
                                                 threadsPerThreadgroup: tg)
                transformLinearEncoder.endEncoding()
            }

            if quadraticLinesIndex > 0, let transformQuadraticEncoder = commandBuffer.makeComputeCommandEncoder() {
                transformQuadraticEncoder.setComputePipelineState(transformQuad!)
                transformQuadraticEncoder.setBuffer(frame.quadraticCurvesBuffer, offset: 0, index: 0)
                transformQuadraticEncoder.setBytes(&MVP,           length:MemoryLayout<float4x4>.stride, index:1)
                transformQuadraticEncoder.setBytes(&uniforms,      length:MemoryLayout<Uniforms>.stride, index:2)
                transformQuadraticEncoder.setBuffer(frame.linearLinesScreenSpaceBuffer,      offset:0, index:3)
                transformQuadraticEncoder.setBuffer(frame.binCounts,     offset:0, index:4)
                transformQuadraticEncoder.setBuffer(frame.binOffsets,    offset:0, index:5)
                transformQuadraticEncoder.setBuffer(frame.binList,       offset:0, index:6)
                transformQuadraticEncoder.setBytes(&quadraticCount,       length: MemoryLayout<Int32>.stride, index:7)
                transformQuadraticEncoder.setBuffer(frame.segAllocBuffer, offset: 0, index: 8)
                transformQuadraticEncoder.setBuffer(frame.randomValuesBuffer, offset: 0, index: 9)

                let tg = MTLSize(width: transformLinear!.threadExecutionWidth,
                                 height: 1,
                                 depth: 1)

                transformQuadraticEncoder.dispatchThreads(MTLSize(width: quadraticLinesIndex, height: 1, depth: 1),
                                                 threadsPerThreadgroup: tg)
                transformQuadraticEncoder.endEncoding()
            }

            if cubicLinesIndex > 0, let transformCubicEncoder = commandBuffer.makeComputeCommandEncoder() {
                transformCubicEncoder.setComputePipelineState(transformCubic!)
                transformCubicEncoder.setBuffer(frame.cubicCurvesBuffer, offset: 0, index: 0)
                transformCubicEncoder.setBytes(&MVP,           length:MemoryLayout<float4x4>.stride, index:1)
                transformCubicEncoder.setBytes(&uniforms,      length:MemoryLayout<Uniforms>.stride, index:2)
                transformCubicEncoder.setBuffer(frame.linearLinesScreenSpaceBuffer,      offset:0, index:3)
                transformCubicEncoder.setBuffer(frame.binCounts,     offset:0, index:4)
                transformCubicEncoder.setBuffer(frame.binOffsets,    offset:0, index:5)
                transformCubicEncoder.setBuffer(frame.binList,       offset:0, index:6)
                transformCubicEncoder.setBytes(&cubicCount,       length: MemoryLayout<Int32>.stride, index:7)
                transformCubicEncoder.setBuffer(frame.segAllocBuffer, offset: 0, index: 8)
                transformCubicEncoder.setBuffer(frame.randomValuesBuffer, offset: 0, index: 9)

                let tg = MTLSize(width: transformLinear!.threadExecutionWidth,
                                 height: 1,
                                 depth: 1)

                transformCubicEncoder.dispatchThreads(MTLSize(width: cubicLinesIndex, height: 1, depth: 1),
                                                 threadsPerThreadgroup: tg)
                transformCubicEncoder.endEncoding()
            }
            
            
            
            
            if let drawLinesEncoder = commandBuffer.makeComputeCommandEncoder() {
                drawLinesEncoder.setComputePipelineState(renderPSO!)
                drawLinesEncoder.setTexture(writeTexture, index: 0)
                drawLinesEncoder.setBuffer(frame.linearLinesScreenSpaceBuffer,      offset:0, index:0)
                drawLinesEncoder.setBuffer(frame.binCounts,     offset:0, index:1)
                drawLinesEncoder.setBuffer(frame.binOffsets,    offset:0, index:2)
                drawLinesEncoder.setBuffer(frame.binList,       offset:0, index:3)
                drawLinesEncoder.setBytes(&uniforms,      length:MemoryLayout<Uniforms>.stride, index:4)
                drawLinesEncoder.setBuffer(frame.randomValuesBuffer, offset: 0, index: 5)
                
                let w  = renderPSO!.threadExecutionWidth
                let h  = renderPSO!.maxTotalThreadsPerThreadgroup / w
                
                // let tg2 = MTLSize(width: w, height: h, depth: 1)
                
                let tgsDrawLines = MTLSize(width: Int(BIN_SIZE), height: Int(BIN_SIZE), depth: 1)
                
                let tptg = safeThreadsPerThreadgroup(renderPSO!, preferred: MTLSize(width: 32, height: 32, depth: 1))

                
                // drawLinesEncoder.dispatchThreads(MTLSize(width: viewW, height: viewH, depth: 1), threadsPerThreadgroup: tgsDrawLines)
                drawLinesEncoder.dispatchThreads(MTLSize(width: viewW, height: viewH, depth: 1), threadsPerThreadgroup: tptg)
                drawLinesEncoder.endEncoding()
            }
        }
        
        
        // FURTHER RENDER PASS
        let computeToRenderRenderPassDescriptor = MTLRenderPassDescriptor()
        computeToRenderRenderPassDescriptor.colorAttachments[0].texture = drawable.texture
        computeToRenderRenderPassDescriptor.colorAttachments[0].loadAction = .clear
        computeToRenderRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        // computeToRenderRenderPassDescriptor.colorAttachments[0].storeAction = .store
        
        guard let computeToRenderRenderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: computeToRenderRenderPassDescriptor) else {
            frameSemaphore.signal()
            return
        }
        
        computeToRenderRenderEncoder.setRenderPipelineState(computeToRenderPipelineState)
        computeToRenderRenderEncoder.setFragmentTexture(readTexture, index: 0)

        // Create CA params from RenderConfigurations with overrides
        let caEnabled = resolve(overrides.chromaticAberrationEnabled, renderConfigs?.chromaticAberrationEnabled ?? false)
        let caAngle = resolve(overrides.chromaticAberrationAngle, renderConfigs?.chromaticAberrationAngle ?? 0.0)

        var caParams = ChromaticAberrationParams(
            intensity: caEnabled
                ? resolve(overrides.chromaticAberrationIntensity, renderConfigs?.chromaticAberrationIntensity ?? 0.0)
                : 0.0,
            redOffset: resolve(overrides.chromaticAberrationRedOffset, renderConfigs?.chromaticAberrationRedOffset ?? -2.0),
            greenOffset: resolve(overrides.chromaticAberrationGreenOffset, renderConfigs?.chromaticAberrationGreenOffset ?? 0.0),
            blueOffset: resolve(overrides.chromaticAberrationBlueOffset, renderConfigs?.chromaticAberrationBlueOffset ?? 2.0),
            radialPower: resolve(overrides.chromaticAberrationRadialPower, renderConfigs?.chromaticAberrationRadialPower ?? 2.0),
            useRadialMode: resolve(overrides.chromaticAberrationUseRadialMode, renderConfigs?.chromaticAberrationUseRadialMode ?? true) ? 1 : 0,
            direction: SIMD2<Float>(cos(caAngle), sin(caAngle)),
            useSpectralMode: resolve(overrides.chromaticAberrationUseSpectralMode, renderConfigs?.chromaticAberrationUseSpectralMode ?? true) ? 1 : 0,
            dispersionStrength: resolve(overrides.chromaticAberrationDispersionStrength, renderConfigs?.chromaticAberrationDispersionStrength ?? 5.0),
            referenceWavelength: resolve(overrides.chromaticAberrationReferenceWavelength, renderConfigs?.chromaticAberrationReferenceWavelength ?? 550.0)
        )

        computeToRenderRenderEncoder.setFragmentBytes(
            &caParams,
            length: MemoryLayout<ChromaticAberrationParams>.stride,
            index: 0
        )

        computeToRenderRenderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        
        computeToRenderRenderEncoder.endEncoding()
        
        
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            frameSemaphore.signal()
            return
        }
        
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
        ) else {
            frameSemaphore.signal()
            return
        }
        
        
        
        
        memcpy(uniformBuffer.contents(), vertexUniforms, MemoryLayout<VertexUniforms>.size)
        
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        
        
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
        
        renderEncoder.endEncoding()

        // Publish frame to Syphon/NDI before presenting
        videoStreamManager?.publishFrame(commandBuffer: commandBuffer, sourceTexture: drawable.texture)

        commandBuffer.addCompletedHandler { [weak self] _ in
            self?.frameSemaphore.signal()
        }
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
