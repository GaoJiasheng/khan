import Foundation
import KhanIPC

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
    let displayMode: DisplayMode
    let receivedAt: Date
}
