import AppIntents
import Foundation

struct OpenSidebarIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Sidebar"
    static var description = IntentDescription("Open the khan sidebar (macOS).")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        if let url = URL(string: "khan://sidebar") {
            #if canImport(AppKit)
            await MainActor.run {
                NSWorkspace.shared.open(url)
            }
            #endif
        }
        return .result()
    }
}

#if canImport(AppKit)
import AppKit
#endif
