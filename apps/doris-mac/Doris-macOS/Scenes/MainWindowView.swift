import SwiftUI
import SwiftData
import DorisCore
import DorisUI

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
            ToolbarItem(placement: .primaryAction) {
                SyncNowToolbarButton()
            }
            ToolbarItem(placement: .primaryAction) {
                ThemeToggleButton()
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        AvatarHero(compact: true, showWeather: true, selfChrome: false)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(minWidth: 240)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.04, blue: 0.10),
                        Color(red: 0.01, green: 0.01, blue: 0.04)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
            )
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
        VStack(spacing: 0) {
            detailHeader
            Divider()
                .overlay(Color.primary.opacity(0.08))
            Group {
                switch tab {
                case .inbox: MainInboxList()
                case .notes: MainNotesList()
                }
            }
            .scrollContentBackground(.hidden)
        }
    }

    /// Right-pane header: DORIS brand on the left, tab buttons next to it.
    private var detailHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                Text("DORIS")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .kerning(2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [CyberPalette.neonPink, CyberPalette.neonCyan],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                Text(L("cyber helper", "赛博助手"))
                    .font(.caption2.monospaced())
                    .foregroundStyle(CyberPalette.neonCyan.opacity(0.7))
            }

            HStack(spacing: 6) {
                tabButton(.inbox, label: L("Inbox", "收件箱"), system: "tray.fill")
                tabButton(.notes, label: L("Notes", "笔记"), system: "note.text")
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private func tabButton(_ value: Tab, label: String, system: String) -> some View {
        let isSelected = tab == value
        return Button {
            tab = value
        } label: {
            HStack(spacing: 6) {
                Image(systemName: system)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .kerning(0.4)
            }
            .foregroundStyle(
                isSelected
                    ? AnyShapeStyle(Color.primary)
                    : AnyShapeStyle(Color.primary.opacity(0.55))
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? CyberPalette.neonCyan.opacity(0.14) : Color.clear)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? CyberPalette.neonCyan.opacity(0.45) : Color.clear, lineWidth: 0.6)
            )
        }
        .buttonStyle(.plain)
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

    @Query(
        filter: #Predicate<Note> { note in !note.archived },
        sort: [SortDescriptor(\Note.updatedAt, order: .reverse)]
    )
    private var notes: [Note]

    /// Pin-first ordering: SwiftData's @Query can't sort by Bool keyPaths,
    /// so we sort client-side (pinned notes first, then by updatedAt desc).
    private var sortedNotes: [Note] {
        notes.sorted { a, b in
            if a.pinned != b.pinned { return a.pinned }
            return a.updatedAt > b.updatedAt
        }
    }

    @State private var editing: Note?
    @State private var searchText: String = ""

    private var filteredNotes: [Note] {
        guard !searchText.isEmpty else { return sortedNotes }
        let q = searchText.lowercased()
        return sortedNotes.filter {
            $0.title.lowercased().contains(q) ||
            $0.bodyMarkdown.lowercased().contains(q)
        }
    }

    var body: some View {
        Group {
            if let editing {
                InlineNoteEditor(note: editing) {
                    self.editing = nil
                }
            } else {
                listBody
            }
        }
    }

    private var listBody: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(.primary.opacity(0.4))
                TextField(L("Search notes…", "搜索笔记…"), text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.primary.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.primary.opacity(0.06))
            )
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 8) {
                    HStack {
                        Spacer()
                        Button {
                            let n = Note(title: L("New note", "新笔记"))
                            ctx.insert(n)
                            try? ctx.save()
                            editing = n
                        } label: {
                            Label(L("New", "新建"), systemImage: "plus.circle.fill")
                                .foregroundStyle(CyberPalette.neonPink)
                        }
                        .buttonStyle(.plain)
                    }
                    if filteredNotes.isEmpty {
                        emptyState.padding(.top, 80)
                    } else {
                        ForEach(filteredNotes) { n in
                            Button {
                                editing = n
                            } label: {
                                MacNoteRow(note: n)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    n.pinned.toggle()
                                    n.touch()
                                    try? ctx.save()
                                } label: {
                                    Label(
                                        n.pinned ? L("Unpin", "取消置顶") : L("Pin", "置顶"),
                                        systemImage: n.pinned ? "pin.slash" : "pin.fill"
                                    )
                                }
                                Divider()
                                Button(role: .destructive) {
                                    n.archive()
                                    try? ctx.save()
                                } label: {
                                    Label(L("Archive", "归档"), systemImage: "archivebox")
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: searchText.isEmpty ? "note.text" : "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.primary.opacity(0.4))
            Text(searchText.isEmpty
                 ? L("No notes yet", "暂无笔记")
                 : L("No results", "无搜索结果"))
                .font(.headline)
                .foregroundStyle(.primary.opacity(0.7))
            if searchText.isEmpty {
                Text(L("Click + to start one.", "点击 + 新建一条。"))
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.5))
            }
        }
    }
}

private struct MacNoteRow: View {
    let note: Note

    var body: some View {
        CyberCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: note.isChecklist ? "checklist" : "note.text")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(CyberPalette.neonPink.opacity(0.85))
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        if note.pinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(CyberPalette.neonCyan)
                        }
                        Text(note.title.isEmpty ? L("Untitled", "无标题") : note.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                    if note.isChecklist {
                        let items = note.checklistItems ?? []
                        let done = items.filter(\.done).count
                        if !items.isEmpty {
                            Text("\(done) / \(items.count)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.primary.opacity(0.55))
                        }
                    } else if !note.bodyMarkdown.isEmpty {
                        Text(note.bodyMarkdown)
                            .font(.subheadline)
                            .foregroundStyle(.primary.opacity(0.65))
                            .lineLimit(3)
                    }
                    HStack(spacing: 6) {
                        Text(note.updatedAt, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.primary.opacity(0.45))
                        if let due = note.dueDate {
                            dueDateChip(due)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
        }
    }

    private func dueDateChip(_ due: Date) -> some View {
        let cal = Calendar.current
        let color: Color = due < Date() ? .red : cal.isDateInToday(due) ? .yellow : CyberPalette.neonCyan
        return HStack(spacing: 3) {
            Image(systemName: "calendar")
                .font(.system(size: 8))
            Text(due, format: .dateTime.month(.abbreviated).day())
                .font(.caption2.monospacedDigit())
        }
        .foregroundStyle(color)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Capsule().fill(color.opacity(0.12)))
    }
}
