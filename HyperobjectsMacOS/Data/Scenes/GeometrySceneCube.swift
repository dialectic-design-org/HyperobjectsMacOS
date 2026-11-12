//
//  GeometrySceneCube.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 06/11/2024.
//

import Foundation
import SwiftUI

func generateGeometrySceneCube() -> GeometriesSceneBase {
    return GeometriesSceneBase(
        name: "Cube Scene",
        inputs: makeCubeSceneInputs(),
        geometryGenerators: [
            CubeGenerator()
        ]
    )
}

/// The inputs of one cube construct. Shared by the Cube scene and by scripted `Cube` objects
/// (`ScriptedObjectKind.cube`), so a name added or renamed here changes both.
func makeCubeSceneInputs() -> [SceneInput] {
    return [
            SceneInput(name: "LineWidth", type: .float, value: 1.0, range: 0.0...40.0),
            SceneInput(name: "LineWidth delay", type: .float, value: 0.0, range: 0.0...3.0),
            SceneInput(name: "LineWidth Outer Loop delay", type: .float, value: 0.0, range: 0.0...3.0),
            SceneInput(name: "LineWidth Inner Loop delay", type: .float, value: 0.0, range: 0.0...3.0),

            SceneInput(name: "Line Length", type: .float, value: 1.0, range: 0.0...3.0),
            SceneInput(name: "Line Length delay", type: .float, value: 0.0, range: 0.0...0.3),

            SceneInput(name: "Line Offset", type: .float, value: 0.0, range: -2.0...2.0),
            SceneInput(name: "Line Offset delay", type: .float, value: 0.0, range: 0.0...3.0),

            SceneInput(name: "Line Gap", type: .float, value: 0.0, range: 0.0...2.0),
            SceneInput(name: "Line Gap delay", type: .float, value: 0.0, range: 0.0...3.0),

            SceneInput(name: "Size", type: .float, value: 0.5, range: 0.0...2.0),

            SceneInput(name: "Width", type: .float, value: 0.5, range: 0.0...3.0),
            SceneInput(name: "Width delay", type: .float, value: 0.0, range: 0.0...3.0),
            SceneInput(name: "Width Outer Loop delay", type: .float, value: 0.0, range: 0.0...3.0),
            SceneInput(name: "Width Inner Loop delay", type: .float, value: 0.0, range: 0.0...3.0),

            SceneInput(name: "Height", type: .float, value: 0.5, range: 0.0...3.0),
            SceneInput(name: "Height delay", type: .float, value: 0.0, range: 0.0...3.0),
            SceneInput(name: "Height Outer Loop delay", type: .float, value: 0.0, range: 0.0...3.0),
            SceneInput(name: "Height Inner Loop delay", type: .float, value: 0.0, range: 0.0...3.0),

            SceneInput(name: "Depth", type: .float, value: 0.5, range: 0.0...3.0),
            SceneInput(name: "Depth delay", type: .float, value: 0.0, range: 0.0...3.0),
            SceneInput(name: "Depth Outer Loop delay", type: .float, value: 0.0, range: 0.0...3.0),
            SceneInput(name: "Depth Inner Loop delay", type: .float, value: 0.0, range: 0.0...3.0),

            SceneInput(name: "Face offset", type: .float, value: 0.0, range: -4.0...4.0),
            SceneInput(name: "Face offset delay", type: .float, value: 0.0, range: 0.0...3.0),
            SceneInput(name: "Face offset Outer Loop delay", type: .float, value: 0.0, range: 0.0...3.0),
            SceneInput(name: "Face offset Inner Loop delay", type: .float, value: 0.0, range: 0.0...3.0),

            SceneInput(name: "Outer Loop Cubes Count", type: .integer,
                       inputGroupName: "Cubes",
                       value: 1,
                       range: 1...20
                      ),
            SceneInput(name: "Inner Loop Cubes Count", type: .integer,
                       inputGroupName: "Cubes",
                       value: 1,
                       range: 1...20,
                      ),

            SceneInput(name: "InnerCubesScaling", type: .float,
                       inputGroupName: "Cubes", value: 0.0, range: -6.0...6.0),

            SceneInput(name: "InnerCubesScaling Outer Loop", type: .float,
                       inputGroupName: "Cubes", value: 0.0, range: -6.0...6.0),

            SceneInput(name: "InnerCubesScaling Inner Loop", type: .float,
                       inputGroupName: "Cubes", value: 0.0, range: -6.0...6.0),

            SceneInput(name: "InnerCubesScaling delay", type: .float,
                       inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),
            SceneInput(name: "InnerCubesScaling Outer Loop delay", type: .float,
                       inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),
            SceneInput(name: "InnerCubesScaling Inner Loop delay", type: .float,
                       inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),



            SceneInput(name: "Outer Loop Cubes spread x", type: .float,
                       inputGroupName: "Cubes", value: 0.0, range: 0.0...5.0),
            SceneInput(name: "Outer Loop Cubes spread x delay", type: .float,
                       inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),
            SceneInput(name: "Outer Loop Cubes spread x Outer Loop delay", type: .float,
                       inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),
            SceneInput(name: "Outer Loop Cubes spread x Inner Loop delay", type: .float,
                       inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),

            SceneInput(name: "Outer Loop Cubes spread y", type: .float,
                       inputGroupName: "Cubes", value: 0.0, range: 0.0...5.0),
            SceneInput(name: "Outer Loop Cubes spread y delay", type: .float,
                       inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),
            SceneInput(name: "Outer Loop Cubes spread y Outer Loop delay", type: .float,
                       inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),
            SceneInput(name: "Outer Loop Cubes spread y Inner Loop delay", type: .float,
                       inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),

            SceneInput(name: "Outer Loop Cubes spread z", type: .float,
                       inputGroupName: "Cubes", value: 0.0, range: 0.0...5.0),
            SceneInput(name: "Outer Loop Cubes spread z delay", type: .float,
                       inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),
            SceneInput(name: "Outer Loop Cubes spread z Outer Loop delay", type: .float,
                       inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),
            SceneInput(name: "Outer Loop Cubes spread z Inner Loop delay", type: .float,
                       inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),


            SceneInput(name: "Inner Loop Cubes spread x", type: .float,
                       inputGroupName: "Cubes", value: 0.0, range: 0.0...5.0),
            SceneInput(name: "Inner Loop Cubes spread x delay", type: .float,
                       inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),
            SceneInput(name: "Inner Loop Cubes spread x Outer Loop delay", type: .float,
                       inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),
            SceneInput(name: "Inner Loop Cubes spread x Inner Loop delay", type: .float,
                       inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),

            SceneInput(name: "Inner Loop Cubes spread y", type: .float,
                       inputGroupName: "Cubes", value: 0.0, range: 0.0...5.0),
            SceneInput(name: "Inner Loop Cubes spread y delay", type: .float,
                       inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),
            SceneInput(name: "Inner Loop Cubes spread y Outer Loop delay", type: .float,
                       inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),
            SceneInput(name: "Inner Loop Cubes spread y Inner Loop delay", type: .float,
                       inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),

            SceneInput(name: "Inner Loop Cubes spread z", type: .float,
                       inputGroupName: "Cubes", value: 0.0, range: 0.0...5.0),
            SceneInput(name: "Inner Loop Cubes spread z delay", type: .float,
                       inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),
            SceneInput(name: "Inner Loop Cubes spread z Outer Loop delay", type: .float,
                       inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),
            SceneInput(name: "Inner Loop Cubes spread z Inner Loop delay", type: .float,
                       inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),


            SceneInput(name: "Wave Amplitude Outer Loop translate x", type: .float,
                       inputGroupName: "Cubes", value: 0.0, range: 0.0...5.0),
            SceneInput(name: "Wave Frequency Outer Loop translate x", type: .float,
                       inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),
            SceneInput(name: "Wave Offset Outer Loop translate x", type: .float,
                       inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),

            SceneInput(name: "Wave Amplitude Outer Loop translate y", type: .float,
                       inputGroupName: "Cubes", value: 0.0, range: 0.0...5.0),
            SceneInput(name: "Wave Frequency Outer Loop translate y", type: .float,
                       inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),
            SceneInput(name: "Wave Offset Outer Loop translate y", type: .float,
                       inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),

            SceneInput(name: "Wave Amplitude Outer Loop translate z", type: .float,
                        inputGroupName: "Cubes", value: 0.0, range: 0.0...5.0),
            SceneInput(name: "Wave Frequency Outer Loop translate z", type: .float,
                        inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),
            SceneInput(name: "Wave Offset Outer Loop translate z", type: .float,
                        inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),


            SceneInput(name: "Wave Amplitude Inner Loop translate x", type: .float,
                        inputGroupName: "Cubes", value: 0.0, range: 0.0...5.0),
            SceneInput(name: "Wave Frequency Inner Loop translate x", type: .float,
                        inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),
            SceneInput(name: "Wave Offset Inner Loop translate x", type: .float,
                        inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),

            SceneInput(name: "Wave Amplitude Inner Loop translate y", type: .float,
                        inputGroupName: "Cubes", value: 0.0, range: 0.0...5.0),
            SceneInput(name: "Wave Frequency Inner Loop translate y", type: .float,
                        inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),
            SceneInput(name: "Wave Offset Inner Loop translate y", type: .float,
                        inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),

            SceneInput(name: "Wave Amplitude Inner Loop translate z", type: .float,
                        inputGroupName: "Cubes", value: 0.0, range: 0.0...5.0),
            SceneInput(name: "Wave Frequency Inner Loop translate z", type: .float,
                        inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),
            SceneInput(name: "Wave Offset Inner Loop translate z", type: .float,
                        inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),



            SceneInput(name: "Wave Amplitude Outer Loop Width", type: .float,
                        inputGroupName: "Cubes", value: 0.0, range: 0.0...5.0),
            SceneInput(name: "Wave Frequency Outer Loop Width", type: .float,
                        inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),
            SceneInput(name: "Wave Offset Outer Loop Width", type: .float,
                        inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),

            SceneInput(name: "Wave Amplitude Outer Loop Height", type: .float,
                        inputGroupName: "Cubes", value: 0.0, range: 0.0...5.0),
            SceneInput(name: "Wave Frequency Outer Loop Height", type: .float,
                        inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),
            SceneInput(name: "Wave Offset Outer Loop Height", type: .float,
                        inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),

            SceneInput(name: "Wave Amplitude Outer Loop Depth", type: .float,
                        inputGroupName: "Cubes", value: 0.0, range: 0.0...5.0),
            SceneInput(name: "Wave Frequency Outer Loop Depth", type: .float,
                        inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),
            SceneInput(name: "Wave Offset Outer Loop Depth", type: .float,
                        inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),


            SceneInput(name: "Wave Amplitude Inner Loop Width", type: .float,
                        inputGroupName: "Cubes", value: 0.0, range: 0.0...5.0),
            SceneInput(name: "Wave Frequency Inner Loop Width", type: .float,
                        inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),
            SceneInput(name: "Wave Offset Inner Loop Width", type: .float,
                        inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),

            SceneInput(name: "Wave Amplitude Inner Loop Height", type: .float,
                        inputGroupName: "Cubes", value: 0.0, range: 0.0...5.0),
            SceneInput(name: "Wave Frequency Inner Loop Height", type: .float,
                        inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),
            SceneInput(name: "Wave Offset Inner Loop Height", type: .float,
                        inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),

            SceneInput(name: "Wave Amplitude Inner Loop Depth", type: .float,
                        inputGroupName: "Cubes", value: 0.0, range: 0.0...5.0),
            SceneInput(name: "Wave Frequency Inner Loop Depth", type: .float,
                        inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),
            SceneInput(name: "Wave Offset Inner Loop Depth", type: .float,
                        inputGroupName: "Cubes", value: 0.0, range: 0.0...3.0),





            // Position of the whole construct, applied after the scene rotation. The delay
            // lets the loop cubes follow the position one after the other.
            SceneInput(name: "Position X", type: .float, inputGroupName: "Position", value: 0.0, range: -3.0...3.0,
                       audioAmplificationAdditionRange: -2.0...2.0),
            SceneInput(name: "Position X delay", type: .float, inputGroupName: "Position", value: 0.0, range: 0.0...3.0),
            SceneInput(name: "Position Y", type: .float, inputGroupName: "Position", value: 0.0, range: -3.0...3.0,
                       audioAmplificationAdditionRange: -2.0...2.0),
            SceneInput(name: "Position Y delay", type: .float, inputGroupName: "Position", value: 0.0, range: 0.0...3.0),
            SceneInput(name: "Position Z", type: .float, inputGroupName: "Position", value: 0.0, range: -3.0...3.0,
                       audioAmplificationAdditionRange: -2.0...2.0),
            SceneInput(name: "Position Z delay", type: .float, inputGroupName: "Position", value: 0.0, range: 0.0...3.0),

            SceneInput(name: "Rotation X", type: .float, inputGroupName: "Rotation", value: 0.0, range: 0.0...2 * .pi),
            SceneInput(name: "Rotation X Delay", type: .float, inputGroupName: "Rotation", value: 0.0, range: 0.0...2 * .pi),
            SceneInput(name: "Rotation X Offset", type: .float, inputGroupName: "Rotation", value: 0.0, range: 0.0...2 * .pi),
            SceneInput(name: "Rotation X Offset Delay", type: .float, inputGroupName: "Rotation", value: 0.0, range: 0.0...2 * .pi),

            SceneInput(name: "Rotation Y", type: .float, inputGroupName: "Rotation", value: 0.0, range: 0.0...2 * .pi),
            SceneInput(name: "Rotation Y Delay", type: .float, inputGroupName: "Rotation", value: 0.0, range: 0.0...2 * .pi),
            SceneInput(name: "Rotation Y Offset", type: .float, inputGroupName: "Rotation", value: 0.0, range: 0.0...2 * .pi),
            SceneInput(name: "Rotation Y Offset Delay", type: .float, inputGroupName: "Rotation", value: 0.0, range: 0.0...2 * .pi),

            SceneInput(name: "Rotation Z", type: .float, inputGroupName: "Rotation", value: 0.0, range: 0.0...2 * .pi),
            SceneInput(name: "Rotation Z Delay", type: .float, inputGroupName: "Rotation", value: 0.0, range: 0.0...2 * .pi),
            SceneInput(name: "Rotation Z Offset", type: .float, inputGroupName: "Rotation", value: 0.0, range: 0.0...2 * .pi),
            SceneInput(name: "Rotation Z Offset Delay", type: .float, inputGroupName: "Rotation", value: 0.0, range: 0.0...2 * .pi),

            // Pivot of the cube's own rotation (Rotation X/Y/Z, stateful rotation, offsets), as
            // an offset from the centre of each loop cube. 0 rotates around the centre.
            SceneInput(name: "Rotation Origin X", type: .float, inputGroupName: "Rotation", value: 0.0, range: -2.0...2.0,
                       audioAmplificationAdditionRange: -2.0...2.0),
            SceneInput(name: "Rotation Origin Y", type: .float, inputGroupName: "Rotation", value: 0.0, range: -2.0...2.0,
                       audioAmplificationAdditionRange: -2.0...2.0),
            SceneInput(name: "Rotation Origin Z", type: .float, inputGroupName: "Rotation", value: 0.0, range: -2.0...2.0,
                       audioAmplificationAdditionRange: -2.0...2.0),





            SceneInput(name:"Stateful Rotation X", type: .statefulFloat, inputGroupName: "Rotation", tickValueAdjustmentRange: -0.1...0.1),
            SceneInput(name:"Stateful Rotation Y", type: .statefulFloat, inputGroupName: "Rotation", tickValueAdjustmentRange: -0.1...0.1),
            SceneInput(name:"Stateful Rotation Z", type: .statefulFloat, inputGroupName: "Rotation", tickValueAdjustmentRange: -0.1...0.1),

            SceneInput(name:"Scene Rotation X", type: .float, inputGroupName: "Rotation", tickValueAdjustmentRange: -0.1...0.1),
            SceneInput(name:"Scene Rotation Y", type: .float, inputGroupName: "Rotation", tickValueAdjustmentRange: -0.1...0.1),
            SceneInput(name:"Scene Rotation Z", type: .float, inputGroupName: "Rotation", tickValueAdjustmentRange: -0.1...0.1),

            SceneInput(name:"Scene Stateful Rotation X", type: .statefulFloat, inputGroupName: "Rotation", tickValueAdjustmentRange: -0.1...0.1),
            SceneInput(name:"Scene Stateful Rotation Y", type: .statefulFloat, inputGroupName: "Rotation", tickValueAdjustmentRange: -0.1...0.1),
            SceneInput(name:"Scene Stateful Rotation Z", type: .statefulFloat, inputGroupName: "Rotation", tickValueAdjustmentRange: -0.1...0.1),

            SceneInput(name: "Color mode",
                       type: .string,
                       inputGroupName: "Shading",
                       value: "Picker",
                       presetValues: [
                        "Picker":"Picker",
                        "RGB":"RGB"
                       ]
                      ),
            SceneInput(name: "Color start", type: .colorInput, inputGroupName: "Shading", value: Color.white),
            SceneInput(name: "Color end", type: .colorInput, inputGroupName: "Shading", value: Color.white),

            SceneInput(name: "Stateful Color Shift", type: .statefulFloat, inputGroupName: "Shading", tickValueAdjustmentRange: 0.0...0.1),

            SceneInput(name: "Color wave repeat", type: .float, inputGroupName: "Shading", value: 1.0, range: 0.0...10.0),

            SceneInput(name: "Brightness", type: .float, inputGroupName: "Shading", value: 1.0, range: 0.0...3),
            SceneInput(name: "Brightness delay", type: .float, inputGroupName: "Shading", value: 1.0, range: 0.0...3),

            SceneInput(name: "Saturation", type: .float, inputGroupName: "Shading", value: 1.0, range: 0.0...3),
            SceneInput(name: "Saturation delay", type: .float, inputGroupName: "Shading", value: 1.0, range: 0.0...3),


            SceneInput(name: "Red start", type: .float, inputGroupName: "Shading", value: 0.0, range: 0.0...1),
            SceneInput(name: "Red start delay", type: .float, inputGroupName: "Shading", value: 0.0, range: 0.0...3),

            SceneInput(name: "Green start", type: .float, inputGroupName: "Shading", value: 0.0, range: 0.0...1),
            SceneInput(name: "Green start delay", type: .float, inputGroupName: "Shading", value: 0.0, range: 0.0...3),

            SceneInput(name: "Blue start", type: .float, inputGroupName: "Shading", value: 0.0, range: 0.0...1),
            SceneInput(name: "Blue start delay", type: .float, inputGroupName: "Shading", value: 0.0, range: 0.0...3),

            SceneInput(name: "Red end", type: .float, inputGroupName: "Shading", value: 0.0, range: 0.0...1),
            SceneInput(name: "Red end delay", type: .float, inputGroupName: "Shading", value: 0.0, range: 0.0...1),

            SceneInput(name: "Green end", type: .float, inputGroupName: "Shading", value: 0.0, range: 0.0...1),
            SceneInput(name: "Green end delay", type: .float, inputGroupName: "Shading", value: 0.0, range: 0.0...3),

            SceneInput(name: "Blue end", type: .float, inputGroupName: "Shading", value: 0.0, range: 0.0...1),
            SceneInput(name: "Blue end delay", type: .float, inputGroupName: "Shading", value: 0.0, range: 0.0...3),
    ]
}
