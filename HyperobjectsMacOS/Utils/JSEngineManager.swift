//
//  JSEngineManager.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 08/10/2025.
//

import SwiftUI
import JavaScriptCore
import UniformTypeIdentifiers
import Combine
import simd

struct StateValue {
    enum Value {
        case float(Double)
        case vector3(SIMD3<Double>)
        case vector4(SIMD4<Double>)
        case object([String: Value])
    }
    
    var value: Value
}

extension StateValue {
    func toJSONValue() -> Any {
        switch value {
        case .float(let f):
            return f
        case .vector3(let v):
            return ["x": v.x, "y": v.y, "z": v.z]
        case .vector4(let v):
            return ["x": v.x, "y": v.y, "z": v.z, "w": v.w]
        case .object(let dict):
            return dict.mapValues { value -> Any in
                return StateValue(value: value).toJSONValue()
            }
        }
    }
    
    static func fromJSONValue(_ jsonValue: Any) -> StateValue? {
        if let number = jsonValue as? Double {
            return StateValue(value: .float(number))
        } else if let dict = jsonValue as? [String: Any] {
            if let x = dict["x"] as? Double,
               let y = dict["y"] as? Double,
               let z = dict["z"] as? Double {
                return StateValue(value: .vector3(SIMD3<Double>(
                    Double(x),
                    Double(y),
                    Double(z)
                )))
            }
            
            var objDict: [String: StateValue.Value] = [:]
            for (key, val) in dict {
                if let stateVal = fromJSONValue(val) {
                    objDict[key] = stateVal.value
                }
            }
            return StateValue(value: .object(objDict))
        } else if let array = jsonValue as? [Double], array.count == 3 {
            return StateValue(value: .vector3(SIMD3<Double>(
                array[0],
                array[1],
                array[2]
            )))
        } else if let array = jsonValue as? [Double], array.count == 4 {
            return StateValue(value: .vector4(SIMD4<Double>(
                array[0],
                array[1],
                array[2],
                array[3]
            )))
        }
        return nil
    }
}

class JSEngineManager: ObservableObject {
    @Published var outputState: [String: StateValue] = [:]
    @Published var errorMessage: String?
    @Published var lastExecutionTime: Date?
    @Published var executionDuration: Double = 0
    
    private var context: JSContext?
    
    init() {
        setupContext()
    }
    
    func setupContext() {
        context = JSContext()
        
        // Setup console.log for debugging
        let consoleLog: @convention(block) (String) -> Void = { message in
            print("JS Console: \(message)")
        }
        context?.setObject(consoleLog, forKeyedSubscript: "consoleLog" as NSString)
        
        context?.evaluateScript("""
            var console = {
                log: function() {
                    var args = Array.prototype.slice.call(arguments);
                    consoleLog(args.join(' '));
                }
            };
        """)
    }
    
    func executeScript(_ script: String, inputState: [String: StateValue]) -> Bool {
        guard let context = context else { return false }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Reset context for clean execution
        setupContext()
        
        let jsonCompatibleInput = inputState.mapValues { $0.toJSONValue() }

        // Inject input state FIRST
        let inputJSON = try? JSONSerialization.data(withJSONObject: jsonCompatibleInput)
        if let inputJSON = inputJSON,
           let inputString = String(data: inputJSON, encoding: .utf8) {
            context.evaluateScript("var inputState = \(inputString);")
        }
        
        // Now execute the script with inputState available
        context.evaluateScript(script)
        
        // Check for errors (compilation or runtime)
        if let exception = context.exception {
            errorMessage = "Error: \(exception.toString() ?? "Unknown")"
            return false
        }
        
        // Extract output state
        // print("Extracting output state")
        if let output = context.objectForKeyedSubscript("outputState"),
           !output.isUndefined,
           let outputDict = output.toDictionary() as? [String: Any] {
            var parsedOutput: [String: StateValue] = [:]
            for (key, value) in outputDict {
                // print("Extracting key \(key)")
                if let stateValue = StateValue.fromJSONValue(value) {
                    parsedOutput[key] = stateValue
                }
            }
            let endTime = CFAbsoluteTimeGetCurrent()
            let duration = (endTime - startTime) * 1000
            DispatchQueue.main.async {
                self.outputState = parsedOutput
                self.errorMessage = nil
                self.lastExecutionTime = Date()
                self.executionDuration = duration
            }
            return true
        } else {
            let endTime = CFAbsoluteTimeGetCurrent()
            let duration = (endTime - startTime) * 1000
            DispatchQueue.main.async {
                self.errorMessage = "No outputState object found or invalid format"
                self.executionDuration = duration
            }
            return false
        }
    }
}
