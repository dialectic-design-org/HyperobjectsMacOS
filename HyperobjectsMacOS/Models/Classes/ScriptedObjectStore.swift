//
//  ScriptedObjectStore.swift
//  HyperobjectsMacOS
//
//  Objects that a live-coding script instantiates and returns in outputState, such as
//  `"Cubes": [new Cube({...}), ...]`. Each object owns a SceneInputBank: a private copy of the
//  inputs of the scene it is modelled on, so its parameters, delays, audio keys and stateful
//  values behave exactly like that scene's inputs.
//

import Foundation

/// The kinds of object a script can instantiate. The raw value is the JS class name and the
/// `__type` tag of the object in outputState.
enum ScriptedObjectKind: String, CaseIterable {
    case cube = "Cube"

    /// A fresh set of inputs for one object of this kind.
    func makeInputs() -> [SceneInput] {
        switch self {
        case .cube: return makeCubeSceneInputs()
        }
    }

    /// Parameter names and their default values, in declaration order. Built once.
    var parameterDefaults: [(name: String, value: StateValue)] {
        Self.parameterDefaultsByKind[self] ?? []
    }

    private static let parameterDefaultsByKind: [ScriptedObjectKind: [(name: String, value: StateValue)]] = {
        var result: [ScriptedObjectKind: [(name: String, value: StateValue)]] = [:]
        for kind in ScriptedObjectKind.allCases {
            result[kind] = kind.makeInputs().map { ($0.name, $0.initialStateValue()) }
        }
        return result
    }()
}

/// One scripted object, kept across script runs so its history and stateful values persist.
final class ScriptedObjectInstance {
    /// The script's `id` parameter, or "#<index>" when the object is identified by position.
    let id: String
    let kind: ScriptedObjectKind
    let bank: SceneInputBank
    /// Keys the last run set, to detect parameters the script stopped setting.
    fileprivate var appliedKeys: Set<String> = []

    // Captured views of the bank's inputs. Only the store writes the bank (script output and
    // the stateful tick), so it can keep these up to date by recapturing what it touched
    // instead of all inputs on every snapshot.
    fileprivate var entries: [SceneInputView]
    fileprivate let entryIndexByName: [String: Int]
    fileprivate let statefulEntryIndices: [Int]
    fileprivate var dirtyEntryIndices: Set<Int> = []

    fileprivate init(id: String, kind: ScriptedObjectKind) {
        self.id = id
        self.kind = kind
        let bank = SceneInputBank(inputs: kind.makeInputs())
        self.bank = bank
        self.entries = bank.inputs.map { SceneInputView(capturing: $0) }
        self.entryIndexByName = Dictionary(bank.inputs.enumerated().map { ($1.name, $0) }, uniquingKeysWith: { first, _ in first })
        self.statefulEntryIndices = bank.inputs.indices.filter { bank.inputs[$0].type == .statefulFloat }
    }

    fileprivate func markDirty(_ input: SceneInput) {
        if let index = entryIndexByName[input.name] {
            dirtyEntryIndices.insert(index)
        }
    }

    fileprivate func refreshedEntries() -> [SceneInputView] {
        for index in dirtyEntryIndices.union(statefulEntryIndices) {
            entries[index] = SceneInputView(capturing: bank.inputs[index])
        }
        dirtyEntryIndices.removeAll(keepingCapacity: true)
        return entries
    }
}

/// Immutable capture of one object for the geometry queue (taken on main).
struct ScriptedObjectSnapshot {
    let id: String
    let kind: ScriptedObjectKind
    let entries: [SceneInputView]
    let bank: SceneInputBank
}

/// What a generator finds in its `inputs` under a collection key such as "Cubes".
struct ScriptedObjectInputs {
    let id: String
    let kind: ScriptedObjectKind
    /// Same shape as a generator's `inputs`: current values, floats combined with audio.
    let inputs: [String: Any]
    /// The object's inputs, for history lookups (delays).
    let source: SceneInputProviding
}

/// The scripted objects of one scene. Main thread only.
final class ScriptedObjectStore {
    static let maxInstancesPerCollection = 64
    /// Keys of an object that are not parameters.
    static let reservedKeys: Set<String> = ["__type", "id"]

    /// outputState key -> kind of object it holds, e.g. ["Cubes": .cube].
    let collections: [String: ScriptedObjectKind]
    private(set) var instances: [String: [ScriptedObjectInstance]] = [:]
    /// Identity key of each instance (parallel to `instances`), used to find it again next run.
    private var identityKeys: [String: [String]] = [:]

    init(collections: [String: ScriptedObjectKind]) {
        self.collections = collections
    }

    func handles(_ key: String) -> Bool {
        collections[key] != nil
    }

