import SwiftUI
import DorisCore

public struct InboxRowView: View {
    public let message: Message

    public init(message: Message) {
        self.message = message
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: message.iconName ?? message.source.sfSymbol)
                .foregroundStyle(.tint)
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(message.title)
                        .font(.headline)
                    Spacer()
                    Text(message.receivedAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let body = message.bodyMarkdown, !body.isEmpty {
                    Text(body)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                HStack(spacing: 6) {
                    Text(message.source.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let appID = message.sourceAppId {
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(appID)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    if message.displayMode == .fix {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
