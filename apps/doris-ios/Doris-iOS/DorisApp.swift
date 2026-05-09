import SwiftUI
import SwiftData
import DorisCore
import DorisIPC
import DorisUI

@main
struct DorisApp: App {
    @UIApplicationDelegateAdaptor(DorisAppDelegate.self) var appDelegate
    /// Single shared container, mirrors macOS. Read once via `DorisRuntime`
    /// so AppDelegate (background sync, push handler) and the SwiftUI
    /// scene see the **same** SwiftData store.
    private let modelContainer: ModelContainer = DorisRuntime.shared.container
    @ObservedObject private var lang = LanguageSettings.shared
    @ObservedObject private var theme = ThemeSettings.shared

    var body: some Scene {
        WindowGroup {
            ZStack {
                CyberBackground()
                RootTabView()
                    .modelContainer(modelContainer)
            }
            .preferredColorScheme(theme.mode.colorScheme)
            .ignoresSafeArea()
        }
    }
}
