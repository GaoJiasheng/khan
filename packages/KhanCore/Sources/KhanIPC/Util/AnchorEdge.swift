import Foundation

public enum AnchorEdge: String, Codable, CaseIterable, Sendable {
    case top, right, bottom, left

    public var displayName: String {
        switch self {
        case .top: return "Top"
        case .right: return "Right"
        case .bottom: return "Bottom"
        case .left: return "Left"
        }
    }
}
