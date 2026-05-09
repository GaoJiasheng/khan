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
            // DORIS brand moved into the detail header next to the tab
            // buttons; keep theme toggle + sync button on the toolbar.
            ToolbarItem(placement: .primaryAction) {
                SyncNowToolbarButton()
            }
            ToolbarItem(placement: .primaryAction) {
                ThemeToggleButton()
            }
        }
    }

    // MARK: - Sidebar

    /// Sidebar is now just the avatar — fills top to bottom, edge to
    /// edge, on the same deep-space gradient that the avatar's starry
    /// sky uses internally so there's no visible seam at the title bar.
    /// Brand line + nav tabs were moved to the detail header.
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
    /// Replaces the old left-sidebar nav rows so the avatar can own the
    /// entire left column.
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

    /// Capsule-style tab button. Selected = cyan-accented, unselected =
    /// dim primary. Same vocabulary as the dropdown panel's tab row so
    /// the two surfaces feel like one product.
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
    @ObservedObject private var focus = NoteFocus.shared
    @Environment(\.modelContext) private var ctx
    @Query(sort: [SortDescriptor(\Note.updatedAt, order: .reverse)])
    private var notes: [Note]
    @State private var editing: Note?

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                HStack {
                    Spacer()
                    Button {
                        let n = Note(title: L("New note", "新笔记"))
                        ctx.insert(n)
                        try? ctx.save()
                        // Open the editor immediately for the new note —
                        // matches the "click + then start typing" muscle
                        // memory from Notes / SideNotes.
                        editing = n
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
                        Button {
                            editing = n
                        } label: {
                            NoteRow(note: n)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                ctx.delete(n)
                                try? ctx.save()
                            } label: {
                                Label(L("Delete", "删除"), systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .sheet(item: $editing) { note in
            NoteEditorSheet(note: note)
        }
        // The dropdown panel hands off note edits via `NoteFocus`. When
        // that pending ID matches a known note, open it here in the main
        // window's editor sheet (where keyboard focus actually works).
        .onReceive(focus.$pendingNoteID) { id in
            guard let id, let match = notes.first(where: { $0.id == id }) else { return }
            editing = match
            focus.clear()
        }
        .onAppear {
            // Honor any focus request set BEFORE the view first appeared.
            if let id = focus.pendingNoteID, let match = notes.first(where: { $0.id == id }) {
                editing = match
                focus.clear()
            }
        }
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
