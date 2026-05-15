import SwiftUI
import SwiftData
import DorisCore

/// In-place note editor — drops into whatever container the host
/// provides (a column in the main window's split view, the dropdown
/// panel's tab body, an iOS NavigationStack push). Unlike
/// `NoteEditorSheet` it does NOT wrap itself in a sheet / NavigationStack
/// / fixed-frame VStack — it's just the editor content + a header strip
/// with Back / Delete / Done. Use for the lightweight "edit in place"
/// flow Doris is moving toward (no separate window or sheet pop-up
/// for editing notes).
///
/// The host is responsible for:
/// - Providing the surrounding chrome (background, borders, padding).
/// - Handling the `onClose` callback (typically: clear the
///   currently-edited note so the parent re-renders with the list view).
public struct InlineNoteEditor: View {
    @Bindable public var note: Note
    @Environment(\.modelContext) private var ctx
    @ObservedObject private var lang = LanguageSettings.shared
    @State private var confirmingDelete: Bool = false

    /// Called when the user wants to leave editing — Back button, Done
    /// button, or after a successful Delete. The host swaps the editor
    /// back out for whatever was there before (usually the notes list).
    public var onClose: () -> Void

    public init(note: Note, onClose: @escaping () -> Void) {
        self.note = note
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 8)
            Divider().overlay(Color.primary.opacity(0.08))
            ScrollView {
                editorBody
                    .padding(14)
            }
            .scrollContentBackground(.hidden)
        }
        .alert(
            L("Delete this note?", "删除这条笔记?"),
            isPresented: $confirmingDelete
        ) {
            Button(L("Delete", "删除"), role: .destructive) {
                note.archive()
                try? ctx.save()
                onClose()
            }
            Button(L("Cancel", "取消"), role: .cancel) {}
        } message: {
            Text(L("This can't be undone.", "此操作无法撤销。"))
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Button {
                note.touch()
                try? ctx.save()
                onClose()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text(L("Back", "返回"))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundStyle(.primary.opacity(0.75))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])

            Spacer(minLength: 0)

            Image(systemName: note.isChecklist ? "checklist" : "note.text")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(CyberPalette.neonPink.opacity(0.85))
            Text(L("Edit", "编辑"))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .kerning(0.4)
                .foregroundStyle(.primary.opacity(0.85))

            Spacer(minLength: 0)

            Button(role: .destructive) {
                confirmingDelete = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(CyberPalette.neonPink.opacity(0.9))
            }
            .buttonStyle(.plain)
            .help(L("Delete this note", "删除这条笔记"))
        }
    }

    private var editorBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(
                L("Title", "标题"),
                text: $note.title,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(2)

            HStack(spacing: 12) {
                Toggle(isOn: $note.pinned) {
                    Label(L("Pinned", "置顶"), systemImage: "pin.fill")
                        .font(.caption2)
                }
                .toggleStyle(.button)
                .tint(CyberPalette.neonPink)
                .controlSize(.small)
                .onChange(of: note.pinned) { _, _ in note.touch() }

                Toggle(isOn: $note.isChecklist) {
                    Label(L("Checklist", "清单"), systemImage: "checklist")
                        .font(.caption2)
                }
                .toggleStyle(.button)
                .tint(CyberPalette.neonCyan)
                .controlSize(.small)
                .onChange(of: note.isChecklist) { _, _ in note.touch() }

                // Due date chip
                DueDateChipButton(note: note)

                Spacer()

                Text(note.updatedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.primary.opacity(0.45))
            }

            Divider().overlay(Color.primary.opacity(0.08))

            if note.isChecklist {
                ChecklistEditorView(note: note)
                    .frame(minHeight: 200)
            } else {
                TextEditor(text: $note.bodyMarkdown)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 220)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.primary.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(.primary.opacity(0.07), lineWidth: 0.5)
                    )
            }
        }
        // Stamp updatedAt as the user types so the list re-sorts in
        // real time. SwiftData persists the change automatically.
        .onChange(of: note.bodyMarkdown) { _, _ in note.touch() }
        .onChange(of: note.title)        { _, _ in note.touch() }
    }
}