    /// Reconciles the objects with what the script returned: creates new ones, updates the
    /// parameters of existing ones and drops the ones that are gone. A collection key that is
    /// missing from `outputState` removes all objects of that collection.
    func apply(from outputState: [String: StateValue], warningCache: ScriptOutputWarningCache) {
        for (collectionKey, kind) in collections {
            let descriptors = Self.descriptors(from: outputState[collectionKey], collectionKey: collectionKey, warningCache: warningCache)
            if descriptors.count > Self.maxInstancesPerCollection {
                warningCache.warnOnce(id: "object-cap/\(collectionKey)",
                                      "[Script Output] \(collectionKey): only the first \(Self.maxInstancesPerCollection) objects are used")
            }

            var previous: [String: ScriptedObjectInstance] = [:]
            for (key, instance) in zip(identityKeys[collectionKey] ?? [], instances[collectionKey] ?? []) {
                previous[key] = instance
            }

            var nextInstances: [ScriptedObjectInstance] = []
            var nextKeys: [String] = []
            var usedKeys: Set<String> = []

            for (index, params) in descriptors.prefix(Self.maxInstancesPerCollection).enumerated() {
                if case .string(let type)? = params["__type"], type != kind.rawValue {
                    warningCache.warnOnce(id: "object-type/\(collectionKey)/\(type)",
                                          "[Script Output] \(collectionKey) expects \(kind.rawValue) objects, ignoring a \(type)")
                    continue
                }

                // Identity: the explicit id when it is usable, otherwise the array position.
                var identityKey = "#\(index)"
                var displayID = identityKey
                if let explicit = Self.explicitID(params["id"]) {
                    let key = "id:" + explicit
                    if usedKeys.contains(key) {
                        warningCache.warnOnce(id: "object-duplicate-id/\(collectionKey)/\(explicit)",
                                              "[Script Output] \(collectionKey): id \"\(explicit)\" is used more than once; the later object is identified by its position")
                    } else {
                        identityKey = key
                        displayID = explicit
                    }
                }
                usedKeys.insert(identityKey)

                let instance: ScriptedObjectInstance
                let isNew: Bool
                if let existing = previous[identityKey] {
                    instance = existing
                    isNew = false
                } else {
                    instance = ScriptedObjectInstance(id: displayID, kind: kind)
                    isNew = true
                }

                Self.applyParameters(params, to: instance, warningCache: warningCache)

                if isNew {
                    // A new object appears complete: delayed lookups see its first values
                    // instead of the defaults it was created with.
                    for input in instance.bank.inputs {
                        input.collapseHistoryToCurrentValue()
                    }
                }

                nextInstances.append(instance)
                nextKeys.append(identityKey)
            }

            instances[collectionKey] = nextInstances
            identityKeys[collectionKey] = nextKeys
        }
    }

    func removeAll() {
        instances.removeAll()
        identityKeys.removeAll()
    }

    /// The stateful floats of all objects, for the audio tick.
    var statefulInputs: [SceneInput] {
        instances.values.flatMap { $0.flatMap { $0.bank.statefulInputs } }
    }

    func captureSnapshot() -> [String: [ScriptedObjectSnapshot]] {
        var result: [String: [ScriptedObjectSnapshot]] = [:]
        for (collectionKey, list) in instances where !list.isEmpty {
            result[collectionKey] = list.map {
                ScriptedObjectSnapshot(id: $0.id, kind: $0.kind, entries: $0.refreshedEntries(), bank: $0.bank)
            }
        }
        return result
    }

    // MARK: - Parsing

    /// The object descriptors under a collection key. Accepts an array of objects, a single
    /// object, or an empty array (which `StateValue.fromJSONValue` reports as empty line
    /// segments or an empty float array).
    private static func descriptors(from value: StateValue?, collectionKey: String, warningCache: ScriptOutputWarningCache) -> [[String: StateValue.Value]] {
        guard let value else { return [] }
        switch value.value {
        case .array(let elements):
            var result: [[String: StateValue.Value]] = []
            for element in elements {
                if case .object(let params) = element {
                    result.append(params)
                } else {
                    warningCache.warnOnce(id: "object-element/\(collectionKey)",
                                          "[Script Output] \(collectionKey): ignoring array elements that are not objects")
                }
            }
            return result
        case .object(let params):
            return [params]
        case .lineSegments(let segments) where segments.isEmpty:
            return []
        case .floatArray(let values) where values.isEmpty:
            return []
        default:
            warningCache.warnOnce(id: "object-collection/\(collectionKey)",
                                  "[Script Output] \(collectionKey) should be an array of objects, got \(value)")
            return []
        }
    }

    private static func explicitID(_ value: StateValue.Value?) -> String? {
        switch value {
        case .string(let s)?:
            return s.isEmpty ? nil : s
        case .float(let d)?:
            guard d.isFinite else { return nil }
            if d == d.rounded(), let i = safeInt(d) { return String(i) }
            return String(d)
        default:
            return nil
        }
    }

    // MARK: - Applying parameters

    private static func applyParameters(_ params: [String: StateValue.Value], to instance: ScriptedObjectInstance, warningCache: ScriptOutputWarningCache) {
        let keys = Set(params.keys).subtracting(reservedKeys)
        let byName = instance.bank.inputsByName

        // Parameters the script no longer sets go back to their default.
        for key in instance.appliedKeys.subtracting(keys) {
            guard let (input, target) = ScriptInputApplier.resolve(key, in: byName),
                  let base = ScriptInputApplier.baseValue(of: input, target: target) else { continue }
            let current = ScriptInputApplier.currentValue(of: input, target: target)
            if current.value == base.value { continue }
            ScriptInputApplier.apply(key: key, value: base, current: current, inputsByName: byName, warningCache: warningCache)
            instance.markDirty(input)
        }

        for key in keys {
            guard let raw = params[key] else { continue }
            guard let (input, target) = ScriptInputApplier.resolve(key, in: byName) else {
                warningCache.warnOnce(id: "object-key/\(instance.kind.rawValue)/\(key)",
                                      "[Script Output] \(instance.kind.rawValue) has no parameter \"\(key)\"; ignored")
                continue
            }
            // Keep the previous value rather than writing NaN or infinity into an input.
            if case .float(let number) = raw, !number.isFinite { continue }
            let new = StateValue(value: raw)
            let current = ScriptInputApplier.currentValue(of: input, target: target)
            if current.value == new.value { continue }
            ScriptInputApplier.apply(key: key, value: new, current: current, inputsByName: byName, warningCache: warningCache)
            instance.markDirty(input)
        }

        instance.appliedKeys = keys
    }
}
