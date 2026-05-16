import SwiftUI
import SwiftData
import DorisCore
import DorisUI

/// iOS Notes screen — mirrors Mac's MainNotesList flow:
///   · `@Query` of non-archived Notes sorted pinned-first then by `updatedAt desc`
///   · CyberCard rows with icon + title + body excerpt + relative time
///   · Tap → push `NoteDetailScreen` (NavigationLink)
///   · "+" creates and pushes immediately
///   · Swipe-to-delete (trailing) → soft-archive
///   · Leading swipe → toggle pin
///   · Long-press contextMenu → Pin/Unpin · Archive · Set Due Date
///   · Pull-to-refresh → `AppCommands.syncNow`
///   · `.searchable` filters on title + body
///   · Sync pill (top) turns red on error; calendar button pushes TodayScreen
struct NotesScreen: View {
    @ObservedObject private var lang = LanguageSettings.shared
    @ObservedObject private var sync = SyncSettings.shared
    @ObservedObject private var theme = ThemeSettings.shared
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

    @State private var path = NavigationPath()
    @State private var showSettings = false
    @State private var nowTick: Date = Date()
    @State private var searchText: String = ""
    @State private var dueDateNoteID: UUID?   // which note's due-date picker is open
    private let tickTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var filteredNotes: [Note] {
        guard !searchText.isEmpty else { return sortedNotes }
        let q = searchText.lowercased()
        return sortedNotes.filter {
            $0.title.lowercased().contains(q) ||
            $0.bodyMarkdown.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if filteredNotes.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 80)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(filteredNotes) { n in
                        NavigationLink(value: n.id) {
                            NoteRow(note: n)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 14, bottom: 4, trailing: 14))
                        // Trailing swipe: archive
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                n.archive()
                                try? ctx.save()
                            } label: {
                                Label(L("Archive", "归档"), systemImage: "archivebox")
                            }
                        }
                        // Leading swipe: toggle pin
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                n.pinned.toggle()
                                n.touch()
                                try? ctx.save()
                            } label: {
                                Label(
                                    n.pinned ? L("Unpin", "取消置顶") : L("Pin", "置顶"),
                                    systemImage: n.pinned ? "pin.slash" : "pin"
                                )
                            }
                            .tint(CyberPalette.neonPink)
                        }
                        // Long-press context menu
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
                            Button {
                                dueDateNoteID = n.id
                            } label: {
                                Label(L("Set due date", "设置截止日期"), systemImage: "calendar")
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
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .searchable(text: $searchText,
                        prompt: L("Search notes…", "搜索笔记…"))
            .refreshable { await runSync() }
            .navigationTitle(L("Notes", "笔记"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    ThemeToggleButton()
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.primary.opacity(0.75))
                    }
                    NavigationLink(value: "today") {
                        Image(systemName: "calendar")
                            .foregroundStyle(CyberPalette.neonCyan.opacity(0.85))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let n = Note(title: "")
                        ctx.insert(n)
                        try? ctx.save()
                        path.append(n.id)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(CyberPalette.neonPink)
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                syncPill
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
            }
            // Note detail destination
            .navigationDestination(for: UUID.self) { id in
                if let note = notes.first(where: { $0.id == id }) {
                    NoteDetailScreen(note: note) {
                        if !path.isEmpty { path.removeLast() }
                    }
                } else {
                    Text(L("Note not found", "笔记不存在"))
                        .foregroundStyle(.secondary)
                }
            }
            // Today screen destination
            .navigationDestination(for: String.self) { dest in
                if dest == "today" {
                    TodayScreen()
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsScreen()
            }
            // Quick due-date picker from contextMenu
            .sheet(item: Binding(
                get: { dueDateNoteID.flatMap { id in notes.first { $0.id == id } } },
                set: { if $0 == nil { dueDateNoteID = nil } }
            )) { note in
                quickDueDateSheet(note: note)
            }
            .onReceive(tickTimer) { nowTick = $0 }
        }
    }

    private func runSync() async {
        AppCommands.syncNow()
        try? await Task.sleep(nanoseconds: 600_000_000)
    }

    // MARK: - Quick due-date sheet (from contextMenu)

    private func quickDueDateSheet(note: Note) -> some View {
        NavigationStack {
            VStack(spacing: 20) {
                DatePicker(
                    L("Due date", "截止日期"),
                    selection: Binding(
                        get: { note.dueDate ?? Date() },
                        set: { note.dueDate = $0; note.touch(); try? ctx.save() }
                    ),
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .tint(CyberPalette.neonCyan)

                if note.dueDate != nil {
                    Button(role: .destructive) {
                        note.dueDate = nil
                        note.touch()
                        try? ctx.save()
                        dueDateNoteID = nil
                    } label: {
                        Label(L("Clear due date", "清除截止日期"), systemImage: "xmark.circle")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .navigationTitle(L("Set due date", "设置截止日期"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("Done", "完成")) { dueDateNoteID = nil }
                        .foregroundStyle(CyberPalette.neonCyan)
                }
            }
            .background { CyberBackground().ignoresSafeArea() }
        }
        .preferredColorScheme(theme.mode.colorScheme)
        .presentationDetents([.medium])
    }

    // MARK: - Sync pill

    private var syncPill: some View {
        let hasError = sync.lastSyncError != nil
        return HStack(spacing: 8) {
            Image(systemName: hasError ? "icloud.slash" :
                  (sync.cloudKitEnabled ? "icloud.fill" : "icloud.slash"))
                .font(.caption)
                .foregroundStyle(hasError ? .red :
                    (sync.cloudKitEnabled ? CyberPalette.neonCyan : .primary.opacity(0.5)))
            Text(syncStatusLabel)
                .font(.caption2)
                .foregroundStyle(hasError ? .red : .primary.opacity(0.65))
                .monospacedDigit()
            Spacer(minLength: 0)
            Button {
                if hasError {
                    showSettings = true
                } else {
                    AppCommands.syncNow()
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: hasError ? "exclamationmark.circle" :
                          "arrow.triangle.2.circlepath")
                        .font(.system(size: 10, weight: .semibold))
                    Text(hasError ? L("Error", "错误") : L("Sync", "同步"))
                        .font(.caption2.weight(.medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(
                    (hasError ? Color.red : CyberPalette.neonCyan).opacity(0.15)
                ))
                .overlay(Capsule().stroke(
                    (hasError ? Color.red : CyberPalette.neonCyan).opacity(0.45),
                    lineWidth: 0.6
                ))
                .foregroundStyle(hasError ? .red : .primary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .opacity(0.6)
        )
        .overlay(
            Capsule()
                .stroke(
                    hasError ? Color.red.opacity(0.35) : Color.primary.opacity(0.08),
                    lineWidth: hasError ? 0.8 : 0.5
                )
        )
    }

    private var syncStatusLabel: String {
        if let err = sync.lastSyncError {
            let truncated = err.count > 40 ? String(err.prefix(40)) + "…" : err
            return truncated
        }
        guard sync.cloudKitEnabled else {
            return L("Local only", "仅本地")
        }
        guard let last = sync.lastSyncedAt else {
            return L("Never synced", "尚未同步")
        }
        _ = nowTick
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return L("Synced ", "已同步 ") + f.localizedString(for: last, relativeTo: Date())
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "note.text")
                .font(.system(size: 36))
                .foregroundStyle(.primary.opacity(0.4))
            Text(searchText.isEmpty
                 ? L("No notes yet", "暂无笔记")
                 : L("No results", "无搜索结果"))
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.65))
            if searchText.isEmpty {
                Text(L("Tap + to create one. Pull down to sync.",
                       "点击 + 新建一条。下拉同步。"))
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.45))
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Row

private struct NoteRow: View {
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
                            .font(.subheadline.weight(.semibold))
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
                            .font(.caption)
                            .foregroundStyle(.primary.opacity(0.55))
                            .lineLimit(2)
                    }
                    HStack(spacing: 6) {
                        Text(note.updatedAt, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.primary.opacity(0.4))
                        if let due = note.dueDate {
                            dueDateChip(due)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(12)
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
