import SwiftUI
import SwiftData
import KhanCore
import KhanUI

/// "Deep work" main window. Same cyber vocabulary as the dropdown panel —
/// adaptive backdrop (dark or light, controlled by `ThemeSettings`), the
/// avatar hero in the sidebar header, neon-stroked surface cards in the
/// detail pane. Toolbar exposes the theme toggle so users can flip modes
/// without going to Settings.
///
/// Sidebar items: **Inbox** and **Notes**. The previous "Devices" placeholder
/// was retired since it never had functional content.
struct MainWindowView: View {
    @ObservedObject private var lang = LanguageSettings.shared
    @State private var tab: Tab = .inbox

    enum Tab: Hashable { case inbox, notes }

    var body: some View {
        ZStack {
            CyberBackground(haloIntensity: 0.7)
            NavigationSplitView {
                sidebar
            } detail: {
                detail
            }
            .navigationSplitViewStyle(.balanced)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 760, minHeight: 520)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Text(L("Khan", "Khan"))
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .kerning(2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [CyberPalette.neonPink, CyberPalette.neonCyan],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
            }
            ToolbarItem(placement: .primaryAction) {
                ThemeToggleButton()
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 12) {
            AvatarHero(compact: true)
                .frame(width: 180, height: 180)
                .padding(.top, 12)
                .padding(.horizontal, 12)
            VStack(spacing: 1) {
                Text("KHAN")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .kerning(2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [CyberPalette.neonPink, CyberPalette.neonCyan],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                Text(L("cyber helper", "赛博助手"))
                    .font(.caption2.monospaced())
                    .foregroundStyle(CyberPalette.neonCyan.opacity(0.65))
            }

            Divider()
                .overlay(Color.primary.opacity(0.08))
                .padding(.horizontal, 12)

            VStack(spacing: 4) {
                sidebarItem(.inbox, label: L("Inbox", "收件箱"), system: "tray.fill")
                sidebarItem(.notes, label: L("Notes", "笔记"), system: "note.text")
            }
            .padding(.horizontal, 8)

            Spacer()
        }
        .frame(minWidth: 220)
        .background(.thinMaterial)
    }

    private func sidebarItem(_ value: Tab, label: String, system: String) -> some View {
        let selected = tab == value
        return Button {
            tab = value
        } label: {
            HStack(spacing: 10) {
                Image(systemName: system)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(selected ? AnyShapeStyle(CyberPalette.neonCyan) : AnyShapeStyle(Color.primary.opacity(0.6)))
                    .frame(width: 18)
                Text(label)
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? AnyShapeStyle(Color.primary) : AnyShapeStyle(Color.primary.opacity(0.7)))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selected ? CyberPalette.neonCyan.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(selected ? CyberPalette.neonCyan.opacity(0.4) : Color.clear, lineWidth: 0.6)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Detail

    private var detail: some View {
        Group {
            switch tab {
            case .inbox: MainInboxList()
            case .notes: MainNotesList()
            }
        }
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Inbox

private struct MainInboxList: View {
    @ObservedObject private var lang = LanguageSettings.shared
    @Query(sort: [SortDescriptor(\Message.receivedAt, order: .reverse)])
    private var messages: [Message]

    var body: some View {
        let active = messages.filter { $0.state == .inbox }
        ScrollView {
            VStack(spacing: 8) {
                if active.isEmpty {
                    emptyState
                        .padding(.top, 80)
                } else {
                    ForEach(active) { m in
                        InboxRow(message: m)
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle(L("Inbox", "收件箱"))
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundStyle(.primary.opacity(0.4))
            Text(L("No new messages", "暂无新消息"))
                .font(.headline)
                .foregroundStyle(.primary.opacity(0.7))
            Text(L("CLI pushes, share extension drops, and cross-device messages will land here.",
                   "CLI 通知、Share 扩展、跨设备推送都会出现在这里。"))
                .font(.caption)
                .foregroundStyle(.primary.opacity(0.5))
                .multilineTextAlignment(.center)
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
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if let body = message.bodyMarkdown, !body.isEmpty {
                        Text(body)
                            .font(.subheadline)
                            .foregroundStyle(.primary.opacity(0.7))
                            .lineLimit(3)
                    }
                    Text(message.receivedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.primary.opacity(0.45))
                }
                Spacer(minLength: 0)
            }
            .padding(14)
        }
    }
}

// MARK: - Notes

private struct MainNotesList: View {
    @ObservedObject private var lang = LanguageSettings.shared
    @Environment(\.modelContext) private var ctx
    @Query(sort: [SortDescriptor(\Note.updatedAt, order: .reverse)])
    private var notes: [Note]

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                HStack {
                    Spacer()
                    Button {
                        let n = Note(title: L("New note", "新笔记"))
                        ctx.insert(n)
                    } label: {
                        Label(L("New", "新建"), systemImage: "plus.circle.fill")
                            .foregroundStyle(CyberPalette.neonPink)
                    }
                    .buttonStyle(.plain)
                }
                if notes.isEmpty {
                    emptyState.padding(.top, 80)
                } else {
                    ForEach(notes) { n in
                        NoteRow(note: n)
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle(L("Notes", "笔记"))
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "note.text")
                .font(.system(size: 36))
                .foregroundStyle(.primary.opacity(0.4))
            Text(L("No notes yet", "暂无笔记"))
                .font(.headline)
                .foregroundStyle(.primary.opacity(0.7))
            Text(L("Click + to start one.", "点击 + 新建一条。"))
                .font(.caption)
                .foregroundStyle(.primary.opacity(0.5))
        }
    }
}

private struct NoteRow: View {
    let note: Note

    var body: some View {
        CyberCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "note.text")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(CyberPalette.neonPink.opacity(0.85))
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 3) {
                    Text(note.title.isEmpty ? L("Untitled", "无标题") : note.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if !note.bodyMarkdown.isEmpty {
                        Text(note.bodyMarkdown)
                            .font(.subheadline)
                            .foregroundStyle(.primary.opacity(0.65))
                            .lineLimit(3)
                    }
                    Text(note.updatedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.primary.opacity(0.45))
                }
                Spacer(minLength: 0)
            }
            .padding(14)
        }
    }
}
