import SwiftUI

public enum KhanColors {
    public static let accent = Color.accentColor
    public static let pinned = Color.orange
    public static let bannerBackground = Color(white: 0.12)
    public static let cardBackground = Color.secondary.opacity(0.06)
}

/// Shared neon palette used across the expanded panel, weather bubble, voice
/// floater, and (now) the iOS UI. Centralized so all surfaces match — pink
/// halo + cyan rim + deep purple/black backdrop are the brand.
public enum CyberPalette {
    public static let neonPink   = Color(red: 1.0, green: 0.30, blue: 0.75)
    public static let neonCyan   = Color(red: 0.0, green: 0.85, blue: 1.0)
    public static let backdropTop    = Color(red: 0.10, green: 0.06, blue: 0.18)
    public static let backdropBottom = Color(red: 0.02, green: 0.02, blue: 0.05)

    public static let panelStroke = LinearGradient(
        colors: [neonPink.opacity(0.40), neonCyan.opacity(0.55)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    public static let backdrop = LinearGradient(
        colors: [backdropTop, backdropBottom],
        startPoint: .top, endPoint: .bottom
    )
}

public extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8 else { return nil }
        var rgba: UInt64 = 0
        guard Scanner(string: s).scanHexInt64(&rgba) else { return nil }
        let r, g, b, a: Double
        if s.count == 6 {
            r = Double((rgba & 0xFF0000) >> 16) / 255
            g = Double((rgba & 0x00FF00) >> 8) / 255
            b = Double(rgba & 0x0000FF) / 255
            a = 1
        } else {
            r = Double((rgba & 0xFF000000) >> 24) / 255
            g = Double((rgba & 0x00FF0000) >> 16) / 255
            b = Double((rgba & 0x0000FF00) >> 8) / 255
            a = Double(rgba & 0x000000FF) / 255
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
