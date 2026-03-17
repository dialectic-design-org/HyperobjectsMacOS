# Performance Bottleneck Analysis

## System Overview

This app has three concurrent loops that interact through shared state:

```
                    ┌─────────────────────┐
                    │   AVAudioEngine     │
                    │   Audio Callback    │
                    │  (~86 Hz, BG thread)│
                    └────────┬────────────┘
                             │ DispatchQueue.main.async
                             ▼
┌──────────────────────────────────────────────────────────┐
│                    MAIN THREAD                           │
│                                                          │
│  ┌──────────────────┐    ┌──────────────────────────┐   │
│  │ AudioInputMonitor│───▶│ RealtimePanel.onChange    │   │
│  │ ~10 @Published   │    │  applyAudioTick()        │   │
│  │ updates per tick │    │  (9+ @Published updates)  │   │
│  └──────────────────┘    └──────────┬───────────────┘   │
│                                     │                    │
│  ┌──────────────────┐    ┌──────────▼───────────────┐   │
│  │ 120Hz Timer      │    │ SceneInputsView.onChange  │   │
│  │ (JS execution)   │───▶│  updateFloatInputsWithAudio│  │
│  └──────────────────┘    │  setWrappedGeometries()   │   │
│                          │  (generateAllGeometries)  │   │
│                          └──────────┬───────────────┘   │
│                                     │                    │
│  ┌──────────────────────────────────▼───────────────┐   │
│  │ SwiftUI View Tree Re-evaluation                  │   │
│  │  - RenderView.body (calls generateAllGeometries  │   │
│  │    AGAIN just for overlay text)                   │   │
│  │  - AudioTimelineChartView (3x Path over 1800+    │   │
│  │    data points)                                   │   │
│  │  - InputsGrid (Equatable always false)           │   │
│  │  - 9+ windows all observe currentScene           │   │
│  └──────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────┘
                             │
                             │ scene.cachedGeometries (unsynchronized)
                             ▼
┌──────────────────────────────────────────────────────────┐
│              RENDER THREAD (dedicated)                    │
│  ┌──────────────────────────────────────────────────┐   │
│  │ CAMetalDisplayLink (240 FPS)                     │   │
│  │  - reads scene.cachedGeometries                  │   │
│  │  - memset full buffers each frame                │   │
│  │  - populates GPU buffers from geometries         │   │
│  │  - dispatches compute + render passes            │   │
│  │  - commandBuffer.waitUntilCompleted()            │   │
│  └──────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────┘
```

---

## The Audio Tick Update Chain (per tick, ~60-86 Hz)

Each audio callback triggers the following cascade on the main thread:

### Step 1: AudioInputMonitor publishes (~10 @Published changes)
**File:** `AudioInputMonitor.swift:104-108`

```swift
DispatchQueue.main.async {
    self.volume = normalizedVolume          // @Published
    self.lowpassVolume = filtered           // @Published
    self.updateSmoothedVolume(...)          // updates:
    // - recentVolumes                       @Published
    // - smoothedVolume                      @Published
    // - recentVolumesPerSmoothing (5 dicts) @Published (dict mutation)
    // - smoothedVolumes (5 entries)         @Published (dict mutation)
}
```

### Step 2: RealtimePanel.onChange fires (triggered by smoothedVolume)
**File:** `RealtimePanel.swift:66-75`

Calls `applyAudioTick()` which updates 9+ more @Published properties on `GeometriesSceneBase`:

```swift
audioSignal = m.smoothed                    // @Published
audioSignalsSmoothed = m.smoothedPerStep    // @Published (dict)
audioSignalRaw = m.raw                      // @Published
audioSignalProcessed = processor.process()  // @Published
audioSignalLowpassRaw = ...                 // @Published
audioSignalLowpassSmoothed = ...            // @Published
audioSignalLowpassProcessed = ...           // @Published
audioSignalsSmoothedProcessed[...] = ...    // @Published (dict, mutated per-key)
frameStamp &+= 1                           // @Published
```

