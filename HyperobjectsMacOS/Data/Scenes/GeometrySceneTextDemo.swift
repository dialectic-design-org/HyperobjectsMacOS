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
                       value: "Hello World!",
                       presetValues: [
                        "Hello world!": "Hello world!",
                        "SATISFACTION": "SATISFACTION",
                        "HYPEROBJECTS": "HYPEROBJECTS",
                        "SOCRATISM": "SOCRATISM",
                        "TWILIGHT":"TWILIGHT",
                        "IDOLS":"IDOLS",
                        "FALSE GODS": "FALSE GODS",
                        "CamelCase":"CamelCase",
                        "Zarathushtra":"Zarathushtra",
                        "BUY MORE TO SAVE MORE": "BUY MORE TO SAVE MORE",
                        "TURING COMPLETE USER": "TURING COMPLETE USER",
                        "PERFORMANCE*PERFORMANCE":"PERFORMANCE*PERFORMANCE",
                        "PERFORMANCE^2": "PERFORMANCE^2",
                        "909":"909",
                        "808":"808",
                        "Techno":"Techno",
                        "TECHNO":"TECHNO",
                        "CYBER":"CYBER",
                        "CYBERPUNK":"CYBERPUNK",
                        "Meta data": "Meta data",
                        "Metropolis": "Metropolis",
                        "Zero day": "Zero day",
                        "ZERODAY":"ZERODAY",
                        "0-day": "0-day",
                        "Exploit": "Exploit",
                        "Hack": "Hack",
                        "Techno-folk":"Techno-folk",
                        "Electro":"Electro",
                        "Electronics":"Electronics",
                        "NOISE":"NOISE",
                        "ART":"ART",
                        "BANANA":"BANANA",
                        "FUTURISM":"FUTURISM",
                        "Techno phobia":"Techno phobia",
                        "Nomics":"Nomics",
                        "Prophet":"Prophet",
                        "^_^":"^_^",
                        "$_$":"$_$",
                        "iPhone":"iPhone",
                        "iPhone one":"iPhone one",
                        "iPhone two":"iPhone two",
                        "iPhone three":"iPhone three",
                        "iPhone four":"iPhone four",
                        "iPhone five":"iPhone five",
                        "iPhone six":"iPhone six",
                        "iPhone seven":"iPhone seven",
                        "iPhone eight":"iPhone eight",
                        "iPhone nine":"iPhone nine",
                        "iPhone ten":"iPhone ten",
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
            SceneInput(name: "Line width base", type: .float, inputGroupName: "Shading", value: 1.0, range: 0...50.0,
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
