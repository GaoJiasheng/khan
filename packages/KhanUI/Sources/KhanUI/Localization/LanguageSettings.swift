import Foundation
import SwiftUI
import Combine

/// User-tunable display language. Persisted in `UserDefaults`. Three modes:
/// English-only, Chinese-only, or bilingual ("English · 中文"). Default is
/// bilingual on first launch since the user explicitly asked for it.
@MainActor
public final class LanguageSettings: ObservableObject {
    public static let shared = LanguageSettings()

    public enum Mode: String, CaseIterable, Identifiable {
        case english = "en"
        case chinese = "zh"
        case bilingual = "both"

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .english:   return "English"
            case .chinese:   return "中文"
            case .bilingual: return "Bilingual · 双语"
            }
        }
    }

    @Published public var mode: Mode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: "khan.language.mode")
        }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: "khan.language.mode")
            ?? Mode.bilingual.rawValue
        self.mode = Mode(rawValue: raw) ?? .bilingual
    }
}

/// Pick the right string for the current display language. Use this for every
/// user-visible label.
///
/// - In `.english` mode returns `en`.
/// - In `.chinese` mode returns `zh`.
/// - In `.bilingual` mode returns `"<en> · <zh>"`.
///
/// Views that call this should observe `LanguageSettings.shared` so they
/// re-render when the user toggles the language.
@MainActor
public func L(_ en: String, _ zh: String) -> String {
    switch LanguageSettings.shared.mode {
    case .english:   return en
    case .chinese:   return zh
    case .bilingual: return "\(en) · \(zh)"
    }
}
