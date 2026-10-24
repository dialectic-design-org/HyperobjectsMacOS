//
//  JSInternalStateRuntime.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 24/10/2026.
//

let JSInternalStateRuntime = """
var internalState = {};

var runtime = {
    now: 0,
    dt: 0,
    frame: 0,
    runsSinceLoad: 0,
    isFirstRun: true,
    scriptReloaded: false
};

function persist(key, init) {
    if (!Object.prototype.hasOwnProperty.call(internalState, key)) {
        internalState[key] = (typeof init === 'function') ? init() : init;
    }
    return internalState[key];
}

function resetInternalState(key) {
    if (key !== undefined) {
        delete internalState[key];
        return;
    }
    for (var k in internalState) {
        if (Object.prototype.hasOwnProperty.call(internalState, k)) {
            delete internalState[k];
        }
    }
}

function internalStateVersion(version) {
    if (internalState.__version !== version) {
        resetInternalState();
        internalState.__version = version;
    }
}

function __describeInternalState() {
    var seen = [];
    try {
        return JSON.stringify(internalState, function (key, value) {
            if (ArrayBuffer.isView(value)) { return Array.prototype.slice.call(value, 0, 64); }
            if (typeof value === 'function') { return '[function]'; }
            if (value instanceof Map) { return Object.fromEntries(value); }
            if (value && typeof value === 'object') {
                if (seen.indexOf(value) !== -1) { return '[circular]'; }
                seen.push(value);
            }
            return value;
        }, 2);
    } catch (e) {
        return 'Unable to describe internalState: ' + e;
    }
}

var Weights = {
    uniform: function (age) { return 1; },
    linear: function (age) { return Math.max(0, 1 - age); },
    exponential: function (k) {
        var kk = (k === undefined) ? 4 : k;
        return function (age) { return Math.exp(-kk * age); };
    },
    gaussian: function (sigma) {
        var s = (sigma === undefined) ? 0.4 : sigma;
        return function (age) { return Math.exp(-(age * age) / (2 * s * s)); };
    }
};

class TimeSeries {
    constructor(maxAge = 1.0, maxSamples = 4096) {
        this.maxAge = maxAge;
        this.maxSamples = maxSamples;
        this.times = [];
        this.values = [];
    }

    get length() { return this.times.length; }
    get latest() { return this.values.length ? this.values[this.values.length - 1] : undefined; }
    get latestTime() { return this.times.length ? this.times[this.times.length - 1] : undefined; }

    push(time, value) {
        if (!Number.isFinite(time) || !Number.isFinite(value)) { return this; }
        var n = this.times.length;
        if (n > 0 && time < this.times[n - 1]) {
            this.clear();
        } else if (n > 0 && time === this.times[n - 1]) {
            this.values[n - 1] = value;
            return this;
        }
        this.times.push(time);
        this.values.push(value);
        this.prune(time);
        return this;
    }

    pushIfChanged(time, value, epsilon = 1e-6) {
        var last = this.latest;
        if (last !== undefined && Math.abs(last - value) <= epsilon) {
            this.prune(time);
            return this;
        }
        return this.push(time, value);
    }


    prune(now) {
        var cutoff = now - this.maxAge;
        var cut = 0;
        while (cut + 1 < this.times.length && this.times[cut + 1] <= cutoff) { cut++; }
        var overflow = this.times.length - cut - this.maxSamples;
        if (overflow > 0) { cut += overflow; }
        if (cut > 0) {
            this.times.splice(0, cut);
            this.values.splice(0, cut);
        }
        return this;
    }

    clear() {
        this.times.length = 0;
        this.values.length = 0;
        return this;
    }

    toArray() {
        var out = [];
        for (var i = 0; i < this.times.length; i++) { out.push({ t: this.times[i], v: this.values[i] }); }
        return out;
    }

    average(now, window = this.maxAge, fallback = 0) {
        return this.weightedAverage(now, window, Weights.uniform, fallback);
    }

    weightedAverage(now, window = this.maxAge, weightFn = Weights.linear, fallback = 0) {
        var n = this.times.length;
        if (n === 0 || window <= 0) { return fallback; }
        var from = now - window;
        var acc = 0;
        var total = 0;
        for (var i = 0; i < n; i++) {
            var segStart = Math.max(this.times[i], from);
            var segEnd = (i + 1 < n) ? Math.min(this.times[i + 1], now) : now;
            var span = segEnd - segStart;
            if (span <= 0) { continue; }
            // Midpoint-rule integration of value * weight(age) over the held segment.
            var age = (now - (segStart + segEnd) * 0.5) / window;
            var w = weightFn(age) * span;
            acc += this.values[i] * w;
            total += w;
        }
        return total > 0 ? acc / total : this.values[n - 1];
    }
}

"""
