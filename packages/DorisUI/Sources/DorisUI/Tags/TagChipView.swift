import SwiftUI
import DorisCore

public struct TagChipView: View {
    public let name: String
    public let colorHex: String?

    public init(name: String, colorHex: String? = nil) {
        self.name = name
        self.colorHex = colorHex
    }

    public var body: some View {
        Text(name)
            .font(.caption)
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(background)
            .clipShape(Capsule())
    }

    private var background: some View {
        let base = colorHex.flatMap(Color.init(hex:)) ?? Color.secondary.opacity(0.18)
        return base.opacity(0.4)
    }
}