### Step 3: SceneInputsView.onChange fires (ALSO triggered by smoothedVolume)
**File:** `SceneInputsView.swift:79-125`

- Iterates ALL inputs for `statefulFloat` type updates
- Calls `updateFloatInputsWithAudio()` which marks ALL float/lines inputs as changed and appends to `historyData` (@Published, up to 4000 items)
- Calls `setWrappedGeometries()` which calls `generateAllGeometries()` and writes to `cachedGeometries` (@Published)

### Step 4: SwiftUI view tree re-evaluation (cascading across 9+ windows)

Every view that observes `GeometriesSceneBase` via `@EnvironmentObject` or `@ObservedObject` re-evaluates its `body`.

**Total @Published changes per audio tick: ~20+**

---

## Bottleneck 1: Duplicate `generateAllGeometries()` Calls

**Severity: HIGH**
**Impact: CPU-bound geometry generation runs twice per audio tick**

### The problem

`generateAllGeometries()` is called in two places per audio tick:

1. **SceneInputsView.onChange** calls `setWrappedGeometries()` which calls `generateAllGeometries()`
   (`SceneInputsView.swift:121` -> `GeometriesSceneBase.swift:297-298`)

2. **RenderView.body** calls `generateAllGeometries()` directly in the view body for the overlay text:
   (`RenderView.swift:19`)
   ```swift
   var body: some View {
       let geometries = currentScene.generateAllGeometries()  // <-- REDUNDANT
       // ...
       Text("geometries count: \(geometries.count)")  // only used for this
   ```

The second call is triggered because `cachedGeometries` (written in step 1) is @Published, causing RenderView's body to re-evaluate. But instead of reading `cachedGeometries.count`, it re-generates all geometries from scratch.

### Fix

Replace the redundant call in `RenderView.swift:19`:

```swift
// Before:
let geometries = currentScene.generateAllGeometries()

// After:
let geometryCount = currentScene.cachedGeometries.count
```

And update the reference on line 45:
```swift
Text("geometries count: \(geometryCount)")
```

---

## Bottleneck 2: Dual onChange Handlers for the Same Signal

**Severity: HIGH**
**Impact: Audio processing work split across two views, causing redundant iterations and ordering issues**

### The problem

Both `RealtimePanel` and `SceneInputsView` have `.onChange(of: audioMonitor.smoothedVolume)`:

- `RealtimePanel.swift:66` — calls `applyAudioTick()` (updates audio signal properties)
- `SceneInputsView.swift:79` — updates stateful inputs, calls `updateFloatInputsWithAudio()` and `setWrappedGeometries()`

SwiftUI does not guarantee execution order of `onChange` handlers across sibling/nested views. This means `SceneInputsView.onChange` might execute before `RealtimePanel.onChange`, causing `setWrappedGeometries()` to run with stale audio signal values.

