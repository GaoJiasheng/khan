import SwiftUI
import SwiftData
import DorisCore

/// In-place note editor — drops into whatever container the host
/// provides (a column in the main window's split view, the dropdown
/// panel's tab body). Unlike `NoteEditorSheet` it does NOT wrap itself
/// in a sheet / NavigationStack / fixed-frame VStack — it's just a
/// compact toolbar + the editor surface, sized to fill its host.
///
/// Layout priority: text editing area is the hero. The toolbar
/// (Back / Pin / Checklist / Delete) is one tight row at the top so the
/// editor body gets every spare pixel of vertical space.
public struct InlineNoteEditor: View {
    @Bindable public var note: Note
    @Environment(\.modelContext) private var ctx
    @ObservedObject private var lang = LanguageSettings.shared
    @State private var confirmingDelete: Bool = false

    /// Called when the user wants to leave editing — Back button, Esc
    /// key, or after a successful Delete.
    public var onClose: () -> Void

    public init(note: Note, onClose: @escaping () -> Void) {
        self.note = note
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 8) {
            toolbar
                .padding(.horizontal, 12)
                .padding(.top, 8)

            // Title — large, looks like a page title rather than a form
            // field. The "Untitled" placeholder reads as such because
            // we don't render any background / border.
            TextField(
                L("Title", "标题"),
                text: $note.title,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(2)
            .padding(.horizontal, 14)

            // Body editor (or checklist) — fills every remaining pixel.
            // The whole point of the redesign was to maximise this
            // surface area so writing actually feels comfortable.
            Group {
                if note.isChecklist {
                    ScrollView {
                        ChecklistEditorView(note: note)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 4)
                    }
                    .scrollContentBackground(.hidden)
                } else {
                    TextEditor(text: $note.bodyMarkdown)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // Stamp updatedAt as the user types. SwiftData persists
        // automatically; we set it explicitly to drive list re-sort.
        .onChange(of: note.bodyMarkdown) { _, _ in note.touch() }
        .onChange(of: note.title)        { _, _ in note.touch() }
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
            Text(L("The note will be archived and can be recovered from Settings.", "笔记将被归档，可以从设置中恢复。"))
        }
    }

    /// One compact row: Back · Pin · Checklist · spacer · time · Delete.
    /// Replaces the previous two-row design (separate header strip plus
    /// a Pin/Checklist row inside the editor body) — saves ~50pt of
    /// vertical real estate that now goes to the body editor.
    private var toolbar: some View {
        HStack(spacing: 6) {
            // Back
            Button {
                note.touch()
                try? ctx.save()
                onClose()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.75))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(Color.primary.opacity(0.06))
                    )
                    .overlay(
                        Capsule().stroke(Color.primary.opacity(0.15), lineWidth: 0.6)
                    )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
            .help(L("Back to list", "返回列表"))

            pinToggle
            checklistToggle
            DueDateChipButton(note: note)

            Spacer(minLength: 0)

            Text(RelativeTime.short(note.updatedAt))
                .font(.caption2)
                .foregroundStyle(.primary.opacity(0.45))
                .help(absoluteTimeText)

            // Delete
            Button(role: .destructive) {
                confirmingDelete = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(CyberPalette.neonPink.opacity(0.9))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(CyberPalette.neonPink.opacity(0.08))
                    )
                    .overlay(
                        Capsule().stroke(CyberPalette.neonPink.opacity(0.25), lineWidth: 0.6)
                    )
            }
            .buttonStyle(.plain)
            .help(L("Delete this note", "删除这条笔记"))
        }
    }

    /// Pin toggle. Label logic is inverted from the obvious choice:
    ///
    ///   - **off**: outline icon + "置顶" text — the text tells the user
    ///     what the button DOES. Without it, an outline pin icon alone
    ///     is opaque ("does it mean pinned? or is it a generic pin?").
    ///   - **on**: filled neonPink icon, no text — the saturated color
    ///     IS the affordance, "置顶" text would be redundant.
    private var pinToggle: some View {
        Button {
            note.pinned.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: note.pinned ? "pin.fill" : "pin")
                    .font(.system(size: 10, weight: .semibold))
                if !note.pinned {
                    Text(L("Pin", "置顶"))
                        .font(.caption2.weight(.medium))
                }
            }
            .foregroundStyle(note.pinned ? CyberPalette.neonPink : Color.primary.opacity(0.7))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(Color.primary.opacity(0.06))
            )
            .overlay(
                Capsule().stroke(note.pinned
                                 ? CyberPalette.neonPink.opacity(0.4)
                                 : Color.primary.opacity(0.15),
                                 lineWidth: 0.6)
            )
        }
        .buttonStyle(.plain)
        .help(note.pinned
              ? L("Unpin from top", "取消置顶")
              : L("Pin to top of list", "置顶到列表顶部"))
    }

    /// Checklist toggle — same inverted-label logic as `pinToggle`.
    /// Off = outline icon + "清单" text; on = neonCyan icon, no text.
    ///
    /// On enable, prepend `- [ ] ` to every non-empty body line that
    /// isn't already a checkbox — the body field is the SINGLE source
    /// of truth for both modes (no separate `checklistItems` storage),
    /// so flipping the toggle ON should visually transform the user's
    /// existing lines into tasks. Disable doesn't strip the markers
    /// (they're still readable plain text).
    private var checklistToggle: some View {
        Button {
            if !note.isChecklist {
                convertBodyToChecklistMarkers()
            }
            note.isChecklist.toggle()
            note.touch()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "checklist")
                    .font(.system(size: 10, weight: .semibold))
                if !note.isChecklist {
                    Text(L("Checklist", "清单"))
                        .font(.caption2.weight(.medium))
                }
            }
            .foregroundStyle(note.isChecklist ? CyberPalette.neonCyan : Color.primary.opacity(0.7))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(Color.primary.opacity(0.06))
            )
            .overlay(
                Capsule().stroke(note.isChecklist
                                 ? CyberPalette.neonCyan.opacity(0.4)
                                 : Color.primary.opacity(0.15),
                                 lineWidth: 0.6)
            )
        }
        .buttonStyle(.plain)
        .help(note.isChecklist
              ? L("Plain note", "纯文本")
              : L("Convert to checklist", "转为清单"))
    }

    /// Prepend `- [ ] ` to every non-empty body line that isn't already
    /// a checkbox. Called when the user flips the checklist toggle ON
    /// so their existing lines visually become tasks. Idempotent — a
    /// line that already starts with `- [ ]` or `- [x]` is left alone.
    private func convertBodyToChecklistMarkers() {
        let converted = note.bodyMarkdown
            .components(separatedBy: "\n")
            .map { line -> String in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { return line }
                if trimmed.hasPrefix("- [ ]") || trimmed.hasPrefix("- [x]") || trimmed.hasPrefix("- [X]") {
                    return line
                }
                return "- [ ] " + line
            }
            .joined(separator: "\n")
        note.bodyMarkdown = converted
    }

    /// Tooltip — full date for both create and update, since the small
    /// "X 分钟前" caption alone is fuzzy when comparing several notes.
    private var absoluteTimeText: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        let created = f.string(from: note.createdAt)
        let updated = f.string(from: note.updatedAt)
        return L(
            "Created \(created)\nUpdated \(updated)",
            "创建于 \(created)\n更新于 \(updated)"
        )
    }
}
