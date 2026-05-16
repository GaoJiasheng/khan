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
            // iOS Doris: Today / Events / Notes tab bar.
            // RootTabView hosts the three main tabs; Settings reachable
            // via the Notes tab toolbar gear.
            RootTabView()
                .modelContainer(modelContainer)
                .preferredColorScheme(theme.mode.colorScheme)
        }
    }
}
