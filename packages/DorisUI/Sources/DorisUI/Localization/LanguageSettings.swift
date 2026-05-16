import Foundation
import SwiftUI
import Combine

/// User-tunable display language. Persisted in `UserDefaults`. Two modes:
/// English-only or Chinese-only. Default is Chinese on first launch.
///
/// Stored rawValue `"both"` from older builds — when bilingual mode was
/// available — falls back to Chinese on read.
@MainActor
public final class LanguageSettings: ObservableObject {
    public static let shared = LanguageSettings()

    public enum Mode: String, CaseIterable, Identifiable {
        case english = "en"
        case chinese = "zh"

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .english: return "English"
            case .chinese: return "中文"
            }
        }
    }

    @Published public var mode: Mode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: "doris.language.mode")
        }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: "doris.language.mode")
            ?? Mode.chinese.rawValue
        // Legacy `.bilingual` ("both") rows demote to Chinese — bilingual
        // is no longer offered as a UI option.
        self.mode = Mode(rawValue: raw) ?? .chinese
    }
}

/// Pick the right string for the current display language. Use this for every
/// user-visible label.
///
/// - In `.english` mode returns `en`.
/// - In `.chinese` mode returns `zh`.
///
/// Views that call this should observe `LanguageSettings.shared` so they
/// re-render when the user toggles the language.
@MainActor
public func L(_ en: String, _ zh: String) -> String {
    switch LanguageSettings.shared.mode {
    case .english: return en
    case .chinese: return zh
    }
}
