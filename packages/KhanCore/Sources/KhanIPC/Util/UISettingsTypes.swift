import Foundation

public enum SidebarEdge: String, Codable, CaseIterable, Sendable {
    case left, right
}

public enum NotchBehavior: String, Codable, CaseIterable, Sendable {
    case idleHidden
    case idlePillVisible
    case disabled
}

public enum KhanTheme: String, Codable, CaseIterable, Sendable {
    case system, light, dark
}
