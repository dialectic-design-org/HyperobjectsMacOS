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
            
            // OPTIMIZATION: Handle packed line segments
            if let packed = dict["lineSegments_packed"] as? [String: Any],
               let count = packed["count"] as? Double, // JS numbers come as Double
               let starts = packed["starts"] as? [Double],
               let ends = packed["ends"] as? [Double],
               let widths = packed["widths"] as? [Double],
               let colors = packed["colors"] as? [Double] {
                
                let countInt = Int(count)
                var segments: [LineStateValue] = []
                segments.reserveCapacity(countInt)
                
                for i in 0..<countInt {
                    let i3 = i * 3
                    let i2 = i * 2
                    let i8 = i * 8
                    
                    // Safety check for array bounds
                    if i3 + 2 < starts.count && i3 + 2 < ends.count &&
                       i2 + 1 < widths.count && i8 + 7 < colors.count {
                        
                        segments.append(LineStateValue(
                            start: SIMD3<Double>(starts[i3], starts[i3+1], starts[i3+2]),
                            end: SIMD3<Double>(ends[i3], ends[i3+1], ends[i3+2]),
                            lineWidthStart: widths[i2],
                            lineWidthEnd: widths[i2+1],
                            colorStart: SIMD4<Double>(colors[i8], colors[i8+1], colors[i8+2], colors[i8+3]),
                            colorEnd: SIMD4<Double>(colors[i8+4], colors[i8+5], colors[i8+6], colors[i8+7])
                        ))
                    }
                }
                return StateValue(value: .lineSegments(segments))
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
    @Published var warningMessage: String?
    @Published var lastExecutionTime: Date?
    @Published var executionDuration: Double = 0
    
    private var context: JSContext?
    private var currentScript: String = ""
    private var consecutiveErrors: Int = 0
    
    private let jsQueue = DispatchQueue(label: "JSEngineManager.JSQueue")
    
    init() {
        jsQueue.async { [weak self] in
            self?.setupContext()
        }
    }
    
    func setupContext() {
        context = JSContext()
        currentScript = "" // Reset script cache
        
        // Setup console.log for debugging
        let consoleLog: @convention(block) (String) -> Void = { message in
            print("JS Console: \(message)")
        }
        context?.setObject(consoleLog, forKeyedSubscript: "consoleLog" as NSString)
        
        
        var scriptToEvaluate = JSHelperClasses + """
        var console = {
            log: function() {
                var args = Array.prototype.slice.call(arguments);
                consoleLog(args.join(' '));
            }
        };
        """
        context?.evaluateScript(scriptToEvaluate)
    }
    
    func executeScript(_ script: String, inputState: [String: StateValue]) -> Bool {
        let requestTime = CFAbsoluteTimeGetCurrent()
        
        jsQueue.async { [weak self] in
            guard let self = self else { return }
            
            let startTime = CFAbsoluteTimeGetCurrent()
            let queueLatency = startTime - requestTime
            
            // Log if we are falling behind (latency > 33ms / 2 frames)
            if queueLatency > 0.033 {
                print("⚠️ JS Queue Backpressure: Waited \(String(format: "%.1f", queueLatency * 1000))ms before execution started.")
            }
            
            // OPTIMIZATION: Only recreate context if it doesn't exist
            if self.context == nil {
                self.setupContext()
            }
            
            guard let context = self.context else {
                DispatchQueue.main.async {
                    self.errorMessage = "JS context not available"
                }
                return
            }
            
            // OPTIMIZATION: Only evaluate the script if it has changed
            if script != self.currentScript {
                // Wrap user script in a function to avoid re-parsing overhead
                // and to allow repeated execution.
                // We also try to return outputState if it exists, to support 'var outputState = ...'
                let wrappedScript = """
                var __optimizeOutput = function(output) {
                    if (!output || typeof output !== 'object') return output;
                    if (output.lineSegments && Array.isArray(output.lineSegments) && output.lineSegments.length > 0) {
                        var segs = output.lineSegments;
                        var count = segs.length;
                        var starts = new Float64Array(count * 3);
                        var ends = new Float64Array(count * 3);
                        var widths = new Float64Array(count * 2);
                        var colors = new Float64Array(count * 8); // 4 for start, 4 for end
                        
                        for (var i = 0; i < count; i++) {
                            var s = segs[i];
                            var i3 = i * 3;
                            var i2 = i * 2;
                            var i8 = i * 8;
                            
                            // Start
                            if (s.start) {
                                starts[i3] = s.start.x || 0;
                                starts[i3+1] = s.start.y || 0;
                                starts[i3+2] = s.start.z || 0;
                            }
                            
                            // End
                            if (s.end) {
                                ends[i3] = s.end.x || 0;
                                ends[i3+1] = s.end.y || 0;
                                ends[i3+2] = s.end.z || 0;
                            }
                            
                            // Widths
                            widths[i2] = s.lineWidthStart || 1;
                            widths[i2+1] = s.lineWidthEnd || 1;
                            
                            // Colors
                            if (s.colorStart) {
                                if (Array.isArray(s.colorStart)) {
                                    colors[i8] = s.colorStart[0];
                                    colors[i8+1] = s.colorStart[1];
                                    colors[i8+2] = s.colorStart[2];
                                    colors[i8+3] = s.colorStart[3];
                                } else {
                                    colors[i8] = s.colorStart.x || 0;
                                    colors[i8+1] = s.colorStart.y || 0;
                                    colors[i8+2] = s.colorStart.z || 0;
                                    colors[i8+3] = s.colorStart.w || 1;
                                }
                            } else {
                                colors[i8] = 1; colors[i8+1] = 1; colors[i8+2] = 1; colors[i8+3] = 1;
                            }
                            
                            if (s.colorEnd) {
                                if (Array.isArray(s.colorEnd)) {
                                    colors[i8+4] = s.colorEnd[0];
                                    colors[i8+5] = s.colorEnd[1];
                                    colors[i8+6] = s.colorEnd[2];
                                    colors[i8+7] = s.colorEnd[3];
                                } else {
                                    colors[i8+4] = s.colorEnd.x || 0;
                                    colors[i8+5] = s.colorEnd.y || 0;
                                    colors[i8+6] = s.colorEnd.z || 0;
                                    colors[i8+7] = s.colorEnd.w || 1;
                                }
                            } else {
                                colors[i8+4] = 1; colors[i8+5] = 1; colors[i8+6] = 1; colors[i8+7] = 1;
                            }
                        }
                        
                        output.lineSegments_packed = {
                            count: count,
                            starts: starts,
                            ends: ends,
                            widths: widths,
                            colors: colors
                        };
                        // Optional: remove original to save bridging time, though strictly not needed if we just ignore it in Swift
                        // delete output.lineSegments; 
                    }
                    return output;
                };

                var userMain = function() {
                    \(script)
                    if (typeof outputState !== 'undefined') { return __optimizeOutput(outputState); }
                };
                """
                context.evaluateScript(wrappedScript)
                self.currentScript = script
            }
            
            // Inject input state directly as JSValues
            let jsInputState = JSValue(newObjectIn: context)
            for (key, stateVal) in inputState {
                if let jsVal = stateVal.toJSValue(in: context) {
                    jsInputState?.setValue(jsVal, forProperty: key)
                }
            }
            context.setObject(jsInputState, forKeyedSubscript: "inputState" as NSString)
            
            // Execute the user function
            let userMain = context.objectForKeyedSubscript("userMain")
            let result = userMain?.call(withArguments: [])
            
            // Check for errors (compilation or runtime)
            if let exception = context.exception {
                self.consecutiveErrors += 1
                if self.consecutiveErrors % 60 == 0 {
                     print("⚠️ High Error Rate: \(self.consecutiveErrors) consecutive errors. This may degrade performance.")
                }
                
                let endTime = CFAbsoluteTimeGetCurrent()
                let duration = (endTime - startTime) * 1000
                let errorString = "Error: \(exception.toString() ?? "Unknown")"
                
                DispatchQueue.main.async {
                    // Optimization: Only update if changed to avoid UI thrashing
                    if self.errorMessage != errorString {
                        self.errorMessage = errorString
                    }
                    self.executionDuration = duration
                }
                // Clear exception for next run
                context.exception = nil
                return
            }
            
            self.consecutiveErrors = 0
            
            // Extract output state
            // First check the return value of the function (supports 'var outputState = ...')
            var output: JSValue? = result
            
            // If return value is undefined, check global scope (supports 'outputState = ...')
            if output == nil || output!.isUndefined {
                output = context.objectForKeyedSubscript("outputState")
            }
            
            if let output = output,
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
                
                if duration > 16.0 {
                     print("⚠️ Slow Script: Execution took \(String(format: "%.1f", duration))ms")
                }
                
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
    
    // Replace non-finite numbers (NaN/Inf) with 0 and accumulate warnings with their paths.
    private func sanitizedJSONValue(_ value: Any, warnings: inout [String], path: String = "root") -> Any {
        if let number = value as? NSNumber {
            let doubleValue = number.doubleValue
            if doubleValue.isNaN || !doubleValue.isFinite {
                warnings.append("\(path) replaced non-finite number with 0")
                return 0.0
            }
            return value
        } else if let dict = value as? [String: Any] {
            var newDict: [String: Any] = [:]
            for (key, val) in dict {
                newDict[key] = sanitizedJSONValue(val, warnings: &warnings, path: "\(path).\(key)")
            }
            return newDict
        } else if let array = value as? [Any] {
            return array.enumerated().map { index, element in
                sanitizedJSONValue(element, warnings: &warnings, path: "\(path)[\(index)]")
            }
        }
        return value
    }
}

extension StateValue {
    func toJSValue(in context: JSContext) -> JSValue? {
        switch value {
        case .float(let f):
            return JSValue(double: f, in: context)
        case .floatArray(let a):
            return JSValue(object: a, in: context)
        case .vector3(let v):
            let obj = JSValue(newObjectIn: context)
            obj?.setValue(v.x, forProperty: "x")
            obj?.setValue(v.y, forProperty: "y")
            obj?.setValue(v.z, forProperty: "z")
            return obj
        case .vector4(let v):
            let obj = JSValue(newObjectIn: context)
            obj?.setValue(v.x, forProperty: "x")
            obj?.setValue(v.y, forProperty: "y")
            obj?.setValue(v.z, forProperty: "z")
            obj?.setValue(v.w, forProperty: "w")
            return obj
        case .object(let dict):
            let obj = JSValue(newObjectIn: context)
            for (k, v) in dict {
                if let jsVal = StateValue(value: v).toJSValue(in: context) {
                    obj?.setValue(jsVal, forProperty: k)
                }
            }
            return obj
        case .lineSegments(let segments):
            let arr = JSValue(newArrayIn: context)
            for (i, seg) in segments.enumerated() {
                let segObj = JSValue(newObjectIn: context)
                
                let start = JSValue(newObjectIn: context)
                start?.setValue(seg.start.x, forProperty: "x")
                start?.setValue(seg.start.y, forProperty: "y")
                start?.setValue(seg.start.z, forProperty: "z")
                segObj?.setValue(start, forProperty: "start")
                
                let end = JSValue(newObjectIn: context)
                end?.setValue(seg.end.x, forProperty: "x")
                end?.setValue(seg.end.y, forProperty: "y")
                end?.setValue(seg.end.z, forProperty: "z")
                segObj?.setValue(end, forProperty: "end")
                
                segObj?.setValue(seg.lineWidthStart, forProperty: "lineWidthStart")
                segObj?.setValue(seg.lineWidthEnd, forProperty: "lineWidthEnd")
                
                let colorStart = JSValue(newObjectIn: context)
                colorStart?.setValue(seg.colorStart.x, forProperty: "x")
                colorStart?.setValue(seg.colorStart.y, forProperty: "y")
                colorStart?.setValue(seg.colorStart.z, forProperty: "z")
                colorStart?.setValue(seg.colorStart.w, forProperty: "w")
                segObj?.setValue(colorStart, forProperty: "colorStart")
                
                let colorEnd = JSValue(newObjectIn: context)
                colorEnd?.setValue(seg.colorEnd.x, forProperty: "x")
                colorEnd?.setValue(seg.colorEnd.y, forProperty: "y")
                colorEnd?.setValue(seg.colorEnd.z, forProperty: "z")
                colorEnd?.setValue(seg.colorEnd.w, forProperty: "w")
                segObj?.setValue(colorEnd, forProperty: "colorEnd")
                
                arr?.setValue(segObj, at: i)
            }
            return arr
        }
    }
}
