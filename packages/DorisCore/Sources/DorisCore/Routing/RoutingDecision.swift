import Foundation
import DorisIPC

public struct RoutingDecision: Sendable {
    public let displaySuppressed: Bool
    public let displayBanner: Bool
    public let displayFix: Bool
    public let broadcastToOutbox: Bool

    public init(displaySuppressed: Bool, displayBanner: Bool, displayFix: Bool, broadcastToOutbox: Bool) {
        self.displaySuppressed = displaySuppressed
        self.displayBanner = displayBanner
        self.displayFix = displayFix
        self.broadcastToOutbox = broadcastToOutbox
    }
}
