import Foundation
import simd
import SwiftUI

class LiveCodingGenerator: CachedGeometryGenerator {
    init() {
        super.init(name: "Live Coding Generator",
                   inputDependencies: [
                    "Lines",
                   ])
    }
    
    override func generateGeometriesFromInputs(inputs: [String : Any], withScene: GeometriesSceneBase) -> [any Geometry] {
        var lines: [Line] = []
        if let linesInput = inputs["Lines"] as? [Line] {
            lines = linesInput
        }

        return lines
    }
}
