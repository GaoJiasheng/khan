import Foundation
#if canImport(AppKit)
import AppKit
#endif

enum AppLauncher {
    static let bundleID = "com.gavin.doris"

    static func isRunning() -> Bool {
        #if canImport(AppKit)
        return !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
        #else
        return false
        #endif
    }

    static func launchIfNeeded() -> Bool {
        #if canImport(AppKit)
        if isRunning() { return true }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return false
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.addsToRecentItems = false
        let semaphore = DispatchSemaphore(value: 0)
        var success = false
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            success = (error == nil)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 5)
        return success
        #else
        return false
        #endif
    }
}
