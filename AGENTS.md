# Repository Guidelines

## Project Structure & Module Organization

HyperobjectsMacOS is a realtime generative-geometry app built with SwiftUI, Metal, audio/MIDI inputs, JavaScript live control, and Syphon output. Scene factories live in `HyperobjectsMacOS/Data/Scenes/` and are registered in `Data/allScenes.swift`. Geometry generation lives in `Data/GeometryGenerators/`, usually as `CachedGeometryGenerator` subclasses returning `Line`, curve, or shape models from `Models/Structs/Geometries/`. Runtime state, inputs, envelopes, render configuration, and caching live under `Models/` and `Utils/`. SwiftUI controls are in `Views/`, while GPU rendering is concentrated in `Views/RenderView/`, `Shaders.metal`, and shared Swift/Metal structs in `definitions.h`. Tests are split between `HyperobjectsMacOSTests/` and `HyperobjectsMacOSUITests/`. Treat `Syphon.framework/` as vendored.

## Scene & Rendering Architecture

Scenes are assembled as `GeometriesSceneBase(name:inputs:geometryGenerators:)`. Each `SceneInput` name is a contract: generators such as `CubeGenerator` retrieve values by exact string, including history-aware delay inputs like `LineWidth delay` and grouped controls like `Cubes` or `Rotation`. When adding a scene, create `GeometrySceneName.swift`, create a matching generator if needed, and add the scene to `allScenes`.

Geometry generation runs off the main thread from `SceneInputSnapshot`; avoid reading mutable UI state directly inside generators unless using scene APIs designed for history or audio state. Use `inputDependencies` narrowly when possible; use `CachedGeometryGenerator.allSceneInputsSentinel` only when every input can affect output.

The Metal path renderer transforms linear, quadratic, and cubic segments into screen-space bins before compositing. Keep `definitions.h`, Swift buffer structs, and `Shaders.metal` layouts synchronized. Changes to `BIN_SIZE`, segment structs, band-field uniforms, chromatic aberration, or line capacity can affect memory use and GPU correctness.

## Build, Test, and Development Commands

Open the project in Xcode with:

```sh
open HyperobjectsMacOS.xcodeproj
```

Build from the command line with a full Xcode toolchain selected:

```sh
xcodebuild -project HyperobjectsMacOS.xcodeproj -scheme HyperobjectsMacOS build
```

Run all tests with:

```sh
xcodebuild -project HyperobjectsMacOS.xcodeproj -scheme HyperobjectsMacOS test
```

If `xcodebuild` reports that Command Line Tools are selected, switch to Xcode, for example `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.

## Coding Style & Naming Conventions

Use four-space Swift indentation, `PascalCase` for types, and `camelCase` for values/functions. Keep scene input names human-readable but stable; renaming an input can break generator lookups, JavaScript state, MIDI mappings, and tests. Prefer `floatFromInputs`, `intFromInputs`, `colorFromInputs`, `SceneInput.getHistoryValue`, and typed structs over force-casting raw dictionary values. In shader code, keep helper functions small and mark hot helpers `[[clang::always_inline]]` when matching existing render style.

## Testing Guidelines

Unit tests use Swift Testing (`@Test`, `#expect`) in `HyperobjectsMacOSTests/`; UI tests use XCTest. Add focused tests for `StateValue` parsing, MIDI snapshots, band-field parsing, envelope/history behavior, render configuration overrides, and geometry helpers. Name tests by behavior, for example `midiSnapshotDefaultsExposeKnobsAndPads`. Run the full scheme tests before a PR.

## Commit & Pull Request Guidelines

Recent commits use short descriptive lowercase summaries, such as `render loop refactor...` or `added initial basic MIDI controls...`. Keep commits scoped. PRs should describe user-visible visual changes, list validation, and call out changes to shaders, shared Metal structs, entitlements, Syphon/video output, audio/MIDI behavior, or JavaScript live-control contracts. Include screenshots or short recordings for visual changes.
