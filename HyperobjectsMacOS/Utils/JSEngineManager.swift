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

struct LineStateValue {
    var start: SIMD3<Double>
    var end: SIMD3<Double>
    var lineWidthStart: Double
    var lineWidthEnd: Double
    var colorStart: SIMD4<Double>
    var colorEnd: SIMD4<Double>
}

struct StateValue {
    enum Value {
        case float(Double)
        case floatArray([Double])
        case vector3(SIMD3<Double>)
        case vector4(SIMD4<Double>)
        case object([String: Value])
        case lineSegments([LineStateValue])
    }
    
    var value: Value
}

extension StateValue {
    func toJSONValue() -> Any {
        switch value {
        case .float(let f):
            return f
        case .floatArray(let a):
            return a as Any
        case .vector3(let v):
            return ["x": v.x, "y": v.y, "z": v.z]
        case .vector4(let v):
            return ["x": v.x, "y": v.y, "z": v.z, "w": v.w]
        case .object(let dict):
            return dict.mapValues { value -> Any in
                return StateValue(value: value).toJSONValue()
            }
        case .lineSegments(let segments):
            return segments.map { l -> Any in
                return [
                    "start": ["x": l.start.x, "y": l.start.y, "z": l.start.z],
                    "end": ["x": l.end.x, "y": l.end.y, "z": l.end.z],
                    "lineWidthStart": l.lineWidthStart,
                    "lineWidthEnd": l.lineWidthEnd,
                    "colorStart": ["x": l.colorStart.x, "y": l.colorStart.y, "z": l.colorStart.z, "w": l.colorStart.w],
                    "colorEnd": ["x": l.colorEnd.x, "y": l.colorEnd.y, "z": l.colorEnd.z, "w": l.colorEnd.w]
                ]
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
        } else if let array = jsonValue as? [Any] {
            if let doubleArray = array as? [Double], doubleArray.count == 3 {
                return StateValue(value: .vector3(SIMD3<Double>(
                    doubleArray[0],
                    doubleArray[1],
                    doubleArray[2]
                )))
            } else if let doubleArray = array as? [Double], doubleArray.count == 4 {
                return StateValue(value: .vector4(SIMD4<Double>(
                    doubleArray[0],
                    doubleArray[1],
                    doubleArray[2],
                    doubleArray[3]
                )))
            } else if let lineDicts = array as? [[String: Any]] {
                var segments: [LineStateValue] = []
                for lineDict in lineDicts {
                    guard let startDict = lineDict["start"] as? [String: Any],
                          let endDict = lineDict["end"] as? [String: Any],
                          let startValue = fromJSONValue(startDict),
                          case let .vector3(startVec) = startValue.value,
                          let endValue = fromJSONValue(endDict),
                          case let .vector3(endVec) = endValue.value else {
                        return nil
                    }
                    let lineWidthStart: Double = lineDict["lineWidthStart"] as? Double ?? 1.0
                    let lineWidthEnd: Double = lineDict["lineWidthEnd"] as? Double ?? 1.0
                    let colorStart: [Double] = (lineDict["colorStart"] as? [Double]) ?? [1.0, 1.0, 1.0, 1.0]
                    let colorEnd: [Double] = (lineDict["colorEnd"] as? [Double]) ?? [1.0, 1.0, 1.0, 1.0]
                    segments.append(LineStateValue(
                        start: startVec,
                        end: endVec,
                        lineWidthStart: lineWidthStart,
                        lineWidthEnd: lineWidthEnd,
                        colorStart: SIMD4<Double>(colorStart),
                        colorEnd: SIMD4<Double>(colorEnd)
                    ))
                }
                return StateValue(value: .lineSegments(segments))
            } else if let floatArray = array as? [Double] {
                return StateValue(value: .floatArray(array as! [Double]))
            }
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
    
    private let jsQueue = DispatchQueue(label: "JSEngineManager.JSQueue")
    
    init() {
        jsQueue.async { [weak self] in
            self?.setupContext()
        }
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
        jsQueue.async { [weak self] in
            guard let self = self else { return }
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Reset context for clean execution
            self.setupContext()
            
            guard let context = self.context else {
                DispatchQueue.main.async {
                    self.errorMessage = "JS context not available"
                }
                return
            }
            
            
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
                let endTime = CFAbsoluteTimeGetCurrent()
                let duration = (endTime - startTime) * 1000
                DispatchQueue.main.async { // CHANGE: main-thread UI update
                    self.errorMessage = "Error: \(exception.toString() ?? "Unknown")"
                    self.executionDuration = duration
                }
                return
            }
            
            // Extract output state
            // print("Extracting output state")
            if let output = context.objectForKeyedSubscript("outputState"),
               !output.isUndefined,
               let outputDict = output.toDictionary() as? [String: Any] {
                var parsedOutput: [String: StateValue] = [:]
                for (key, value) in outputDict {
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
                return
            } else {
                let endTime = CFAbsoluteTimeGetCurrent()
                let duration = (endTime - startTime) * 1000
                DispatchQueue.main.async {
                    self.errorMessage = "No outputState object found or invalid format"
                    self.executionDuration = duration
                }
                return
            }
        }
        return true
    }
}
