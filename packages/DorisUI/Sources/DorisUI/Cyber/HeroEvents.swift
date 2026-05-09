import Foundation
import Combine
import SwiftUI

/// Global event bus the avatar listens to. Lets any code path fire a mood
/// reaction without having to plumb a binding all the way down. The events
/// are timestamps so a hero can re-fire the same reaction (`celebrate()`
/// twice in a row both run).
///
/// Usage:
///   - `HeroEvents.shared.celebrate()` — when sync finishes, note saves, etc.
///   - `HeroEvents.shared.greet()` — when the dropdown panel opens.
///   - `HeroEvents.shared.alert()` — when a notification arrives.
///   - `HeroEvents.shared.isListening = true/false` — voice capture lifecycle.
@MainActor
public final class HeroEvents: ObservableObject {
    public static let shared = HeroEvents()

    @Published public var lastCelebration: Date = .distantPast
    @Published public var lastGreeting: Date = .distantPast
    @Published public var lastAlert: Date = .distantPast
    @Published public var isListening: Bool = false

    private init() {}

    public func celebrate() { lastCelebration = Date() }
    public func greet()     { lastGreeting    = Date() }
    public func alert()     { lastAlert       = Date() }
}
