//
//  MIDIManager.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 24/05/2026.
//

import Foundation
import CoreMIDI
import SwiftUI
import Combine

class MIDIManager: ObservableObject {
    @Published var logEntries: [String] = []
    @Published var lastSignalUpdate: UInt64 = 0
    @Published var lastCCUpdate: UInt64 = 0
    
    let controls = MIDIControlState()
    
    private var midiClient = MIDIClientRef()
    private var inputPort = MIDIPortRef()
    private let maxLogEntries = 1000
    
    init() {
        setupMIDI()
    }
    
    deinit {
        MIDIClientDispose(midiClient)
    }
    
    private func setupMIDI() {
        let clientName = "HyperobjectsMacOS" as CFString
        let status = MIDIClientCreate(clientName, nil, nil, &midiClient)
        
        if status != noErr {
            addLogEntry("Failed to create MIDI client: \(status)")
            return
        }
        
        let portName = "Input Port" as CFString
        let inputStatus = MIDIInputPortCreate(
            midiClient,
            portName,
            midiReadProc,
            Unmanaged.passUnretained(self).toOpaque(),
            &inputPort
        )
        
        if inputStatus != noErr {
            addLogEntry("Failed to create input port: \(inputStatus)")
            return
        }
        
        connectToAllSources()
        
        addLogEntry("MIDI system initialized successfully")
        addLogEntry("Listening for MIDI messages...")
    }
    
    private func connectToAllSources() {
        let sourceCount = MIDIGetNumberOfSources()
        
        for i in 0..<sourceCount {
            let source = MIDIGetSource(i)
            if source != 0 {
                let connectStatus = MIDIPortConnectSource(inputPort, source, nil)
                if connectStatus == noErr {
                    var name: Unmanaged<CFString>?
                    let nameStatus = MIDIObjectGetStringProperty(source, kMIDIPropertyName, &name)
                    let sourceName = (nameStatus == noErr && name != nil) ? name!.takeUnretainedValue() as String : "Unknown Source"
                    addLogEntry("Connected to MIDI source: \(sourceName)")
                } else {
                    addLogEntry("Failed to connect to MIDI source \(i): \(connectStatus)")
                }
            }
        }
    }
    
    private func addLogEntry(_ message: String) {
        DispatchQueue.main.async {
            let timestamp = DateFormatter.timeFormatter.string(from: Date())
            let entry = "[\(timestamp)] \(message)"
            
            self.logEntries.append(entry)
            
            if self.logEntries.count > self.maxLogEntries {
                self.logEntries.removeFirst((self.logEntries.count - self.maxLogEntries))
            }
        }
    }
    
    func clearLog() {
        logEntries.removeAll()
        addLogEntry("Log cleared")
    }
    
    func processMIDIPacket(_ packet: UnsafePointer<MIDIPacket>) {
        let pkt = packet.pointee
        let length = Int(pkt.length)
        let dataArray: [UInt8] = withUnsafeBytes(of: pkt.data) { rawBuf in
            Array(rawBuf.prefix(length))
        }
        
        let hexData = dataArray.map { String(format: "%02X", $0) }.joined(separator: " ")
        let message = interpretMIDIMessage(dataArray)
        addLogEntry("MIDI: \(hexData) - \(message)")
        
        controls.ingest(bytes: dataArray, timeStamp: pkt.timeStamp)
        
        let channelMessages = MIDIControlState.channelVoiceMessages(in: dataArray)
        let hasSceneSignal = channelMessages.contains { message in
            switch message.type {
            case 0x80, 0x90, 0xB0:
                return true
            default:
                return false
            }
        }
        let hasCC = channelMessages.contains { $0.type == 0xB0 }

        if hasSceneSignal || hasCC {
            DispatchQueue.main.async {
                if hasSceneSignal { self.lastSignalUpdate &+= 1 }
                if hasCC { self.lastCCUpdate &+= 1 }
            }
        }
    }
    
    private func interpretMIDIMessage(_ data: [UInt8]) -> String {
        guard !data.isEmpty else { return "Empty message" }
        
        let status = data[0]
        let messageType = status & 0xF0
        let channel = (status & 0x0F) + 1
        
        switch messageType {
        case 0x80:
            if data.count >= 3 {
                return "Note Off - Channel: \(channel), Note: \(data[1]), Velocity: \(data[2])"
            }
        case 0x90:
            if data.count >= 3 {
                let velocity = data[2]
                if velocity == 0 {
                    return "Note Off - Channel: \(channel), Note: \(data[1]), Velocity: 0"
                } else {
                    return "Note On - Channel: \(channel), Note: \(data[1]), Velocity: \(velocity)"
                }
            }
        case 0xA0:
            if data.count >= 3 {
                return "Polyphonic Key Pressure - Channel: \(channel), Note: \(data[1]), Pressure: \(data[2])"
            }
        case 0xB0:
            if data.count >= 3 {
                return "Control Change - Channel: \(channel), Controller: \(data[1]), Value: \(data[2])"
            }
        case 0xC0:
            if data.count >= 2 {
                return "Program Change - Channel: \(channel), Program: \(data[1])"
            }
        case 0xD0:
            if data.count >= 2 {
                return "Channel Pressure - Channel: \(channel), Pressure: \(data[1])"
            }
        case 0xE0:
            if data.count >= 3 {
                let value = Int(data[1]) | (Int(data[2]) << 7)
                return "Pitch Bend - Channel: \(channel), Value: \(value)"
            }
        case 0xF0:
            switch status {
            case 0xF0:
                return "System Exclusive (SysEx) - Length: \(data.count)"
            case 0xF1:
                return "MIDI Time Code Quarter Frame"
            case 0xF2:
                if data.count >= 3 {
                    let position = Int(data[1]) | (Int(data[2]) << 7)
                    return "Song Position Pointer - Position: \(position)"
                }
            case 0xF3:
                if data.count >= 2 {
                    return "Song Select - Song: \(data[1])"
                }
            case 0xF6:
                return "Tune Request"
            case 0xF7:
                return "End of System Exclusive"
            case 0xF8:
                return "Timing Clock"
            case 0xFA:
                return "Start"
            case 0xFB:
                return "Continue"
            case 0xFC:
                return "Stop"
            case 0xFE:
                return "Active Sensing"
            case 0xFF:
                return "System Reset"
            default:
                return "Unknown System Message"
            }

            
        default:
            break
        }
        
        
        return "Unknown MIDI message"
    }
}

func midiReadProc(
    packetList: UnsafePointer<MIDIPacketList>,
    readProcRefCon: UnsafeMutableRawPointer?,
    srcConnRefCon: UnsafeMutableRawPointer?
) {
    guard let refCon = readProcRefCon else { return }
    let midiManager = Unmanaged<MIDIManager>.fromOpaque(refCon).takeUnretainedValue()
    
    var packet = packetList.pointee.packet
    for _ in 0..<packetList.pointee.numPackets {
        midiManager.processMIDIPacket(&packet)
        packet = MIDIPacketNext(&packet).pointee
    }
}

extension DateFormatter {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}
