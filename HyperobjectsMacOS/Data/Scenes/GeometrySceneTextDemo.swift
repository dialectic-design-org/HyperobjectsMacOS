//
//  GeometrySceneTextDemo.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 02/08/2025.
//


import Foundation
import SwiftUI

func generateGeometrySceneTextDemo() -> GeometriesSceneBase {
    return GeometriesSceneBase(
        name: "Text Demo Scene",
        inputs: [
            SceneInput(name: "Title text",
                       type: .string,
                       value: "SATISFACTION",
                       presetValues: [
                        "Hello world!": "Hello world!",
                        "SATISFACTION": "SATISFACTION",
                        "HYPEROBJECTS": "HYPEROBJECTS",
                        "SOCRATISM": "SOCRATISM",
                        "TWILIGHT":"TWILIGHT",
                        "IDOLS":"IDOLS",
                        "FALSE GODS": "FALSE GODS",
                        "CamelCase":"CamelCase",
                        "Zarathushra":"Zarathushra",
                        "BUY MORE TO SAVE MORE": "BUY MORE TO SAVE MORE",
                        "TURING COMPLETE USER": "TURING COMPLETE USER",
                        "PERFORMANCE*PERFORMANCE":"PERFORMANCE*PERFORMANCE",
                        "PERFORMANCE^2": "PERFORMANCE^2"
                       ]
                      ),
            SceneInput(name: "Replacement characters",
                       type: .string,
                       value: "$#%@*!+",
                       presetValues: [
                        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()-=_+`~": "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()-=_+`~",
                        "$": "$",
                        "#": "#",
                        "!": "!",
                        "HYPEROBJECTS": "HYPEROBJECTS",
                        "SOCRATISM": "SOCRATISM",
                        "BUY MORE TO SAVE MORE": "BUY MORE TO SAVE MORE",
                        "TURING COMPLETE USER": "TURING COMPLETE USER",
                        "PERFORMANCE*PERFORMANCE":"PERFORMANCE*PERFORMANCE",
                        "PERFORMANCE^2": "PERFORMANCE^2",
                        "$#%@*!+":"$#%@*!+",
                        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ":"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ",
                        "αβγδεζηθικλμνξοπρστυφχψωΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ":"αβγδεζηθικλμνξοπρστυφχψωΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ",
                        "абвгдеёжзийклмнопрстуфхцчшщъыьэюяАБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ":"абвгдеёжзийклмнопрстуфхцчшщъыьэюяАБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ",
                        "אבגדהוזחטיכלמנסעפצקרשת":"אבגדהוזחטיכלמנסעפצקרשת",
                        "ابتثجحخدذرزسشصضطظعغفقكلمنهوي":"ابتثجحخدذرزسشصضطظعغفقكلمنهوي",
                        "अआइईउऊऋएऐओऔकखगघङचछजझञटठडढणतथदधनपफबभमयरलवशषसह":"अआइईउऊऋएऐओऔकखगघङचछजझञटठडढणतथदधनपफबभमयरलवशषसह"
                       ]
                      ),
            
            
            
            
            SceneInput(name: "Replacement probability", type: .float, inputGroupName: "Text effects",
                       value: 0.02,
                       range: 0...1,
                       audioAmplificationMultiplicationRange: 0...1
                      ),
            
            SceneInput(name: "Restore probability", type: .float, inputGroupName: "Text effects",
                       value: 0.1,
                       range: 0...1,
                       audioAmplificationMultiplicationRange: 0...1
                      ),
            
            SceneInput(name: "Spacing", type: .float, inputGroupName: "Text effects",
                       value: 0.0,
                       range: 0...2,
                       audioAmplificationMultiplicationRange: 0...5
                      ),
            
            SceneInput(name:"Stateful Rotation X", type: .statefulFloat, tickValueAdjustmentRange: 0.0...0.1),
            SceneInput(name:"Stateful Rotation Y", type: .statefulFloat, tickValueAdjustmentRange: 0.0...0.1),
            SceneInput(name:"Stateful Rotation Z", type: .statefulFloat, tickValueAdjustmentRange: 0.0...0.1),
            SceneInput(name: "Line width base", type: .float, inputGroupName: "Shading", value: 0.0, range: 0...50.0,
                       audioAmplificationAddition: 0.0,
                       audioAmplificationAdditionRange: 0.0...20.0),
            SceneInput(name: "Start color", type: .colorInput, inputGroupName: "Shading", value: Color.white),
            SceneInput(name: "End color", type: .colorInput, inputGroupName: "Shading", value: Color.white),
        ],
        geometryGenerators: [
            TextDemoGenerator()
        ]
    )
}
