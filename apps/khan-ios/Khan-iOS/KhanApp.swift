import SwiftUI
import SwiftData
import KhanCore
import KhanIPC

@main
struct KhanApp: App {
    @UIApplicationDelegateAdaptor(KhanAppDelegate.self) var appDelegate
    @State private var modelContainer: ModelContainer? = makeContainer()

    var body: some Scene {
        WindowGroup {
            if let modelContainer {
                RootTabView()
                    .modelContainer(modelContainer)
            } else {
                Text("Khan failed to initialize. Please ensure iCloud is signed in.")
                    .padding()
            }
        }
    }
}

private func makeContainer() -> ModelContainer? {
    do {
        return try ModelContainerFactory.make(useCloudKit: true)
    } catch {
        return try? ModelContainerFactory.make(useCloudKit: false)
    }
}
