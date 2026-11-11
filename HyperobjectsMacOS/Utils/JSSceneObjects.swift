//
//  JSSceneObjects.swift
//  HyperobjectsMacOS
//
//  JavaScript classes for objects a live-coding script can instantiate and return in
//  outputState, e.g. `"Cubes": [new Cube({ "Width": 0.3 })]`. The Swift side is
//  ScriptedObjectStore.
//
//  Expects the global `__sceneObjectSchemas` ({ Cube: { "<parameter name>": <default>, ... } }),
//  which JSEngineManager injects from ScriptedObjectKind before evaluating this source.
//

let JSSceneObjectClasses = """

var __sceneObjectKeyPrefixes = ['audio_add_', 'audio_multiply_offset_', 'audio_multiply_',
                                'audio_delay_', 'audio_smoothed_source_', 'frame_tick_'];

// Levenshtein distance. Only used to build the "Did you mean" hint when a name is rejected.
function __editDistance(a, b) {
    var prev = [], i, j;
    for (j = 0; j <= b.length; j++) { prev[j] = j; }
    for (i = 1; i <= a.length; i++) {
        var cur = [i];
        for (j = 1; j <= b.length; j++) {
            cur[j] = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
        }
        prev = cur;
    }
    return prev[b.length];
}

// Proxy handler around every scene object: rejects assignments of names the object's kind
// does not have, so a misspelled parameter throws wherever it is set.
var __sceneObjectGuard = {
    set: function (target, key, value) {
        if (typeof key === 'string' && key !== '__type' && !target.constructor.accepts(key)) {
            var hint = target.constructor.suggestion(key);
            throw new Error(target.__type + ' has no parameter "' + key + '"' +
                            (hint ? '. Did you mean "' + hint + '"?' : ''));
        }
        target[key] = value;
        return true;
    }
};

class SceneObject {
    constructor(type, params) {
        this.__type = type;
        var guarded = new Proxy(this, __sceneObjectGuard);
        if (params) { guarded.set(params); }
        return guarded;   // `new Cube()` evaluates to the guarded object
    }

    // Parameter names and defaults of this kind (the same list as the Swift inputs). Walks up
    // the class chain, so a script's own `class Spinner extends Cube` uses the Cube parameters.
    static get defaults() {
        for (var c = this; typeof c === 'function' && c.name; c = Object.getPrototypeOf(c)) {
            if (Object.prototype.hasOwnProperty.call(__sceneObjectSchemas, c.name)) { return __sceneObjectSchemas[c.name]; }
        }
        return {};
    }

    static prefixOf(key) {
        for (var i = 0; i < __sceneObjectKeyPrefixes.length; i++) {
            if (key.indexOf(__sceneObjectKeyPrefixes[i]) === 0) { return __sceneObjectKeyPrefixes[i]; }
        }
        return '';
    }

    static accepts(key) {
        var d = this.defaults;
        if (key === 'id' || Object.prototype.hasOwnProperty.call(d, key)) { return true; }
        var p = this.prefixOf(key);
        return p !== '' && Object.prototype.hasOwnProperty.call(d, key.slice(p.length));
    }

    // The closest existing name, or null. Catches typos and wrong capitalisation.
    static suggestion(key) {
        var p = this.prefixOf(key), base = key.slice(p.length).toLowerCase();
        var best = null, bestDistance = Infinity;
        for (var name in this.defaults) {
            var distance = __editDistance(base, name.toLowerCase());
            if (distance < bestDistance) { bestDistance = distance; best = name; }
        }
        return best !== null && bestDistance <= Math.max(2, Math.floor(base.length / 4)) ? p + best : null;
    }

    // set("Width", 0.3) or set({ "Width": 0.3, "Height": 0.8 }). Chainable.
    set(nameOrParams, value) {
        var params = nameOrParams;
        if (typeof nameOrParams === 'string') { params = {}; params[nameOrParams] = value; }
        for (var key in params) {
            if (!Object.prototype.hasOwnProperty.call(params, key) || key === '__type') { continue; }
            this[key] = params[key];   // goes through the guard
        }
        return this;
    }

    // The value set on this object, or the default.
    get(name) {
        return Object.prototype.hasOwnProperty.call(this, name) ? this[name] : this.constructor.defaults[name];
    }

    // Removes a parameter again, so it falls back to its default.
    unset(name) { delete this[name]; return this; }
}

class Cube extends SceneObject {
    constructor(params) { super('Cube', params); }
}

"""
