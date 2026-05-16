import AppKit
import Foundation
import DorisIPC

/// Watches global `flagsChanged` events for one or more configured modifier
/// keys, and emits long-press start/end events on each. The triggering
/// keyCode is passed through the callbacks so the controller can route to
/// the right binding.
///
/// Each key has its own state machine (down/up + long-press timer) so two
/// users of the same modifier (left+right shift, both contributing to the
/// `.shift` flag) don't interfere with each other.
@MainActor
final class HotkeyEngine {
    var longPressThreshold: TimeInterval = 0.35

    /// Fires once the threshold elapses while a watched key is still held.
    /// Argument is the keyCode of the key.
    var onLongPressStart: ((UInt16) -> Void)?

    /// Fires when a long-press is released.
    var onLongPressEnd: ((UInt16) -> Void)?

    private struct State {
        var isHeld: Bool = false
        var longPressFired: Bool = false
        var pressTask: Task<Void, Never>? = nil
    }

    private var states: [UInt16: State] = [:]
    private var globalMonitor: Any?
    private var localMonitor: Any?

    init(initialKeyCodes: Set<UInt16> = []) {
        setWatchedKeyCodes(initialKeyCodes)
    }

    /// Replace the set of keyCodes we listen for. State for keys removed
    /// from the set is dropped (any pending long-press is cancelled).
    func setWatchedKeyCodes(_ codes: Set<UInt16>) {
        for kc in states.keys where !codes.contains(kc) {
            states[kc]?.pressTask?.cancel()
            states.removeValue(forKey: kc)
        }
        for kc in codes where states[kc] == nil {
            states[kc] = State()
        }
        DorisLog.voice.info("hotkey watching keyCodes: \(Array(codes).sorted(), privacy: .public)")
    }

    func start() {
        guard globalMonitor == nil else { return }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in self?.handleFlagsChanged(event) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in self?.handleFlagsChanged(event) }
            return event
        }
        DorisLog.voice.info("HotkeyEngine started")
    }

    func stop() {
        if let g = globalMonitor { NSEvent.removeMonitor(g); globalMonitor = nil }
        if let l = localMonitor { NSEvent.removeMonitor(l); localMonitor = nil }
        for kc in states.keys {
            states[kc]?.pressTask?.cancel()
            if states[kc]?.longPressFired == true {
                onLongPressEnd?(kc)
            }
            states[kc] = State()
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let kc = event.keyCode
        // Diagnostic: log every modifier event so we can see what keyCode
        // each physical key actually reports on the user's hardware
        // (some external/Bluetooth keyboards collapse left+right modifiers
        // onto the same keyCode). The `modifierFlags` raw value carries
        // device-specific bits that disambiguate sides even when keyCode
        // doesn't.
        DorisLog.voice.notice("flagsChanged keyCode=\(kc, privacy: .public) flags=0x\(String(event.modifierFlags.rawValue, radix: 16), privacy: .public) watched=\(self.states.keys.contains(kc) ? "yes" : "no", privacy: .public)")
        guard var state = states[kc] else { return }

        let nowDown = !state.isHeld
        state.isHeld = nowDown
        states[kc] = state

        if nowDown {
            state.longPressFired = false
            states[kc] = state
            let threshold = longPressThreshold
            state.pressTask?.cancel()
            let task = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(threshold * 1_000_000_000))
                guard let self, !Task.isCancelled,
                      var s = self.states[kc], s.isHeld else { return }
                s.longPressFired = true
                self.states[kc] = s
                self.onLongPressStart?(kc)
            }
            state.pressTask = task
            states[kc] = state
        } else {
            state.pressTask?.cancel()
            state.pressTask = nil
            let fired = state.longPressFired
            state.longPressFired = false
            states[kc] = state
            if fired {
                onLongPressEnd?(kc)
            }
        }
    }
}
