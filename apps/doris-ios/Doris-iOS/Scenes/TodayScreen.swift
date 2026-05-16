import SwiftUI
import SwiftData
import DorisCore
import DorisUI

/// iOS Today / Agenda screen — shows notes in three strips, same logic
/// as Mac's Today view:
///
///   1. **Overdue / Due today** — notes with `dueDate <= endOfToday`, sorted
///      by dueDate asc (most overdue first). Red chip = overdue, yellow = today.
///   2. **Pinned** — pinned non-archived notes without a due date (already
///      shown in strip 1 if they have a due date), sorted by updatedAt desc.
///   3. **Recent** — notes updated in the last 24 hours, sorted by updatedAt desc.
///      Provides useful content before any due dates are set.
///
/// Tap a row → `NoteDetailScreen` (same NavigationLink pattern as NotesScreen).
struct TodayScreen: View {
    @ObservedObject private var lang = LanguageSettings.shared
    @Environment(\.modelContext) private var ctx

    @Query(
        filter: #Predicate<Note> { note in !note.archived },
        sort: [SortDescriptor(\Note.updatedAt, order: .reverse)]
    )
    private var allNotes: [Note]

    @State private var path = NavigationPath()

    // Pre-computed strips
    private var dueNotes: [Note] {
        let endOfToday = Calendar.current.startOfDay(for: Date())
            .addingTimeInterval(24 * 60 * 60 - 1)
        return allNotes
            .filter { $0.dueDate != nil && $0.dueDate! <= endOfToday }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    private var pinnedNotes: [Note] {
        let dueIDs = Set(dueNotes.map(\.id))
        return allNotes.filter { $0.pinned && !dueIDs.contains($0.id) }
    }

    private var recentNotes: [Note] {
        let cutoff = Date().addingTimeInterval(-24 * 60 * 60)
        let dueIDs = Set(dueNotes.map(\.id))
        let pinnedIDs = Set(pinnedNotes.map(\.id))
        return allNotes.filter {
            $0.updatedAt >= cutoff && !dueIDs.contains($0.id) && !pinnedIDs.contains($0.id)
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if dueNotes.isEmpty && pinnedNotes.isEmpty && recentNotes.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 80)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    // Strip 1: Due / Overdue
                    if !dueNotes.isEmpty {
                        Section {
                            ForEach(dueNotes) { n in
                                todayRow(n)
                            }
                        } header: {
                            Text(L("Due", "截止任务"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(CyberPalette.neonPink.opacity(0.8))
                                .textCase(nil)
                        }
                    }

                    // Strip 2: Pinned
                    if !pinnedNotes.isEmpty {
                        Section {
                            ForEach(pinnedNotes) { n in
                                todayRow(n)
                            }
                        } header: {
                            Text(L("Pinned", "置顶"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(CyberPalette.neonCyan.opacity(0.8))
                                .textCase(nil)
                        }
                    }

                    // Strip 3: Recent (last 24h)
                    if !recentNotes.isEmpty {
                        Section {
                            ForEach(recentNotes) { n in
                                todayRow(n)
                            }
                        } header: {
                            Text(L("Recent", "最近 24 小时"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary.opacity(0.5))
                                .textCase(nil)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .navigationTitle(L("Today", "今日"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(for: UUID.self) { id in
                if let note = allNotes.first(where: { $0.id == id }) {
                    NoteDetailScreen(note: note) {
                        if !path.isEmpty { path.removeLast() }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func todayRow(_ n: Note) -> some View {
        NavigationLink(value: n.id) {
            TodayNoteRow(note: n)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 4, leading: 14, bottom: 4, trailing: 14))
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 36))
                .foregroundStyle(.primary.opacity(0.4))
            Text(L("Nothing due or pinned today", "今日无截止或置顶任务"))
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.65))
            Text(L("Set a due date on a note to see it here.",
                   "在笔记上设置截止日期，它就会出现在这里。"))
                .font(.caption)
                .foregroundStyle(.primary.opacity(0.45))
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Today row

private struct TodayNoteRow: View {
    let note: Note

    var body: some View {
        CyberCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: note.isChecklist ? "checklist" : "note.text")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(CyberPalette.neonPink.opacity(0.85))
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 3) {
                    Text(note.title.isEmpty ? L("Untitled", "无标题") : note.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let due = note.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 9))
                            Text(due, format: .dateTime.weekday(.abbreviated)
                                    .month(.abbreviated).day())
                                .font(.caption.monospacedDigit())
                        }
                        .foregroundStyle(dueDateColor(due))
                    }

                    Text(note.updatedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.primary.opacity(0.4))
                }
                Spacer(minLength: 0)
            }
            .padding(12)
        }
    }

    private func dueDateColor(_ due: Date) -> Color {
        if due < Date() { return .red }
        if Calendar.current.isDateInToday(due) { return .yellow }
        return CyberPalette.neonCyan
    }
}
