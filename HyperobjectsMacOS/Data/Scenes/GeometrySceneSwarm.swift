//
//  GeometrySceneSwarm.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 07/03/2026.
//

import Foundation
import SwiftUI

func generateGeometrySceneSwarm() -> GeometriesSceneBase {
    return GeometriesSceneBase(
        name: "Swarm Scene",
        inputs: [
            SceneInput(name: "BoidsCount", type: .integer, value: 80, range: 1...200),

            SceneInput(name: "BoidsTraceInterval", type: .integer, value: 50, range: 1...200),

            SceneInput(name: "SelectedBoidTranslateFollowFactor", type: .float, value: 0.001, range: 0.0...2.0, audioAmplificationAddition: 0.0),
            SceneInput(name: "SelectedBoidRotateFollowFactor", type: .float, value: 0.001, range: 0.0...2.0, audioAmplificationAddition: 0.0),
            
            SceneInput(name: "Brightness", type: .float, value: 0.0, range: 0.0...1.0, audioAmplificationAddition: 1.0),
            
            SceneInput(name: "BoundarySize", type: .float, value: 6.0, range: 0.0...20.0),
            
            SceneInput(name: "Sim_dt", type: .float, value: 0.05, range: 0.0...0.5, audioAmplificationAddition: 0.0),

            SceneInput(name: "AddedSpeed", type: .float, value: 0.0, range: 0.0...3.0, audioAmplificationAddition: 1.0),
            SceneInput(name: "AddedSpeedDelay", type: .float, value: 0.0, range: 0.0...2.0, audioAmplificationAddition: 1.0),
            
            SceneInput(name:"Stateful_Rotation_X", type: .statefulFloat, inputGroupName: "Rotation", value: 0.01, tickValueAdjustmentRange: -0.1...0.1),
            
            
            SceneInput(name: "BoidsBaseR", type: .float, inputGroupName: "Color", value: 0.05, range: 0.0...1.0),
            SceneInput(name: "BoidsBaseG", type: .float, inputGroupName: "Color", value: 0.05, range: 0.0...1.0),
            SceneInput(name: "BoidsBaseB", type: .float, inputGroupName: "Color", value: 0.05, range: 0.0...1.0),
            SceneInput(name: "BoidsBaseA", type: .float, inputGroupName: "Color", value: 1.0, range: 0.0...1.0),
            SceneInput(name: "BoidsBaseTotal", type: .float, inputGroupName: "Color", value: 0.0, range: 0.0...1.0),
            SceneInput(name: "BoidsBaseIndexDelay", type: .float, inputGroupName: "Color", value: 0.0, range: 0.0...1.0),
            
            SceneInput(name: "AllBoidsBoundsR", type: .float, inputGroupName: "Color", value: 0.05, range: 0.0...1.0),
            SceneInput(name: "AllBoidsBoundsG", type: .float, inputGroupName: "Color", value: 0.05, range: 0.0...1.0),
            SceneInput(name: "AllBoidsBoundsB", type: .float, inputGroupName: "Color", value: 0.05, range: 0.0...1.0),
            SceneInput(name: "AllBoidsBoundsA", type: .float, inputGroupName: "Color", value: 1.0, range: 0.0...1.0),
            SceneInput(name: "AllBoidsBoundsLineWidth", type: .float, inputGroupName: "Color", value: 1.5, range: 0.0...1.0),

            SceneInput(name: "AllBoidsTraceStartR", type: .float, inputGroupName: "Color", value: 0.05, range: 0.0...1.0),
            SceneInput(name: "AllBoidsTraceStartG", type: .float, inputGroupName: "Color", value: 0.05, range: 0.0...1.0),
            SceneInput(name: "AllBoidsTraceStartB", type: .float, inputGroupName: "Color", value: 0.05, range: 0.0...1.0),
            SceneInput(name: "AllBoidsTraceStartA", type: .float, inputGroupName: "Color", value: 1.0, range: 0.0...1.0),

            SceneInput(name: "AllBoidsTraceEndR", type: .float, inputGroupName: "Color", value: 0.05, range: 0.0...1.0),
            SceneInput(name: "AllBoidsTraceEndG", type: .float, inputGroupName: "Color", value: 0.05, range: 0.0...1.0),
            SceneInput(name: "AllBoidsTraceEndB", type: .float, inputGroupName: "Color", value: 0.05, range: 0.0...1.0),
            SceneInput(name: "AllBoidsTraceEndA", type: .float, inputGroupName: "Color", value: 1.0, range: 0.0...1.0),

            SceneInput(name: "AllBoidsTraceLineWidth", type: .float, inputGroupName: "Color", value: 1.0, range: 0.0...1.0),
            
            SceneInput(name: "BoidsOrganicR", type: .float, inputGroupName: "Color", value: 1.0, range: 0.0...1.0),
            SceneInput(name: "BoidsOrganicG", type: .float, inputGroupName: "Color", value: 1.0, range: 0.0...1.0),
            SceneInput(name: "BoidsOrganicB", type: .float, inputGroupName: "Color", value: 1.0, range: 0.0...1.0),
            SceneInput(name: "BoidsOrganicA", type: .float, inputGroupName: "Color", value: 1.0, range: 0.0...1.0),
            
            SceneInput(name: "BoidsOrganicTotal", type: .float, inputGroupName: "Color", value: 0.0, range: 0.0...1.0),
            
            
            SceneInput(name: "SelectedBoidR", type: .float, inputGroupName: "Color", value: 0.05, range: 0.0...1.0),
            SceneInput(name: "SelectedBoidG", type: .float, inputGroupName: "Color", value: 0.05, range: 0.0...1.0),
            SceneInput(name: "SelectedBoidB", type: .float, inputGroupName: "Color", value: 0.05, range: 0.0...1.0),
            SceneInput(name: "SelectedBoidA", type: .float, inputGroupName: "Color", value: 1.0, range: 0.0...1.0),
            SceneInput(name: "SelectedBoidTotal", type: .float, inputGroupName: "Color", value: 0.0, range: 0.0...1.0),


            SceneInput(name: "DistanceToSelectedBoidRangeStartR", type: .float, inputGroupName: "Color", value: 0.05, range: 0.0...1.0),
            SceneInput(name: "DistanceToSelectedBoidRangeStartG", type: .float, inputGroupName: "Color", value: 0.05, range: 0.0...1.0),
            SceneInput(name: "DistanceToSelectedBoidRangeStartB", type: .float, inputGroupName: "Color", value: 0.05, range: 0.0...1.0),
            SceneInput(name: "DistanceToSelectedBoidRangeStartA", type: .float, inputGroupName: "Color", value: 1.0, range: 0.0...1.0),
            SceneInput(name: "DistanceToSelectedBoidRangeEndR", type: .float, inputGroupName: "Color", value: 0.05, range: 0.0...1.0),
            SceneInput(name: "DistanceToSelectedBoidRangeEndG", type: .float, inputGroupName: "Color", value: 0.05, range: 0.0...1.0),
            SceneInput(name: "DistanceToSelectedBoidRangeEndB", type: .float, inputGroupName: "Color", value: 0.05, range: 0.0...1.0), 
            SceneInput(name: "DistanceToSelectedBoidRangeEndA", type: .float, inputGroupName: "Color", value: 1.0, range: 0.0...1.0),
            SceneInput(name: "DistanceToSelectedBoidRangeTotal", type: .float, inputGroupName: "Color", value: 0.0, range: 0.0...1.0),
            SceneInput(name: "DistanceToSelectedBoidDistanceDelay", type: .float, inputGroupName: "Color", value: 0.0, range: 0.0...5.0),
            
            SceneInput(name: "BoidsClusterR", type: .float, inputGroupName: "Color", value: 0.05, range: 0.0...1.0),
            SceneInput(name: "BoidsClusterG", type: .float, inputGroupName: "Color", value: 0.05, range: 0.0...1.0),
            SceneInput(name: "BoidsClusterB", type: .float, inputGroupName: "Color", value: 0.05, range: 0.0...1.0),
            SceneInput(name: "BoidsClusterA", type: .float, inputGroupName: "Color", value: 1.0, range: 0.0...1.0),
            SceneInput(name: "BoidsClusterTotal", type: .float, inputGroupName: "Color", value: 0.0, range: 0.0...1.0),
            
            
            SceneInput(name: "BoidsPairOneR", type: .float, inputGroupName: "Color", value: 0.05, range: 0.0...1.0),
            SceneInput(name: "BoidsPairOneG", type: .float, inputGroupName: "Color", value: 0.05, range: 0.0...1.0),
            SceneInput(name: "BoidsPairOneB", type: .float, inputGroupName: "Color", value: 0.05, range: 0.0...1.0),
            SceneInput(name: "BoidsPairOneA", type: .float, inputGroupName: "Color", value: 1.0, range: 0.0...1.0),
            SceneInput(name: "BoidsPairOneTotal", type: .float, inputGroupName: "Color", value: 0.05, range: 0.0...1.0),
            
            SceneInput(name: "BoidsPairTwoR", type: .float, inputGroupName: "Color", value: 0.05, range: 0.0...1.0),
            SceneInput(name: "BoidsPairTwoG", type: .float, inputGroupName: "Color", value: 0.05, range: 0.0...1.0),
            SceneInput(name: "BoidsPairTwoB", type: .float, inputGroupName: "Color", value: 0.05, range: 0.0...1.0),
            SceneInput(name: "BoidsPairTwoA", type: .float, inputGroupName: "Color", value: 1.0, range: 0.0...1.0),
            SceneInput(name: "BoidsPairBothTotal", type: .float, inputGroupName: "Color", value: 0.05, range: 0.0...1.0),
            
            SceneInput(name: "BoidsPairTotal", type: .float, inputGroupName: "Color", value: 0.05, range: 0.0...1.0),
            
            SceneInput(name: "BoidsPairConnectionStartR", type: .float, inputGroupName: "Color", value: 0.05, range: 0.0...1.0),
            SceneInput(name: "BoidsPairConnectionStartG", type: .float, inputGroupName: "Color", value: 0.05, range: 0.0...1.0),
            SceneInput(name: "BoidsPairConnectionStartB", type: .float, inputGroupName: "Color", value: 0.05, range: 0.0...1.0),
            SceneInput(name: "BoidsPairConnectionStartA", type: .float, inputGroupName: "Color", value: 1.0, range: 0.0...1.0),
            
            SceneInput(name: "BoidsPairConnectionEndR", type: .float, inputGroupName: "Color", value: 0.05, range: 0.0...1.0),
            SceneInput(name: "BoidsPairConnectionEndG", type: .float, inputGroupName: "Color", value: 0.05, range: 0.0...1.0),
            SceneInput(name: "BoidsPairConnectionEndB", type: .float, inputGroupName: "Color", value: 0.05, range: 0.0...1.0),
            SceneInput(name: "BoidsPairConnectionEndA", type: .float, inputGroupName: "Color", value: 1.0, range: 0.0...1.0),
            
            SceneInput(name: "PerceptionLinesBaseR", type: .float, inputGroupName: "Color", value: 0.2, range: 0.0...1.0),
            SceneInput(name: "PerceptionLinesBaseG", type: .float, inputGroupName: "Color", value: 0.2, range: 0.0...1.0),
            SceneInput(name: "PerceptionLinesBaseB", type: .float, inputGroupName: "Color", value: 0.2, range: 0.0...1.0),
            SceneInput(name: "PerceptionLinesBaseA", type: .float, inputGroupName: "Color", value: 1.0, range: 0.0...1.0),
            SceneInput(name: "PerceptionLinesTotal", type: .float, inputGroupName: "Color", value: 0.0, range: 0.0...1.0),
            SceneInput(name: "PerceptionLinesIndexDelay", type: .float, inputGroupName: "Color", value: 0.5, range: 0.0...5.0),

        ],
        geometryGenerators: [
            SwarmGenerator()
        ]
    )
}
