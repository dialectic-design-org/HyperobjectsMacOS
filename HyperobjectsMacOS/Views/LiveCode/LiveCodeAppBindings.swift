//
//  LiveCodeAppBindings.swift
//  HyperobjectsMacOS
//
//  Connects JSEngineManager and RenderConfigurations to the LiveCodeSession. Applied once on
//  the main window. Subscribes to individual engine publishers (deduplicated) instead of
//  observing the whole engine, which publishes at up to 120 Hz.
//

import SwiftUI
import Combine

struct LiveCodeAppBindings: ViewModifier {
    let session: LiveCodeSession
    let jsEngine: JSEngineManager
    @ObservedObject var renderConfigs: RenderConfigurations
    /// Current inputState for the readout panel (thread-safe cache owned by the App).
    let readoutSource: () -> [String: StateValue]

    @State private var readoutTimer: Timer?

    func body(content: Content) -> some View {
        content
            // Engine error -> overlay (only on change).
            .onReceive(errorPublisher) { error in
                session.reportEngineError(error.message, line: error.line)
            }
            // Console tail -> info panel (engine already throttles to <= 10 Hz).
            .onReceive(jsEngine.$consoleTail.removeDuplicates()) { tail in
                session.updateConsoleTail(tail)
            }
            .onChange(of: renderConfigs.showCodeConsole, initial: true) { _, on in
                jsEngine.consoleCaptureEnabled.set(on)
                if !on {
                    jsEngine.consoleTail = []
                    session.updateConsoleTail([])
                }
            }
            .onChange(of: renderConfigs.showCodeInputReadout, initial: true) { _, on in
                updateReadoutTimer(enabled: on)
            }
            .onChange(of: renderConfigs.showCodeOverlay) { _, _ in clearBurnedInStateIfUnused() }
            .onChange(of: renderConfigs.codeOverlayOutput) { _, _ in clearBurnedInStateIfUnused() }
            .onDisappear { updateReadoutTimer(enabled: false) }
    }

    private var errorPublisher: AnyPublisher<LiveCodeErrorUpdate, Never> {
        jsEngine.$errorMessage
            .combineLatest(jsEngine.$errorLine)
            .map { LiveCodeErrorUpdate(message: $0, line: $1) }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    /// 10 Hz main-thread sampling of the cached inputState, only while the toggle is on.
    private func updateReadoutTimer(enabled: Bool) {
        readoutTimer?.invalidate()
        readoutTimer = nil
        guard enabled else {
            session.updateInputReadout([])
            return
        }
        let renderConfigs = renderConfigs
        let session = session
        let source = readoutSource
        let timer = Timer(timeInterval: 0.1, repeats: true) { _ in
            let keys = LiveCodeReadout.keys(from: renderConfigs.codeInputReadoutKeys)
            session.updateInputReadout(LiveCodeReadout.rows(keys: keys, state: source()))
        }
        RunLoop.main.add(timer, forMode: .common)   // keep ticking while sliders are dragged
        timer.fire()
        readoutTimer = timer
    }

    private func clearBurnedInStateIfUnused() {
        if !(renderConfigs.showCodeOverlay && renderConfigs.codeOverlayOutput == .burnedIn) {
            session.overlayState.clear()
        }
    }
}

private struct LiveCodeErrorUpdate: Equatable {
    var message: String?
    var line: Int?
}
