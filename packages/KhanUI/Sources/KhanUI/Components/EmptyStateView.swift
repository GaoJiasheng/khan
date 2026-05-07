import SwiftUI

public struct KhanEmptyStateView: View {
    public let title: String
    public let systemImage: String
    public let subtitle: String?

    public init(title: String, systemImage: String, subtitle: String? = nil) {
        self.title = title
        self.systemImage = systemImage
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}
