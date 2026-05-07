import SwiftUI
import SwiftData
import KhanCore
import KhanUI

/// Inbox tab — list of Messages received via CloudKit / local insertion,
/// rendered as cyber-themed cards. Mirrors the Mac AnchorInboxView but
/// vertically scrollable for a phone form factor.
struct InboxScreen: View {
    @ObservedObject private var lang = LanguageSettings.shared

    @Query(sort: [SortDescriptor(\Message.receivedAt, order: .reverse)])
    private var messages: [Message]

    var body: some View {
        let active = messages.filter { $0.state == .inbox }
        NavigationStack {
            ScrollView {
                if active.isEmpty {
                    emptyState
                        .padding(.top, 80)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(active) { m in
                            InboxRow(message: m)
                        }
                    }
                    .padding(14)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(L("Inbox", "收件箱"))
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.4))
            Text(L("No new messages", "暂无新消息"))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.65))
        }
    }
}

private struct InboxRow: View {
    let message: Message

    var body: some View {
        CyberCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: message.iconName ?? message.source.sfSymbol)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(CyberPalette.neonCyan)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 3) {
                    Text(message.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    if let body = message.bodyMarkdown, !body.isEmpty {
                        Text(body)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.65))
                            .lineLimit(3)
                    }
                    Text(message.receivedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                }
                Spacer(minLength: 0)
            }
            .padding(12)
        }
    }
}
