//
//  SwarmGenerator.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 07/03/2026.
//

import Foundation

class SwarmGenerator: CachedGeometryGenerator {
    init() {
        super.init(name: "Swarm Generator", inputDependencies: ["Brightness"])
    }
    
    override func generateGeometriesFromInputs(inputs: [String : Any], withScene scene: GeometriesSceneBase) -> [any Geometry] {
        var lines: [Line] = []
        
        
        // ELEMENTS
        // Boids
        
        // Selected boid
        // Boid pair
        // boid cluster
        
        // *connecting lines*
        // boids to perceived boids connecting lines: PerceptionLines
        // boids to N nearest boids connecting lines: NearestNLines
        // selected boid to nearest boids connecting lines: SelectedNearestNLines
        // boid pair connecting line: PairLine
        // boid pair nearest boids connecting lines
        // boid cluster connecting lines
        // boid cluster to nearest boids connecting lines
        
        // boids bounding box
        // boid pair bounding box
        // boid cluster bounding box
        
        // Boid traces
        
        
        // INPUTS
        // Camera mode:
        // World center
        // Selected agent
        // Cluster
        // Pair
        
        
        // Styling
        
        // > Boids general styling
        // Coloring
        // Line width
        // Shape
        
        // > PerceptionLines all styling
        // Coloring
        
        
        // > Selected boid styling
        // Coloring
        // Line width
        // Shape
        
        // > Boid cluster styling
        // Coloring
        // Line width
        // Shape
        
        
        
        
        
        
        
        
        
        // Extract Cube rendering parameters
        
        
        // Extract camera positioning and behaviour parameters
        
        
        // Extract swarm simulation parameters
        
        
        // Apply swarm modifications on previous swarm state
        
        
        // Simulate swarm
        
        
        
        // Generate direct swarm boid geometries
        
        
        // Apply global boid styling
        
        
        // Select specific boids for custom styling
        
        
        // Generate global differential boid geometries (e.g. traces)
        
        
        // Generate select differential boid geometries (e.g. traces)
        
        
        // Generate global inter-boid geometries (e.g. nearness vectors)
        
        
        // Generate select inter-boid geometries (e.g. nearness vectors)
        
        let selectedBoidIndex = intFromInputs(inputs, name: "SelectedBoidIndex")
        let boidPairAIndex = intFromInputs(inputs, name: "BoidPairAIndex")
        let boidPairBIndex = intFromInputs(inputs, name: "BoidPairBIndex")
        
        let boidsClusterStartIndex = intFromInputs(inputs, name: "BoidsClusterStartNr")
        let boidsClusterEndIndex = intFromInputs(inputs, name: "BoidsClusterEndNr")
        
        let showBoidsBodies = stringFromInputs(inputs, name: "BoidsBodies") == "SHOW"
        let showPerceptionLines = stringFromInputs(inputs, name: "PerceptionLines") == "SHOW"
        let showAllBoidsBounds = stringFromInputs(inputs, name: "AllBoidsBounds") == "SHOW"
        let showBoidsClusterBounds = stringFromInputs(inputs, name: "BoidsClusterBounds") == "SHOW"
        let showBoidsPairBounds = stringFromInputs(inputs, name: "BoidsPairBounds") == "SHOW"
        
        
        let sceneRotationY = floatFromInputs(inputs, name: "Stateful_Rotation_X")
        let boundarySize = floatFromInputs(inputs, name: "BoundarySize")
        
        let boidsCount = intFromInputs(inputs, name: "BoidsCount")
        let boidsTraceInterval = intFromInputs(inputs, name: "BoidsTraceInterval")
        
        
        
        // Colors
        
        
        
        
        var brightnessInput = scene.getInputWithName(name: "Brightness")
        
        var outputLines: [Line] = []
        
        // Resolve current time as Double to avoid colliding with C time() symbol
        let currentTime: Double = Date().timeIntervalSinceReferenceDate
        
        // 1. Initialize logic
        let sim = FishSchoolSimulation.shared
        if !sim.isInitialized {
            sim.initialize(count: boidsCount)
        }
        
        if sim.agents.count != boidsCount {
            sim.initialize(count: boidsCount)
        }
        
        
        sim.boundarySize = boundarySize
        
        
        
        // 2. Physics Step
        // Use a semi-fixed timestep assumption or just run once per generate call
        let dt = ensureValueIsFloat(scene.getInputWithName(name: "Sim_dt").getHistoryValue(millisecondsAgo: 0))
        sim.update(dt: dt,
                   time: currentTime,
                   speedInput: scene.getInputWithName(name: "AddedSpeed"),
                   delayInput: scene.getInputWithName(name: "AddedSpeedDelay")) // dt=0.05 makes it lively
        
        // 3. Geometry Generation
        // Create a base cube to clone logic from
        // Center 0, 0, 0, size 1.0 (we will scale it)
        
        
        // Pre-calculate up vector for look-at
        let up = SIMD3<Float>(0, 1, 0)
        
        let outputScale = matrix_scale(scale: SIMD3<Float>(repeating: 0.15))
        
        
        let traceStartColor = SIMD4<Float>(
            scene.val_f(name: "AllBoidsTraceStartR"),
            scene.val_f(name: "AllBoidsTraceStartG"),
            scene.val_f(name: "AllBoidsTraceStartB"),
            scene.val_f(name: "AllBoidsTraceStartA"))
        let traceEndColor = SIMD4<Float>(
            scene.val_f(name: "AllBoidsTraceEndR"),
            scene.val_f(name: "AllBoidsTraceEndG"),
            scene.val_f(name: "AllBoidsTraceEndB"),
            scene.val_f(name: "AllBoidsTraceEndA"))
        
        let traceStartOKLCH = OKLCH(simd: traceStartColor)
        let traceEndOKLCH = OKLCH(simd: traceEndColor)
        
        
        let organicR = scene.getInputWithName(name: "BoidsOrganicR")
        let organicG = scene.getInputWithName(name: "BoidsOrganicG")
        let organicB = scene.getInputWithName(name: "BoidsOrganicB")
        let organicA = scene.getInputWithName(name: "BoidsOrganicA")
        let organicTotal = scene.getInputWithName(name: "BoidsOrganicTotal")
        
        
        for agent in sim.agents {
            let speed = length(agent.velocity)
            let direction = speed > 0.001 ? normalize(agent.velocity) : SIMD3<Float>(0, 0, 1)
            
            // Build Rotation Matrix (LookAt)
            // Z-axis points in direction of velocity
            let zAxis = direction
            var xAxis = normalize(cross(up, zAxis))
            if length(xAxis) < 0.001 {
                // handle parallel case
                xAxis = SIMD3<Float>(1, 0, 0)
            }
            let yAxis = cross(zAxis, xAxis)
            
            let rotationMatrix = matrix_float4x4(
                columns: (
                    SIMD4<Float>(xAxis, 0),
                    SIMD4<Float>(yAxis, 0),
                    SIMD4<Float>(zAxis, 0),
                    SIMD4<Float>(0, 0, 0, 1)
                )
            )
            
            // Muscle / Deformation Logic
            // Strech based on speed ("Muscle Exertion")
            // Breathing / Pulse effect
            let pulse = 1.0 + sin(Float(currentTime) * 4.0 + Float(agent.id)) * 0.1
            let lengthScale = (0.5 + speed * 0.2) * pulse
            let widthScale = (0.5 - speed * 0.05) * pulse // Conservation of volume-ish
            
            let scaleMatrix = matrix_float4x4(diagonal: SIMD4<Float>(widthScale, widthScale, lengthScale, 1.0))
            
            // Translation
            let translationMatrix = matrix_float4x4(
                columns: (
                    SIMD4<Float>(1, 0, 0, 0),
                    SIMD4<Float>(0, 1, 0, 0),
                    SIMD4<Float>(0, 0, 1, 0),
                    SIMD4<Float>(agent.position, 1)
                )
            )
            
            // Combine: T * R * S
            let finalMatrix = outputScale * translationMatrix * rotationMatrix * scaleMatrix
            
            // Color Logic: Slow Cycle + Chromatic Audio Brightness
            
            // 1. Base Gradient Cycle (Blue -> Purple -> Pink -> Yellow)
            // Cycle depends on time and agent ID for individuality
            let cycleT = (currentTime * 0.2 + Double(agent.id) * 0.05).truncatingRemainder(dividingBy: 4.0)
            
            let blue = SIMD4<Float>(0.1, 0.2, 0.9, 1)
            let purple = SIMD4<Float>(0.5, 0.1, 0.9, 1)
            let pink = SIMD4<Float>(1.0, 0.2, 0.6, 1)
            let yellow = SIMD4<Float>(1.0, 0.9, 0.2, 1)
            
            var baseColor = blue
            let phase = Int(cycleT)
            let tMix = Float(cycleT.truncatingRemainder(dividingBy: 1.0))
            
            switch phase {
            case 0: baseColor = mix(blue, purple, t: tMix)
            case 1: baseColor = mix(purple, pink, t: tMix)
            case 2: baseColor = mix(pink, yellow, t: tMix)
            case 3: baseColor = mix(yellow, blue, t: tMix)
            default: baseColor = blue
            }
            
            // 2. Chromatic Audio Brightness
            // Different delays for R, G, B components to create chromatic aberration on transients
            // Normalized ID 0..1 assuming ~100 agents
            let normID = Double(agent.id) / 100.0
            
            func getFloat(_ val: Any?) -> Float {
                if let v = val as? Float { return v }
                if let v = val as? Double { return Float(v) }
                if let v = val as? Int { return Float(v) }
                return 0.0
            }
            
            let rDelay = normID * 50.0
            let gDelay = 35.0 + normID * 35.0
            let bDelay = 70.0 + normID * 50.0
            
            let rVal = getFloat(brightnessInput.getHistoryValue(millisecondsAgo: rDelay)) * getFloat(organicR.getHistoryValue(millisecondsAgo: 0))
            let gVal = getFloat(brightnessInput.getHistoryValue(millisecondsAgo: gDelay)) * getFloat(organicG.getHistoryValue(millisecondsAgo: 0))
            let bVal = getFloat(brightnessInput.getHistoryValue(millisecondsAgo: bDelay)) * getFloat(organicB.getHistoryValue(millisecondsAgo: 0))
            
            let minLight: Float = 0.3
            let chromaticBrightness = SIMD4<Float>(
                rVal * 2.0 + minLight,
                gVal * 2.0 + minLight,
                bVal * 2.0 + minLight,
                1.0
            )
            
            var organicColor = baseColor * chromaticBrightness * getFloat(organicTotal.getHistoryValue(millisecondsAgo: 0))
            
            
            // Desaturate into dark gray on the darker side
            let luminance = dot(SIMD3<Float>(organicColor.x, organicColor.y, organicColor.z), SIMD3<Float>(0.299, 0.587, 0.114))
            let grayScale = SIMD4<Float>(luminance, luminance, luminance, 1.0)
            
            // Smoothly blend to gray when luminance is low
            // < 0.25 luminance -> fully gray, > 0.55 luminance -> fully colored
            let tSat = max(0.0, min(1.0, (luminance - 0.25) / 0.3))
            organicColor = mix(organicColor, organicColor, t: tSat)
            
            organicColor.w = 1.0
            
            
            var baseBrightnessColor = SIMD4<Float>(repeating: getFloat(brightnessInput.getHistoryValue(millisecondsAgo: normID * 1000))) * 0.1
            
            let baseBoidsIndexDelay = scene.val_f(name: "BoidsBaseIndexDelay")
            
            let baseRDelay = scene.val_f(name: "BoidsBaseR_IndexDelay") * 1000
            let baseGDelay = scene.val_f(name: "BoidsBaseG_IndexDelay") * 1000
            let baseBDelay = scene.val_f(name: "BoidsBaseB_IndexDelay") * 1000
            let baseADelay = scene.val_f(name: "BoidsBaseA_IndexDelay") * 1000
            
            let baseBoidsColor = SIMD4<Float>(
                scene.val_f(name: "BoidsBaseR", delay: Double(baseRDelay)),
                scene.val_f(name: "BoidsBaseG", delay: Double(baseGDelay)),
                scene.val_f(name: "BoidsBaseB", delay: Double(baseBDelay)),
                scene.val_f(name: "BoidsBaseA", delay: Double(baseADelay))
            )
            
            var finalColor = organicColor + baseBrightnessColor + baseBoidsColor
            
            let baseCube = Cube(center: SIMD3<Float>(0, 0, 0), size: 1.0)
            let baseLines = baseCube.wallOutlines()

            // Apply to lines
            for line in baseLines {
                var transformedLine = line
                transformedLine = transformedLine.applyMatrix(finalMatrix)
                
                transformedLine.lineWidthStart = 1.5
                transformedLine.lineWidthEnd = 1.5
                
                // Apply color
                transformedLine.colorStart = finalColor
                transformedLine.colorEnd = finalColor
                transformedLine.colorStartOuterLeft = finalColor
                transformedLine.colorStartOuterRight = finalColor
                transformedLine.colorEndOuterLeft = finalColor
                transformedLine.colorEndOuterRight = finalColor
                
                outputLines.append(transformedLine)
            }
            
            
            // Agent traces
            if agent.id % boidsTraceInterval == 0 {
                
                
                for i in agent.positionHistory.indices.dropFirst() {
                    let traceT = Float(i) / Float(agent.positionHistory.count - 1)
                    if i % 1 == 0 && traceT < scene.val_f(name: "AllBoidsTraceLengthFactor", delay: Double(traceT) * 1000) {
                        let prevPos = agent.positionHistory[i - 1]
                        let pos = agent.positionHistory[i]
                        let traceT = Float(i) / Float(agent.positionHistory.count - 1)
                        let traceTdt = Float(1.0) / Float(agent.positionHistory.count - 1)
                        
                        let startColor = traceStartOKLCH.lerp(to: traceEndOKLCH, t: traceT)
                        let endColor = traceStartOKLCH.lerp(to: traceEndOKLCH, t: traceT + traceTdt)
                        
                        var line = Line(startPoint: prevPos, endPoint: pos)
                        line.setBasicEndPointColors(startColor: startColor.simd4(alpha: 1.0), endColor: endColor.simd4(alpha: 1.0))
                        line.lineWidthStart = 1.5
                        line.lineWidthEnd = 1.5
                        line = line.applyMatrix(outputScale)
                        
                        outputLines.append(line)
                    }
                }
            }
        }
        
        lines = outputLines
        
        
        // Perception lines
        var perceptions = sim.perceptionsAgents()
        
        let perceptionLineColor = SIMD4<Float>(
            scene.val_f(name: "PerceptionLinesBaseR"),
            scene.val_f(name: "PerceptionLinesBaseG"),
            scene.val_f(name: "PerceptionLinesBaseB"),
            scene.val_f(name: "PerceptionLinesBaseA"))
        
        var perceptionLinesIndexDelay = floatFromInputs(inputs, name: "PerceptionLinesIndexDelay")
        
        var perceptionT: Float = 0.0
        var perceptions_i: Int = 0
        var totalPerceptions: Int = perceptions.count
        for p in perceptions {
            let perceptionTdt: Float = 1.0 / Float(totalPerceptions)
            perceptionT += perceptionTdt
            
            let perceptionLineColor = SIMD4<Float>(
                scene.val_f(name: "PerceptionLinesBaseR", delay: Double(perceptionT * perceptionLinesIndexDelay * 1000.0)),
                scene.val_f(name: "PerceptionLinesBaseG", delay: Double(perceptionT * perceptionLinesIndexDelay * 1000.0)),
                scene.val_f(name: "PerceptionLinesBaseB", delay: Double(perceptionT * perceptionLinesIndexDelay * 1000.0)),
                scene.val_f(name: "PerceptionLinesBaseA"))
            var perceptionLine = Line(
                startPoint: p.a.position,
                endPoint: p.b.position
            )
            
            perceptionLine = perceptionLine.setBasicEndPointColors(startColor: perceptionLineColor, endColor: perceptionLineColor)
            perceptionLine.lineWidthStart = 1.5
            perceptionLine.lineWidthEnd = 1.5
            perceptionLine = perceptionLine.applyMatrix(outputScale)
            lines.append(perceptionLine)
        }
        
        // Bounds
        
        // All boids bounds
        
        let allBoidIDs: [Int] = Array(0..<sim.agents.count)
        var allBoidsBoundsLines = sim.boundsAsBoxLines(ids: allBoidIDs, padding: 0.0)
        
        for i in allBoidsBoundsLines.indices {
            allBoidsBoundsLines[i] = allBoidsBoundsLines[i].applyMatrix(outputScale)
        }
        
        lines.append(contentsOf: allBoidsBoundsLines)

        // Boids pair bounds
        let pairIDs = [boidPairAIndex, boidPairBIndex]
        var pairBoundsLines = sim.boundsAsBoxLines(ids: pairIDs, padding: 0.0)
        for i in pairBoundsLines.indices {
            pairBoundsLines[i] = pairBoundsLines[i].applyMatrix(outputScale)
        }
        lines.append(contentsOf: pairBoundsLines)

        // Boids cluster bounds
        let clusterIDs = Array(boidsClusterStartIndex...boidsClusterEndIndex)
        var clusterBoundsLines = sim.boundsAsBoxLines(ids: clusterIDs, padding: 0.0)
        for i in clusterBoundsLines.indices {
            clusterBoundsLines[i] = clusterBoundsLines[i].applyMatrix(outputScale)
        }
        lines.append(contentsOf: clusterBoundsLines)

        // Selected boid lines to all boids bounding box
        
        // Camera modes
        // 1: "world_center" - Center on world
        // 2: "agent_center" Center on selected agent
        // 2.1: "agent_center_orient" Center on selected agent and follow orientation
        // 3: "cluster_center" Center on agent cluster center
        // 4: "pair_center" Center on centerpoint between the pair
        
        
        
        var selectedBoidTranslateFollowFactor = floatFromInputs(inputs, name: "SelectedBoidTranslateFollowFactor")
        var selectedBoidRotateFollowFactor = floatFromInputs(inputs, name: "SelectedBoidRotateFollowFactor")
        
        
        var brightnessFloat = ensureValueIsFloat(brightnessInput.getHistoryValue(millisecondsAgo: 0.0))
        var brightnessAsInt = Int((brightnessFloat * 50.0).rounded(.down))
        
        // print(brightnessFloat, brightnessAsInt)
        
        var agentIndex: Int = selectedBoidIndex
        if agentIndex >= sim.agents.count {
            agentIndex = 0
        }
        
        var selectedAgent = sim.agents[agentIndex]
        
        var translateFactor: Float = -0.15 * selectedBoidTranslateFollowFactor
        
        var camDistance: Float = 1.7
        
        
        var translateToAgentMat = matrix_translation(translation: SIMD3<Float>(
            selectedAgent.position.x * translateFactor * 1.0,
            selectedAgent.position.y * translateFactor * 1.0,
            selectedAgent.position.z * translateFactor * 1.0 + camDistance * 0.0
        ))
        
        
        let upFinal = SIMD3<Float>(0, 1, 0)
        
        let agentSpeed = length(selectedAgent.velocity)
        let agentDir = agentSpeed > 0.001 ? normalize(selectedAgent.velocity) : SIMD3<Float>(0, 0, 1)
        
        let zAxis = agentDir
        var xAxis = normalize(cross(upFinal, zAxis))
        
        if length(xAxis) < 0.001 {
            xAxis = SIMD3<Float>(1, 0, 0)
        }
        let yAxis = cross(zAxis, xAxis)
        
        let inverseRotation = matrix_float4x4(
            columns: (
                SIMD4<Float>(xAxis.x, yAxis.x, zAxis.x, 0),
                SIMD4<Float>(xAxis.y, yAxis.y, zAxis.y, 0),
                SIMD4<Float>(xAxis.z, yAxis.z, zAxis.z, 0),
                SIMD4<Float>(0, 0, 0, 1)
            )
        )
        
        var rotationFactor: Float = 1.0 * selectedBoidRotateFollowFactor
        
        let targetQuat = simd_quatf(inverseRotation)
        let identityQuat = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        let blendedQuat = simd_slerp(identityQuat, targetQuat, rotationFactor)
        let blendedRotation = matrix_float4x4(blendedQuat)
        
        let pullbackFactor: Float = 0.0
        
        let pullback = matrix_translation(translation: SIMD3<Float>(0, 0, 1.65 * pullbackFactor))
        
        let finalRotate = matrix_rotation(angle: sceneRotationY, axis: SIMD3<Float>(0.0, 1.0, 0.0))
        
        
        let fullMat = finalRotate * pullback * blendedRotation * translateToAgentMat
        
        for i in lines.indices {
            lines[i] = lines[i].applyMatrix(fullMat)
        }
        
        
        return lines
    }
}