Additionally, the stateful float update logic in `SceneInputsView.swift:86-118` uses `audioSignalProcessedHistory` (which is never actually populated in the current code — it's a legacy property) rather than the active `historyData` array.

### Fix

Consolidate all audio-tick processing into a single location. Move it all into `RealtimePanel.onChange` (or better: into `GeometriesSceneBase.applyAudioTick` itself) so the full chain runs in deterministic order:

1. Update audio signal properties
2. Update stateful float inputs
3. Update float inputs with audio
4. Regenerate geometries

This eliminates the ordering ambiguity and the redundant loop through inputs.

---

## Bottleneck 3: @Published Property Avalanche on GeometriesSceneBase

**Severity: HIGH**
**Impact: Every @Published mutation fires objectWillChange, triggering re-evaluation in ALL observing views across ALL windows**

### The problem

`GeometriesSceneBase` has 18+ @Published properties. On each audio tick, `applyAudioTick()` mutates 9+ of them individually. Each mutation fires `objectWillChange.send()`, which SwiftUI can coalesce within the same RunLoop cycle — **but only if all mutations happen synchronously in the same call stack**.

The problem is that mutations happen across multiple call stacks:
1. `applyAudioTick()` — 9+ mutations
2. `SceneInputsView.onChange` — mutates `inputs[i].value` (array element), `changedInputs`, `historyData`, `cachedGeometries`

Each of these can trigger a separate SwiftUI update pass.

Additionally, **9+ windows** inject `currentScene` as `@EnvironmentObject`:

```swift
// HyperobjectsMacOSApp.swift — every window observes the same object:
Window("secondary render") { ... .environmentObject(sceneManager.currentScene) }
Window("scene inputs")     { ... .environmentObject(sceneManager.currentScene) }
Window("render configs")   { ... .environmentObject(sceneManager.currentScene) }
Window("geometries list")  { ... .environmentObject(sceneManager.currentScene) }
Window("viewport front")   { ... .environmentObject(sceneManager.currentScene) }
Window("viewport side")    { ... .environmentObject(sceneManager.currentScene) }
Window("viewport top")     { ... .environmentObject(sceneManager.currentScene) }
```

Every single `objectWillChange` notification forces body re-evaluation in ALL these windows.

### Fix

**A. Batch audio properties into a single struct:**

```swift
// Instead of 9+ individual @Published properties:
struct AudioState {
    var signal: Float = 0
    var signalRaw: Float = 0
    var signalProcessed: Double = 0
    var signalsSmoothed: [Int: Float] = [:]
    var signalsSmoothedProcessed: [Int: Double] = [:]
    var lowpassRaw: Double = 0
    var lowpassSmoothed: Double = 0
    var lowpassProcessed: Double = 0
}

// Single @Published, single objectWillChange notification:
@Published var audioState = AudioState()
```

**B. Don't use @Published for render-only data:**

`cachedGeometries` is only read by the Metal renderer on its own thread. It doesn't need to be @Published. Use an `Atomic` wrapper or a lock-protected property instead:

```swift
// Instead of @Published var cachedGeometries:
private let _cachedGeometries = NSLock()
private var _cachedGeometriesValue: [GeometryWrapped] = []
var cachedGeometries: [GeometryWrapped] {
    get { _cachedGeometries.lock(); defer { _cachedGeometries.unlock() }; return _cachedGeometriesValue }
    set { _cachedGeometries.lock(); _cachedGeometriesValue = newValue; _cachedGeometries.unlock() }
}
```

This prevents the entire SwiftUI tree from re-evaluating just because geometry data changed.

**C. Split the monolithic observable into domain-specific objects:**

- `AudioState` (ObservableObject) — only injected into audio-related views
- `SceneGeometry` — non-observable, accessed by renderer directly
- `SceneInputState` (ObservableObject) — only injected into input views

---

## Bottleneck 4: AudioTimelineChartView Drawing Thousands of Path Segments

**Severity: HIGH (when audio controls are visible)**
**Impact: SwiftUI re-renders 3 complex Path views with 1800+ data points each, ~60 times per second**

### The problem

`AudioTimelineChartView` receives `historyData: [AudioDataPoint]` as a `let` property (`AudioTimelineChartView.swift:12`). Since `historyData` is @Published on `GeometriesSceneBase` and appended to on every audio tick, the view redraws on every tick.

Each redraw:
1. Filters the array: `historyData.filter { $0.timestamp >= startTime }` — O(n) where n can be ~1800+
2. Draws **3 separate Path objects**, each iterating all filtered points (raw, smoothed, processed)
3. Uses SwiftUI `Path` which is not hardware-accelerated for arbitrary paths

At 60 Hz with a 10-second window and ~60 samples/sec, this means ~600 points × 3 paths × 60 redraws/sec = **~108,000 path point calculations per second** in SwiftUI.

### Fix

**A. Use a Canvas instead of Path for high-frequency drawing:**

```swift
Canvas { context, size in
    let drawingRect = CGRect(...)
    let filteredData = historyData.filter { $0.timestamp >= startTime }

    // Single immediate-mode pass, much faster than SwiftUI Path diffing
    var rawPath = Path()
    var smoothedPath = Path()
    var processedPath = Path()

    for (i, dp) in filteredData.enumerated() {
        let x = timeToX(dp.timestamp, in: drawingRect)
        if i == 0 {
            rawPath.move(to: CGPoint(x: x, y: volumeToY(dp.rawVolume, in: drawingRect)))
            smoothedPath.move(to: CGPoint(x: x, y: volumeToY(dp.smoothedVolume, in: drawingRect)))
            processedPath.move(to: CGPoint(x: x, y: volumeToY(dp.processedVolume, in: drawingRect)))
        } else {
            rawPath.addLine(to: CGPoint(x: x, y: volumeToY(dp.rawVolume, in: drawingRect)))
            smoothedPath.addLine(to: CGPoint(x: x, y: volumeToY(dp.smoothedVolume, in: drawingRect)))
            processedPath.addLine(to: CGPoint(x: x, y: volumeToY(dp.processedVolume, in: drawingRect)))
        }
    }

    context.stroke(rawPath, with: .color(.red.opacity(0.8)), lineWidth: 1.5)
    context.stroke(smoothedPath, with: .color(.orange.opacity(0.8)), lineWidth: 1.5)
    context.stroke(processedPath, with: .color(.green.opacity(0.8)), lineWidth: 1.5)
}
```

Canvas is immediate-mode and doesn't create a SwiftUI view diff.

**B. Downsample for display:**

Only display every Nth point when the array is large. At 600px width, you only need ~600 points max:

```swift
let stride = max(1, filteredData.count / Int(drawingRect.width))
for i in stride(from: 0, to: filteredData.count, by: stride) { ... }
```

**C. Throttle the chart update rate:**

The chart doesn't need to update at 60 Hz. Throttle to ~10-15 Hz using a timer or debounce mechanism:

```swift
@State private var displayData: [AudioDataPoint] = []
// Update displayData on a 15Hz timer instead of every audio tick
```

---

## Bottleneck 5: InputsGrid and InputGroupColumn Always Redraw

**Severity: MEDIUM-HIGH**
**Impact: All input controls (sliders, color pickers, etc.) redraw on every audio tick regardless of whether inputs changed**

### The problem

Both `InputsGrid` and `InputGroupColumn` implement `Equatable` but always return `false`:

```swift
// InputsGrid.swift:43-44
struct InputsGrid: View, Equatable {
    static func == (l: Self, r: Self) -> Bool {
        return false  // <-- Defeats the purpose of .equatable()
    }
}
```

```swift
// InputGroupColumn.swift (same pattern)
struct InputGroupColumn: View, Equatable {
    static func == (l: Self, r: Self) -> Bool {
        return false
    }
}
```

`SceneInputsView` applies `.equatable()` to `InputsGrid` (`SceneInputsView.swift:74`), expecting it to skip redraws when inputs haven't changed. But because `==` always returns `false`, every parent redraw causes a full redraw of all input controls.

Since `SceneInputsView` observes both `currentScene` (which changes every audio tick) and `audioMonitor`, the InputsGrid redraws ~60 Hz even when no inputs have actually changed.

### Fix

Implement meaningful equality checks:

```swift
struct InputsGrid: View, Equatable {
    static func == (l: Self, r: Self) -> Bool {
        // Compare input identity and group state
        l.inputs.map(\.id) == r.inputs.map(\.id) &&
        l.groups.wrappedValue.map(\.id) == r.groups.wrappedValue.map(\.id)
    }
}
```

Or better: stop passing `currentScene.inputs` directly (which is a reference-type array that changes identity on every mutation) and instead pass a stable snapshot or signature.

---

## Bottleneck 6: Data Race on cachedGeometries

**Severity: HIGH (correctness + potential crash)**
**Impact: Main thread writes while render thread reads, causing potential crashes or rendering artifacts**

### The problem

`cachedGeometries` is a `@Published var` on `GeometriesSceneBase` (main-thread class). It's written by `setWrappedGeometries()` on the main thread:

```swift
// GeometriesSceneBase.swift:298 (main thread)
self.cachedGeometries = self.generateAllGeometries().map { GeometryWrapped(geometry: $0) }
```

But it's read by the Metal renderer on a **dedicated render thread**:

```swift
// MetalRenderer.swift:397 (render thread)
let totalLineCount = scene.cachedGeometries.count
// ...
// MetalRenderer.swift:442 (render thread)
for gWrapped in scene.cachedGeometries { ... }
```

Swift arrays are value types with copy-on-write, but the `@Published` property wrapper doesn't provide thread-safe access. If the main thread replaces the array while the render thread is iterating it, this can cause:
- Inconsistent count vs actual elements
- Use-after-free of the backing buffer
- Rendering artifacts (mixing old and new geometry data)

### Fix

Use a thread-safe handoff mechanism. The simplest approach:

```swift
private let geometryLock = NSLock()
private var _cachedGeometries: [GeometryWrapped] = []

var cachedGeometries: [GeometryWrapped] {
    get { geometryLock.lock(); defer { geometryLock.unlock() }; return _cachedGeometries }
    set { geometryLock.lock(); _cachedGeometries = newValue; geometryLock.unlock() }
}
```

Or better: use a double-buffer pattern where the main thread writes to a staging buffer and the render thread atomically swaps to the latest version at the start of each frame.

---

## Bottleneck 7: waitUntilCompleted() Blocks the Render Thread

**Severity: MEDIUM**
**Impact: Render thread sits idle waiting for GPU, reducing effective throughput and increasing latency**

### The problem

```swift
// MetalRenderer.swift:884-885
commandBuffer.present(drawable)
commandBuffer.commit()
commandBuffer.waitUntilCompleted()  // <-- BLOCKS until GPU finishes
```

This is a synchronous stall point. The render thread cannot begin preparing the next frame's CPU work (buffer population, geometry iteration) until the GPU has completely finished the current frame. At 240 FPS target, each frame has only ~4.17ms. If GPU work takes 3ms, the CPU sits idle for those 3ms.

### Fix

Use a semaphore-based triple-buffering approach:

```swift
private let maxFramesInFlight = 3
private let frameSemaphore = DispatchSemaphore(value: 3)

func render(drawable: CAMetalDrawable) {
    frameSemaphore.wait()  // Block only if 3 frames already in flight

    // ... prepare buffers, encode commands ...

    commandBuffer.addCompletedHandler { [weak self] _ in
        self?.frameSemaphore.signal()  // Release slot when GPU finishes
    }

    commandBuffer.present(drawable)
    commandBuffer.commit()
    // Do NOT wait — continue to next frame's CPU prep
}
```

This allows CPU and GPU to overlap work, significantly improving throughput.

---

## Bottleneck 8: Full Buffer memset Every Frame

**Severity: LOW-MEDIUM**
**Impact: Unnecessary memory bandwidth usage, especially with large buffer allocations**

### The problem

```swift
// MetalRenderer.swift:424-431
memset(linesBuffer.contents(), 0, byteCount)           // Full wipe
memset(quadraticCurvesBuffer.contents(), 0, byteCountQuadratic) // Full wipe
memset(cubicCurvesBuffer.contents(), 0, byteCountCubic)        // Full wipe
```

Buffers are sized for `lineCount` (minimum 10,000, grows geometrically). If the scene has 500 lines, you're still zeroing memory for 10,000+ entries. With `LinearSeg3D` likely being 100+ bytes, that's ~1MB+ of unnecessary memory writes per frame.

### Fix

Only zero the portion that will be used, or better yet, pass the actual counts to the GPU shaders and skip the memset entirely:

```swift
// Instead of full memset, pass counts to compute shaders
var linearCount: UInt32 = UInt32(linearLinesIndex)
var quadraticCount: UInt32 = UInt32(quadraticLinesIndex)
var cubicCount: UInt32 = UInt32(cubicLinesIndex)
```

The shaders only process `count` elements anyway, so uninitialized memory beyond the count is never read.

---

## Bottleneck 9: updateFloatInputsWithAudio Marks ALL Inputs as Changed

**Severity: MEDIUM**
**Impact: Defeats the caching in CachedGeometryGenerator, forcing full regeneration every tick**

### The problem

```swift
// GeometriesSceneBase.swift:191-205
for (index, input) in inputs.enumerated() where input.type == .float {
    if true {  // <-- Always true! No actual change detection
        changedInputNames.append(input.name)
    }
}

for (index, input) in inputs.enumerated() where input.type == .lines {
    if true {  // <-- Always true!
        changedInputNames.append(input.name)
    }
}
```

Every float and lines input is unconditionally marked as changed. In `generateAllGeometries()`, the `needsRecalculation(changedInputs:)` check on geometry generators will always return true, defeating the caching system entirely.

### Fix

Implement actual change detection:

```swift
for (index, input) in inputs.enumerated() where input.type == .float {
    let historicAudioSignal = extractHistoricAudioValue(for: input)
    let newValue = input.combinedValueAsFloat(audioSignal: Float(historicAudioSignal))
    let currentValue = (input.value as? Double).map { Float($0) } ?? 0
    if abs(newValue - currentValue) > 1e-6 {
        changedInputNames.append(input.name)
    }
}
```

Also clear `changedInputs` after `generateAllGeometries()` runs (it's currently accumulated and never cleared).

---

## Bottleneck 10: 120Hz Timer Competing with Audio Loop

**Severity: MEDIUM (when runScriptOnFrameChange is enabled)**
**Impact: Two independent loops modifying scene state at different rates**

### The problem

`HyperobjectsMacOSApp.swift:65-86` runs a `Timer` at 120 Hz that:
1. Executes JavaScript via `jsEngine.executeScript()`
2. Applies output to scene via `applyScriptOutput()` (which does linear searches through inputs for each output key)

This runs on the main thread and competes with the audio-driven updates for CPU time. When both are active:
- Audio tick (~86 Hz): `applyAudioTick()` + `updateFloatInputsWithAudio()` + `setWrappedGeometries()`
- Timer tick (120 Hz): `executeScript()` + `applyScriptOutput()`

Both modify `inputs[].value` and trigger `objectWillChange` cascades.

### Fix

- Consider running JS execution off the main thread
- Use a dictionary lookup for `applyScriptOutput` instead of `inputs.first(where:)` (use the existing `inputMap`)
- If the timer is only needed for animation purposes, consider tying it to the audio tick or the display link callback instead

---

## Bottleneck 11: MetalView.updateNSView Called on Every State Change

**Severity: LOW-MEDIUM**
**Impact: Unnecessary scene reference updates**

### The problem

`MetalView` is an `NSViewRepresentable` that observes `currentScene` and `renderConfigs` via `@EnvironmentObject`:

```swift
// MetalView.swift:14-15
@EnvironmentObject var currentScene: GeometriesSceneBase
@EnvironmentObject var renderConfigs: RenderConfigurations
```

Any change to either of these objects causes SwiftUI to call `updateNSView()`:

```swift
func updateNSView(_ view: MTKView, context: Context) {
    context.coordinator.renderer?.updateCurrentScene(currentScene)
}
```

This is called on every audio tick because `currentScene` fires `objectWillChange` ~20 times per tick. The `updateCurrentScene` call is likely just a reference reassignment, but the SwiftUI diffing and `updateNSView` dispatch itself has overhead.

### Fix

Remove `@EnvironmentObject var currentScene` from `MetalView`. The renderer already holds a reference to the scene (passed in `makeNSView`). The scene doesn't change during runtime — only its properties do, which the renderer reads directly.

If scene switching is needed, use a dedicated mechanism rather than `@EnvironmentObject` observation.

---

## Bottleneck 12: historyData Growing as @Published Array

**Severity: MEDIUM**
**Impact: Every append triggers objectWillChange, and array copy-on-write can be expensive at 4000 items**

### The problem

`historyData` is `@Published var historyData: [AudioDataPoint] = []` with up to 4000 items. Each audio tick:
1. Appends one item (`GeometriesSceneBase.swift:228`)
2. Potentially removes old items (`GeometriesSceneBase.swift:244-245`)

Both operations trigger `objectWillChange.send()`. The `removeFirst()` on a large array is O(n) because Swift arrays must shift elements.

The only views that read `historyData` are `AudioTimelineChartView` and `AudioTimelineView`, but because it's @Published on `GeometriesSceneBase`, ALL views observing the scene are notified.

### Fix

**A. Move historyData to a separate ObservableObject:**

```swift
class AudioHistory: ObservableObject {
    @Published var data: [AudioDataPoint] = []
    // Only AudioTimelineView observes this
}
```

**B. Use a circular buffer instead of Array:**

A ring buffer avoids the O(n) `removeFirst()` and reduces copy-on-write overhead:

```swift
struct CircularBuffer<T> {
    private var storage: [T?]
    private var head = 0
    private var count = 0
    let capacity: Int

    mutating func append(_ item: T) {
        storage[head] = item
        head = (head + 1) % capacity
        count = min(count + 1, capacity)
    }
}
```

---

## Summary: Priority-Ordered Fix List

| Priority | Bottleneck | Effort | Impact |
|----------|-----------|--------|--------|
| 1 | Duplicate `generateAllGeometries()` in RenderView.body | 5 min | High - eliminates redundant heavy computation |
| 2 | Remove `cachedGeometries` from @Published | 15 min | High - prevents massive SwiftUI cascade |
| 3 | Consolidate dual onChange handlers | 30 min | High - fixes ordering bug + removes redundancy |
| 4 | Batch audio @Published into single struct | 30 min | High - reduces objectWillChange notifications by ~8x |
| 5 | Canvas + downsampling for AudioTimelineChartView | 30 min | High - eliminates heaviest SwiftUI redraw |
| 6 | Fix data race on cachedGeometries | 15 min | High - correctness fix, prevents crashes |
| 7 | Fix InputsGrid/InputGroupColumn Equatable | 15 min | Medium - prevents unnecessary input control redraws |
| 8 | Replace waitUntilCompleted with semaphore | 20 min | Medium - enables CPU/GPU overlap |
| 9 | Fix `if true` change detection bypass | 10 min | Medium - enables geometry caching |
| 10 | Move historyData to separate observable | 20 min | Medium - reduces notification blast radius |
| 11 | Remove @EnvironmentObject from MetalView | 10 min | Low-Medium - reduces updateNSView calls |
| 12 | Only memset used buffer portion | 5 min | Low-Medium - reduces memory bandwidth |

### Expected Impact

Fixing items 1-5 alone should dramatically reduce main thread work per audio tick:
- **Before:** ~20+ @Published notifications → 9+ window re-evaluations → duplicate geometry generation → 1800+ point Path rendering
- **After:** ~2-3 @Published notifications → only audio-related views update → single geometry generation → throttled Canvas chart

This should eliminate the SwiftUI interference with the Metal render loop that you're experiencing when `showAudioControls` is enabled.
