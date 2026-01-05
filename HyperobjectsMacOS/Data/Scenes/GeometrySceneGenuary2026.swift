//
//  GeometrySceneGenuary2026.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 01/01/2026.
//

import Foundation
import SwiftUI

var fontValues: [String: String] = [
    "Futura": "Futura",
    "SF Mono": "SF Mono",
    "SF Mono Heavy": "SF Mono Heavy",
    "Menlo": "Menlo",
    "Courier New": "Courier New",
    "American Typewriter": "American Typewriter",
    "Palatino": "Palatino",
    "Georgia": "Georgia",
    "Bookman Old Style": "Bookman Old Style",
    "Helvetica": "Helvetica",
    "Verdana": "Verdana",
    "Times New Roman": "Times New Roman",
    "Courier": "Courier",
]

func generateGeometrySceneGenuary2026() -> GeometriesSceneBase {
    var scene = GeometriesSceneBase(
        name: "Genuary 2026",
        inputs: [
            SceneInput(name: "Day", type: .string, inputGroupName: "Day configs", value: "6", presetValues: [
                "1":"1", "2":"2", "3":"3", "4":"4", "5":"5", "6":"6", "7":"7", "8":"8", "9":"9", "10":"10",
                "11":"11", "12":"12", "13":"13", "14":"14", "15":"15", "16":"16", "17":"17", "18":"18", "19":"19", "20":"20",
                "21":"21", "22":"22", "23":"23", "24":"24", "25":"25", "26":"26", "27":"27", "28":"28", "29":"29", "30":"30", "31":"31"
            ]),
            SceneInput(name: "Main title", type: .string, inputGroupName: "Texts", value: "Genuary"),
            SceneInput(name: "Year", type: .string, inputGroupName: "Texts", value: "2026"),
            SceneInput(name: "Prompt", type: .string, inputGroupName: "Texts", value: "Lights on / off."),
            SceneInput(name: "Credit", type: .string, inputGroupName: "Texts", value: "socratism.io"),
            
            
            SceneInput(name: "Main font", type: .string, inputGroupName: "Text effects", value: "SF Mono Heavy", presetValues: fontValues),
            SceneInput(name: "Secondary font", type: .string, inputGroupName: "Text effects", value: "SF Mono Heavy", presetValues: fontValues),
            
            SceneInput(name: "Line width base", type: .float, inputGroupName: "Text effects", value: 2.4, range: 0...50.0,
                       audioAmplificationAddition: 0.0,
                       audioAmplificationAdditionRange: 0.0...20.0),
            
            SceneInput(name: "Replacement probability", type: .float, inputGroupName: "Text effects",
                                   value: 0.0,
                                   range: 0...1,
                                   audioAmplificationAddition: 0.9,
                                   audioAmplificationMultiplicationRange: 0...1
                                  ),
                        
            SceneInput(name: "Restore probability", type: .float, inputGroupName: "Text effects",
                       value: 0.55,
                       range: 0...1,
                       audioAmplificationMultiplicationRange: 0...1
                      ),
            
            
            SceneInput(name: "Brightness", type: .float, value: 0.0, range: 0.0...1.0, audioAmplificationAddition: 1.0),
            
            SceneInput(name: "Width", type: .float, value: 1.0, range: 0.0...3.0, audioAmplificationAddition: -0.8),
            SceneInput(name: "Height", type: .float, value: 1.0, range: 0.0...3.0, audioAmplificationAddition: -0.8, audioDelay: 0.1),
            SceneInput(name: "Depth", type: .float, value: 1.0, range: 0.0...3.0, audioAmplificationAddition: -0.8, audioDelay: 0.17),

            
            
        ],
        geometryGenerators: [
            Genuary2026Generator()
        ]
    )
    
    scene.sceneHasBackgroundColor = true
    scene.backgroundColor = SIMD3<Float>(0.05, 0.01, 0.1)
    
    return scene
}
