import SwiftUI
import SwiftData
import DorisCore
import DorisUI

/// Notes tab — list of all Notes, newest-edited first. Tap a row to open
/// the shared `NoteEditorSheet` (same one macOS uses, full cyber chrome).
/// "+" toolbar button creates a fresh note and immediately opens it.
///
/// Swipe-to-delete works because the rows are inside a `List` (the new
/// `.swipeActions` modifier needs that context). Pull-to-refresh runs
/// the same manual sync hook the Settings screen and Inbox use.
struct NotesScreen: View {
    @ObservedObject private var lang = LanguageSettings.shared
    @Environment(\.modelContext) private var ctx

    @Query(sort: [SortDescriptor(\Note.updatedAt, order: .reverse)])
    private var notes: [Note]

    @State private var editing: Note?

    var body: some View {
        NavigationStack {
            Group {
                if notes.isEmpty {
                    ScrollView {
                        emptyState.padding(.top, 80)
                    }
                    .refreshable { await runSync() }
                } else {
                    List {
                        ForEach(notes) { n in
                            Button {
                                editing = n
                            } label: {
                                NoteRow(note: n)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 14, bottom: 4, trailing: 14))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    ctx.delete(n)
                                    try? ctx.save()
                                } label: {
                                    Label(L("Delete", "删除"), systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .refreshable { await runSync() }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(L("Notes", "笔记"))
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let n = Note(title: L("New note", "新笔记"))
                        ctx.insert(n)
                        try? ctx.save()
                        editing = n
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(CyberPalette.neonPink)
                    }
                }
            }
            .sheet(item: $editing) { note in
                NoteEditorSheet(note: note)
            }
        }
    }

    private func runSync() async {
        AppCommands.syncNow()
        try? await Task.sleep(nanoseconds: 600_000_000)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "note.text")
                .font(.system(size: 36))
                .foregroundStyle(.primary.opacity(0.4))
            Text(L("No notes yet", "暂无笔记"))
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.65))
            Text(L("Tap + to create one. Pull down to sync.",
                   "点击 + 新建一条。下拉同步。"))
                .font(.caption)
                .foregroundStyle(.primary.opacity(0.45))
                .multilineTextAlignment(.center)
        }
    }
}

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
                    if !note.bodyMarkdown.isEmpty {
                        Text(note.bodyMarkdown)
                            .font(.caption)
                            .foregroundStyle(.primary.opacity(0.55))
                            .lineLimit(2)
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
}
