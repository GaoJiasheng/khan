import SwiftUI
import SwiftData
import KhanCore
import KhanIPC
import KhanUI

@main
struct KhanApp: App {
    @UIApplicationDelegateAdaptor(KhanAppDelegate.self) var appDelegate
    @State private var modelContainer: ModelContainer? = makeContainer()
    @ObservedObject private var lang = LanguageSettings.shared
    @ObservedObject private var theme = ThemeSettings.shared

    var body: some Scene {
        WindowGroup {
            ZStack {
                CyberBackground()
                if let modelContainer {
                    RootTabView()
                        .modelContainer(modelContainer)
                } else {
                    setupErrorView
                }
            }
            .preferredColorScheme(theme.mode.colorScheme)
            .ignoresSafeArea()
        }
    }

    private var setupErrorView: some View {
        VStack(spacing: 12) {
            Image(systemName: "icloud.slash.fill")
                .font(.system(size: 40))
                .foregroundStyle(CyberPalette.neonPink)
            Text(L("Khan couldn't initialize",
                   "Khan 启动失败"))
                .font(.headline)
                .foregroundStyle(.white)
            Text(L("Sign in to iCloud and reopen the app.",
                   "请先登录 iCloud,再重新打开 Khan。"))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}

private func makeContainer() -> ModelContainer? {
    // CloudKit sync is opt-in (matches Mac behavior). Without a paid Apple
    // Developer account + entitlements wired up the iOS Simulator path
    // can't create a CloudKit container — so default to local persistent
    // storage and let users flip to CloudKit once they're signed in.
    if ProcessInfo.processInfo.environment["KHAN_USE_CLOUDKIT"] == "1" {
        if let c = try? ModelContainerFactory.make(useCloudKit: true) { return c }
    }
    return try? ModelContainerFactory.make(useCloudKit: false)
        ?? ModelContainerFactory.make(inMemory: true)
}
