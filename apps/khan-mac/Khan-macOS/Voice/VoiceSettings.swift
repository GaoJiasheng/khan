import Foundation
import SwiftUI
import Combine

/// One row in the user's voice-bindings table. Each binding is fully
/// independent: its own trigger key, language, target app, and auto-submit
/// flag. Persisted as part of `VoiceSettings.bindings` (JSON-encoded).
struct VoiceBinding: Identifiable, Codable, Hashable {
    var id: UUID
    var triggerKey: VoiceSettings.TriggerKey
    var provider: VoiceSettings.Provider
    var language: VoiceSettings.VoiceLanguage
    var autoSubmit: Bool

    init(
        id: UUID = UUID(),
        triggerKey: VoiceSettings.TriggerKey,
        provider: VoiceSettings.Provider,
        language: VoiceSettings.VoiceLanguage = .auto,
        autoSubmit: Bool = true
    ) {
        self.id = id
        self.triggerKey = triggerKey
        self.provider = provider
        self.language = language
        self.autoSubmit = autoSubmit
    }
}

@MainActor
final class VoiceSettings: ObservableObject {
    static let shared = VoiceSettings()

    enum TriggerKey: String, CaseIterable, Identifiable, Codable {
        case rightControl
        case leftControl
        case rightShift
        case leftShift
        case fn

        var id: String { rawValue }

        var keyCode: UInt16 {
            switch self {
            case .leftShift:    return 56
            case .rightShift:   return 60
            case .leftControl:  return 59
            case .rightControl: return 62
            case .fn:           return 63
            }
        }

        @MainActor
        var displayName: String {
            switch self {
            case .leftShift:    return L("Left Shift",    "左 Shift")
            case .rightShift:   return L("Right Shift",   "右 Shift")
            case .leftControl:  return L("Left Control",  "左 Control")
            case .rightControl: return L("Right Control", "右 Control")
            case .fn:           return L("Fn",            "Fn")
            }
        }
    }

    /// Where transcribed text gets routed. `frontmost` skips app activation
    /// and just pastes into whatever's currently focused — handy for
    /// Cursor / Slack / generic input boxes.
    enum Provider: String, CaseIterable, Identifiable, Codable {
        case chatGPT
        case claude
        case frontmost

        var id: String { rawValue }

        /// Bundle id we activate. `nil` means "leave whatever's focused alone."
        var bundleId: String? {
            switch self {
            case .chatGPT:   return "com.openai.chat"
            case .claude:    return "com.anthropic.claudefordesktop"
            case .frontmost: return nil
            }
        }

        /// Used when the desktop app isn't installed — open a search-style URL.
        var webFallback: URL? {
            switch self {
            case .chatGPT:   return URL(string: "https://chatgpt.com/")
            case .claude:    return URL(string: "https://claude.ai/new")
            case .frontmost: return nil
            }
        }

        @MainActor
        var displayName: String {
            switch self {
            case .chatGPT:   return L("ChatGPT",        "ChatGPT")
            case .claude:    return L("Claude",         "Claude")
            case .frontmost: return L("Frontmost app",  "当前 App")
            }
        }
    }

    enum VoiceLanguage: String, CaseIterable, Identifiable, Codable {
        case auto
        case chinese
        case english
        case cantonese

        var id: String { rawValue }

        @MainActor
        var displayName: String {
            switch self {
            case .auto:      return L("Auto",      "自动")
            case .chinese:   return L("Chinese",   "中文")
            case .english:   return L("English",   "英文")
            case .cantonese: return L("Cantonese", "粤语")
            }
        }

        var locale: Locale {
            switch self {
            case .chinese:   return Locale(identifier: "zh-CN")
            case .english:   return Locale(identifier: "en-US")
            case .cantonese: return Locale(identifier: "zh-HK")
            case .auto:
                for tag in Locale.preferredLanguages {
                    let l = Locale(identifier: tag)
                    if l.language.languageCode?.identifier == "zh" {
                        return Locale(identifier: "zh-CN")
                    }
                    if l.language.languageCode?.identifier == "en" {
                        return Locale(identifier: "en-US")
                    }
                }
                return Locale(identifier: "en-US")
            }
        }
    }

    @Published var enabled: Bool {
        didSet { UserDefaults.standard.set(enabled, forKey: "khan.voice.enabled") }
    }

    /// User-defined bindings. Each row maps one trigger key to one
    /// (provider, language, autoSubmit). The UI enforces unique trigger
    /// keys across rows; logic ignores duplicates if any slip through.
    @Published var bindings: [VoiceBinding] {
        didSet { persistBindings() }
    }

    private static let bindingsKey = "khan.voice.bindings.v1"

    private init() {
        let d = UserDefaults.standard
        self.enabled = (d.object(forKey: "khan.voice.enabled") as? Bool) ?? true

        if let data = d.data(forKey: Self.bindingsKey),
           let decoded = try? JSONDecoder().decode([VoiceBinding].self, from: data),
           !decoded.isEmpty {
            self.bindings = decoded
        } else {
            // Migrate from the old single-binding settings, or fall back to
            // a sensible default (Right Control → ChatGPT in auto language).
            let oldKey = d.string(forKey: "khan.voice.triggerKey")
                .flatMap(TriggerKey.init(rawValue:)) ?? .rightControl
            let oldLang = d.string(forKey: "khan.voice.language")
                .flatMap(VoiceLanguage.init(rawValue:)) ?? .auto
            let oldProvider = d.string(forKey: "khan.voice.provider")
                .flatMap(Provider.init(rawValue:)) ?? .chatGPT
            let oldAutoSubmit = (d.object(forKey: "khan.voice.autoSubmit") as? Bool) ?? true
            self.bindings = [
                VoiceBinding(
                    triggerKey: oldKey,
                    provider: oldProvider,
                    language: oldLang,
                    autoSubmit: oldAutoSubmit
                )
            ]
        }
    }

    /// Pick a trigger key for a new row that isn't already taken. If every
    /// key is taken (5 used, only 5 supported) we collide on Right Shift —
    /// the UI will visually flag the duplicate.
    func suggestUnusedTriggerKey() -> TriggerKey {
        let used = Set(bindings.map(\.triggerKey))
        return TriggerKey.allCases.first { !used.contains($0) } ?? .rightShift
    }

    func addBinding() {
        bindings.append(VoiceBinding(
            triggerKey: suggestUnusedTriggerKey(),
            provider: .chatGPT,
            language: .auto,
            autoSubmit: true
        ))
    }

    func removeBinding(id: UUID) {
        bindings.removeAll { $0.id == id }
    }

    private func persistBindings() {
        guard let data = try? JSONEncoder().encode(bindings) else { return }
        UserDefaults.standard.set(data, forKey: Self.bindingsKey)
    }
}
