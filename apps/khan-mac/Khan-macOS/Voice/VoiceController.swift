import AppKit
import Foundation
import Combine
import KhanIPC

/// Top-level coordinator. Listens to all configured trigger keys, and on a
/// long-press → release cycle:
///
/// 1. Looks up the matching `VoiceBinding` by keyCode.
/// 2. Starts a speech-recognizer in that binding's language.
/// 3. On release, hands the transcript to `AppRouter` aimed at the
///    binding's provider, with the binding's auto-submit preference.
///
/// Only one recording is active at a time. If a second trigger key starts
/// while the first is still held, it's ignored until the active one ends.
@MainActor
final class VoiceController {
    private let hotkey = HotkeyEngine()
    private let floater = VoiceFloater()
    private let appRouter = AppRouter()

    private var bindingsByKey: [UInt16: VoiceBinding] = [:]
    private var recognizer: SpeechRecognizer?
    private var activeBinding: VoiceBinding?
    private var settingsCancellables = Set<AnyCancellable>()

    init() {
        wireHotkey()
        observeSettings()
        applyBindings(VoiceSettings.shared.bindings)
    }

    func start() {
        guard VoiceSettings.shared.enabled else { return }
        hotkey.start()
    }

    func stop() {
        hotkey.stop()
    }

    // MARK: - Wire-up

    private func wireHotkey() {
        hotkey.onLongPressStart = { [weak self] kc in
            Task { @MainActor in self?.beginRecording(forKeyCode: kc) }
        }
        hotkey.onLongPressEnd = { [weak self] kc in
            Task { @MainActor in await self?.endRecording(forKeyCode: kc) }
        }
    }

    private func observeSettings() {
        VoiceSettings.shared.$bindings
            .sink { [weak self] list in
                self?.applyBindings(list)
            }
            .store(in: &settingsCancellables)

        VoiceSettings.shared.$enabled
            .sink { [weak self] enabled in
                if enabled { self?.hotkey.start() } else { self?.hotkey.stop() }
            }
            .store(in: &settingsCancellables)
    }

    private func applyBindings(_ list: [VoiceBinding]) {
        // Last write wins on collisions — UI prevents them in practice.
        var map: [UInt16: VoiceBinding] = [:]
        for b in list { map[b.triggerKey.keyCode] = b }
        bindingsByKey = map
        hotkey.setWatchedKeyCodes(Set(map.keys))
    }

    // MARK: - Recording lifecycle

    private func beginRecording(forKeyCode kc: UInt16) {
        KhanLog.voice.info("hotkey long-press fired keyCode=\(kc, privacy: .public)")
        guard let binding = bindingsByKey[kc] else {
            KhanLog.voice.notice("no binding for keyCode \(kc, privacy: .public)")
            return
        }
        guard activeBinding == nil else {
            KhanLog.voice.notice("another binding already active — ignoring")
            return
        }

        let auth = SpeechRecognizer.currentAuthorization()
        if auth != .granted {
            Task { _ = await SpeechRecognizer.requestAuthorization() }
            showError(message: errorMessage(for: auth), autoDismiss: 2.5)
            return
        }

        let r = SpeechRecognizer(locale: binding.language.locale)
        r.onPartial = { [weak self] partial in
            self?.floater.update(.listening(partial: partial))
        }
        do {
            try r.start()
            recognizer = r
            activeBinding = binding
            floater.show(initial: .listening(partial: ""))
            KhanLog.voice.info("recorder started for binding=\(binding.id.uuidString, privacy: .public) lang=\(binding.language.rawValue, privacy: .public) provider=\(binding.provider.rawValue, privacy: .public)")
        } catch {
            recognizer = nil
            KhanLog.voice.error("recorder start failed: \(error.localizedDescription, privacy: .public)")
            showError(message: error.localizedDescription, autoDismiss: 2.5)
        }
    }

    private func endRecording(forKeyCode kc: UInt16) async {
        guard let binding = activeBinding, binding.triggerKey.keyCode == kc, let r = recognizer else {
            return
        }
        activeBinding = nil
        recognizer = nil

        let result = await r.stop()
        KhanLog.voice.info("transcript len=\(result.text.count, privacy: .public): \(result.text, privacy: .public)")
        guard !result.text.isEmpty else {
            floater.hide(after: 0.15)
            return
        }

        floater.update(.sending(text: result.text, target: binding.provider.displayName))
        do {
            try await appRouter.send(text: result.text, to: binding.provider, autoSubmit: binding.autoSubmit)
            KhanLog.voice.info("router send ok")
            floater.hide(after: 0.6)
        } catch {
            KhanLog.voice.error("router send failed: \(error.localizedDescription, privacy: .public)")
            showError(message: error.localizedDescription, autoDismiss: 3.0)
        }
    }

    private func showError(message: String, autoDismiss: TimeInterval) {
        floater.show(initial: .error(message: message))
        floater.hide(after: autoDismiss)
    }

    private func errorMessage(for auth: SpeechRecognizer.Authorization) -> String {
        switch auth {
        case .granted, .notYetDetermined:
            return L("Granting permission… try again.", "正在请求权限,请重试。")
        case .deniedSpeech:
            return L(
                "Speech recognition denied. Enable in System Settings › Privacy › Speech Recognition.",
                "语音识别已拒绝。请在系统设置 › 隐私与安全性 › 语音识别中开启。"
            )
        case .deniedMicrophone:
            return L(
                "Microphone denied. Enable in System Settings › Privacy › Microphone.",
                "麦克风已拒绝。请在系统设置 › 隐私与安全性 › 麦克风中开启。"
            )
        case .restricted:
            return L("Speech recognition is restricted on this Mac.", "本机已限制语音识别。")
        }
    }
}
