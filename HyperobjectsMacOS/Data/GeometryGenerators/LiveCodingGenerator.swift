import Foundation
import simd
import SwiftUI

class LiveCodingGenerator: CachedGeometryGenerator {
    init() {
        super.init(name: "Live Coding Generator",
                   inputDependencies: [CachedGeometryGenerator.allSceneInputsSentinel])
    }
    
    override func generateGeometriesFromInputs(inputs: [String : Any], withScene: GeometriesSceneBase) -> [any Geometry] {
        var lines: [Line] = []
        if let linesInput = inputs["Lines"] as? [Line] {
            lines = linesInput
        }

        // Scripted `Cube` objects: the Cube scene's generator, run once per object against
        // the object's own inputs.
        if let cubes = inputs["Cubes"] as? [ScriptedObjectInputs] {
            for cube in cubes {
                lines += CubeGenerator.generateLines(inputs: cube.inputs, inputSource: cube.source)
            }
        }

        return lines
    }
}
