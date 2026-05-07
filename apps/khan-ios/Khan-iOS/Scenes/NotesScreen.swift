import SwiftUI
import SwiftData
import KhanCore
import KhanUI

/// Notes tab — list of all Notes, newest-edited first. Tap a row to open a
/// simple editor sheet; tap the "+" toolbar button to create a new note.
struct NotesScreen: View {
    @ObservedObject private var lang = LanguageSettings.shared
    @Environment(\.modelContext) private var ctx

    @Query(sort: [SortDescriptor(\Note.updatedAt, order: .reverse)])
    private var notes: [Note]

    @State private var editing: Note?

    var body: some View {
        NavigationStack {
            ScrollView {
                if notes.isEmpty {
                    emptyState
                        .padding(.top, 80)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(notes) { n in
                            Button {
                                editing = n
                            } label: {
                                NoteRow(note: n)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(14)
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

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "note.text")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.4))
            Text(L("No notes yet", "暂无笔记"))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.65))
            Text(L("Tap + to create one.", "点击 + 新建一条。"))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
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
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if !note.bodyMarkdown.isEmpty {
                        Text(note.bodyMarkdown)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(2)
                    }
                    Text(note.updatedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                }
                Spacer(minLength: 0)
            }
            .padding(12)
        }
    }
}

/// Lightweight editor sheet — title field + multi-line body. Edits persist
/// through the model context automatically (SwiftData property bindings).
private struct NoteEditorSheet: View {
    @Bindable var note: Note
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var lang = LanguageSettings.shared

    var body: some View {
        NavigationStack {
            ZStack {
                CyberBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        TextField(L("Title", "标题"), text: $note.title, axis: .vertical)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .textFieldStyle(.plain)
                        Divider().overlay(Color.white.opacity(0.1))
                        TextEditor(text: $note.bodyMarkdown)
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(minHeight: 320)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                    }
                    .padding(18)
                }
                .scrollContentBackground(.hidden)
            }
            .ignoresSafeArea()
            .navigationTitle(L("Edit", "编辑"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("Done", "完成")) {
                        note.updatedAt = Date()
                        dismiss()
                    }
                    .foregroundStyle(CyberPalette.neonCyan)
                }
            }
        }
    }
}
