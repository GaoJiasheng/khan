import Foundation
import SwiftUI
import Combine

/// User-tunable appearance preferences. Persisted in `UserDefaults`. The notch
/// extension shape ignores the opacity (we always want it pure black so it fuses
/// with the real notch); every other shape honors it.
@MainActor
final class AppearanceSettings: ObservableObject {
    static let shared = AppearanceSettings()

    @Published var backgroundOpacity: Double {
        didSet {
            UserDefaults.standard.set(backgroundOpacity, forKey: "doris.appearance.backgroundOpacity")
        }
    }

    private init() {
        let raw = UserDefaults.standard.object(forKey: "doris.appearance.backgroundOpacity") as? Double
        self.backgroundOpacity = raw ?? 1.0
    }
}
