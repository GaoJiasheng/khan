import Foundation
import DorisIPC

enum AnchorState: Equatable {
    case idle
    case banner(message: AnchorMessage)
    case fix(message: AnchorMessage)
    case expanded
}

struct AnchorMessage: Equatable {
    let id: UUID
    let title: String
    let body: String?
    let iconName: String?
    let level: EventLevel
    let displayMode: DisplayMode
    let receivedAt: Date
    /// What happens when the user clicks the banner card itself.
    /// `nil` → fall back to "dismiss banner + expand Doris dropdown"
    /// (the historical default for events that have no specific
    /// landing place).
    /// `.openURL(claude://)` etc. → open the originating app via
    /// LaunchServices, without expanding Doris. This is what
    /// Claude/Codex/ChatGPT integrations send so the user lands
    /// straight in the source app on click.
    let clickAction: ClickAction?
}

extension EventLevel {
    /// How long an auto-dismiss banner of this level stays on screen.
    /// `critical` is sticky and never returns a finite duration; the
    /// caller routes critical through the `fix` path instead.
    var bannerDuration: TimeInterval {
        switch self {
        case .info:     return 1.5
        case .reminder: return 4.0
        case .critical: return .infinity
        }
    }
}
