import Foundation
import Combine

/// Cross-window note-edit hand-off. The menu-bar dropdown panel is a
/// `.borderless` `.nonactivatingPanel` and can't reliably host a
/// keyboard-driven sheet — so when the user taps a note row in the
/// dropdown, we set `pendingNoteID` and ask the main window to open. The
/// main window's notes list watches this published value and opens its
/// editor sheet on the matching note as soon as it appears.
///
/// Cleared automatically by the consumer once the editor opens.
@MainActor
public final class NoteFocus: ObservableObject {
    public static let shared = NoteFocus()

    /// Set by the dropdown when the user taps a row. The main window
    /// reads this on body re-evaluation, opens its editor, then nils
    /// it out so a subsequent tap fires again (Combine equality check
    /// would otherwise swallow a re-set with the same UUID).
    @Published public var pendingNoteID: UUID?

    private init() {}

    public func request(_ id: UUID) {
        pendingNoteID = id
    }

    public func clear() {
        pendingNoteID = nil
    }
}
