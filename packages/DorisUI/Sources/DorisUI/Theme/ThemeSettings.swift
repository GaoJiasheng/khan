import Foundation
import SwiftUI
import Combine

/// Global appearance toggle — dark cyber (default) vs light cyber (cream
/// backdrop with the same neon accents, easier on the eyes during the day).
/// Applied at the scene root via `.preferredColorScheme(...)` so every
/// surface that uses adaptive `CyberPalette` colors flips together.
@MainActor
public final class ThemeSettings: ObservableObject {
    public static let shared = ThemeSettings()

    public enum Mode: String, CaseIterable, Identifiable {
        case dark
        case light

        public var id: String { rawValue }

        @MainActor
        public var displayName: String {
            switch self {
            case .dark:  return L("Dark · 深色",  "深色 · Dark")
            case .light: return L("Light · 浅色", "浅色 · Light")
            }
        }

        public var colorScheme: ColorScheme {
            switch self {
            case .dark:  return .dark
            case .light: return .light
            }
        }

        public var iconName: String {
            switch self {
            case .dark:  return "moon.stars.fill"
            case .light: return "sun.max.fill"
            }
        }

        public var toggled: Mode {
            switch self {
            case .dark:  return .light
            case .light: return .dark
            }
        }
    }

    @Published public var mode: Mode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: "doris.theme.mode") }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: "doris.theme.mode") ?? Mode.dark.rawValue
        self.mode = Mode(rawValue: raw) ?? .dark
    }

    public func toggle() { mode = mode.toggled }
}
