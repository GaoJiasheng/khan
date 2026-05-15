import SwiftUI
import SwiftData
import DorisCore
import DorisIPC
import DorisUI

@main
struct DorisApp: App {
    @UIApplicationDelegateAdaptor(DorisAppDelegate.self) var appDelegate
    /// Single shared container, mirrors macOS. Read once via `DorisRuntime`
    /// so AppDelegate (sync timer) and the SwiftUI scene see the **same**
    /// SwiftData store.
    private let modelContainer: ModelContainer = DorisRuntime.shared.container
    @ObservedObject private var lang = LanguageSettings.shared
    @ObservedObject private var theme = ThemeSettings.shared

    var body: some Scene {
        WindowGroup {
            // iOS Doris is a single-screen Notes viewer mirroring macOS's
            // MainNotesList — the Inbox / Today / Voice surfaces from Mac
            // don't ship to iOS. Settings reachable via the toolbar gear.
            NotesScreen()
                .modelContainer(modelContainer)
                .background {
                    CyberBackground().ignoresSafeArea()
                }
                .preferredColorScheme(theme.mode.colorScheme)
        }
    }
}
