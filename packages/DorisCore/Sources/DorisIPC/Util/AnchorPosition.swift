import Foundation

public enum AnchorPosition: String, Codable, CaseIterable, Sendable {
    /// Auto: hugs the right edge of the camera notch on notched MacBooks; renders a
    /// small notch-shaped pill at the top center on screens without a notch.
    case notchAdjacent
    case rightCenter
    case rightTop
    case rightBottom
    case leftCenter
    case notchRight
    case notchLeft
    case topCenter

    public var displayName: String {
        switch self {
        case .notchAdjacent: return "Auto · Beside Notch"
        case .rightCenter:   return "Right · Center"
        case .rightTop:      return "Right · Top"
        case .rightBottom:   return "Right · Bottom"
        case .leftCenter:    return "Left · Center"
        case .notchRight:    return "Notch · Right"
        case .notchLeft:     return "Notch · Left"
        case .topCenter:     return "Top · Center"
        }
    }
}
