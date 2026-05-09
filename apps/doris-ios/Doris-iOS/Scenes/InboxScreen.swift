import SwiftUI
import SwiftData
import DorisCore
import DorisUI

/// Inbox tab — list of Messages received via CloudKit / local insertion,
/// rendered as cyber-themed cards. Mirrors the Mac AnchorInboxView but
/// vertically scrollable for a phone form factor.
///
/// Pull-to-refresh fires `AppCommands.syncNow` (manual sync) so the user
/// can force a CloudKit poke without going to Settings.
struct InboxScreen: View {
    @ObservedObject private var lang = LanguageSettings.shared
    @Environment(\.modelContext) private var ctx

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
                                .contextMenu {
                                    Button {
                                        m.state = .actioned
                                        try? ctx.save()
                                    } label: {
                                        Label(L("Mark done", "标为已读"), systemImage: "checkmark.circle")
                                    }
                                    Button {
                                        m.state = .dismissed
                                        try? ctx.save()
                                    } label: {
                                        Label(L("Dismiss", "忽略"), systemImage: "xmark.circle")
                                    }
                                    Button(role: .destructive) {
                                        ctx.delete(m)
                                        try? ctx.save()
                                    } label: {
                                        Label(L("Delete", "删除"), systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .padding(14)
                }
            }
            .scrollContentBackground(.hidden)
            .refreshable {
                // Run the same hook the Settings "Sync Now" button uses.
                // Fire-and-forget into the AppDelegate — the sync timer
                // pokes synchronously on the main actor and updates
                // `SyncSettings.lastSyncedAt`, so the UI just observes.
                AppCommands.syncNow()
                try? await Task.sleep(nanoseconds: 600_000_000)
            }
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
                .foregroundStyle(.primary.opacity(0.4))
            Text(L("No new messages", "暂无新消息"))
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.65))
            Text(L("Pull down to sync now.", "下拉以立即同步。"))
                .font(.caption)
                .foregroundStyle(.primary.opacity(0.45))
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
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if let body = message.bodyMarkdown, !body.isEmpty {
                        Text(body)
                            .font(.caption)
                            .foregroundStyle(.primary.opacity(0.65))
                            .lineLimit(3)
                    }
                    Text(message.receivedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.primary.opacity(0.4))
                }
                Spacer(minLength: 0)
            }
            .padding(12)
        }
    }
}
