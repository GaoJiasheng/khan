import SwiftUI
import SwiftData
import KhanCore
import KhanIPC
import KhanUI

@main
struct KhanApp: App {
    @UIApplicationDelegateAdaptor(KhanAppDelegate.self) var appDelegate
    /// Single shared container, mirrors macOS. Read once via `KhanRuntime`
    /// so AppDelegate (background sync, push handler) and the SwiftUI
    /// scene see the **same** SwiftData store.
    private let modelContainer: ModelContainer = KhanRuntime.shared.container
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
