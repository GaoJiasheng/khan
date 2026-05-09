import AppKit
import SwiftUI
import SwiftData
import KhanCore
import KhanIPC
import KhanMacChrome
import KhanUI

@MainActor
final class KhanAppDelegate: NSObject, NSApplicationDelegate {
    private var anchorController: AnchorController?
    private var router: NotificationRouter?
    private var drainer: IPCInboxDrainer?
    private var fsEventReader: IPCFSEventReader?
    private var darwinKickSubscription: DarwinNotify.Subscription?
    private var syncTimer: SyncTimer?
    private var outboxPublisher: OutboxPublisher?
    private var silentPushHandler: SilentPushHandler?
    private var voiceController: VoiceController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // When launched directly (not via launchd / `open`) the process is a background
        // process and SwiftUI windows don't show. Promote to accessory + show anchor.
        NSApp.setActivationPolicy(.accessory)

        Task { @MainActor in
            try? IPCDirectory.ensureDirectories()
            let secret = try? KeychainSecretStore.ensureSecret()

            // Single shared container — KhanRuntime is the only place that
            // builds one. Anchor + main window + share extension all read
            // from `.shared.container` so edits in one surface in the other.
            let container = KhanRuntime.shared.container
            let cloudKitOn = SyncSettings.shared.cloudKitEnabled

            let router = NotificationRouter(modelContainer: container)
            self.router = router
            if cloudKitOn {
                self.outboxPublisher = OutboxPublisher()
                router.setOutbox(self.outboxPublisher)
            }

            _ = SettingsStore(container: container).load()
            // Anchor lives as an NSStatusItem in the menu bar (system handles placement
            // & cross-screen routing). Click → dropdown panel below it.
            let anchor = AnchorController(modelContainer: container)
            self.anchorController = anchor
            anchor.show()
            // Auto-expand the dropdown so the user lands on their inbox /
            // notes immediately at launch — the main window doesn't open
            // anymore (LSUIElement: true), the dropdown is the primary UI.
            // Tiny delay lets the avatar window finish its first layout
            // pass; without it the panel's "burst-out-of-the-avatar"
            // animation starts from `.zero` and looks broken.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 250_000_000)
                anchor.expand()
            }

            // Route banner/fix through the anchor (replaces DynamicNotchKit).
            router.setPresenter(anchor)

            let drainer = IPCInboxDrainer(router: router, secret: secret)
            self.drainer = drainer
            await drainer.drain()

            self.fsEventReader = IPCFSEventReader { [weak drainer] in
                Task { @MainActor in await drainer?.drain() }
            }
            self.fsEventReader?.start()

            self.darwinKickSubscription = DarwinNotify.subscribe(KhanIdentifiers.darwinKickName) { [weak drainer] in
                Task { @MainActor in await drainer?.drain() }
            }

            if cloudKitOn {
                self.silentPushHandler = SilentPushHandler(router: router)
                NSApp.registerForRemoteNotifications()
            }

            self.syncTimer = SyncTimer(container: container, interval: 60)
            await self.syncTimer?.start()

            // Avatar's right-click menu calls into these hooks. Sync
            // completion fires a celebration so the cyber girl reacts.
            // Both manual buttons (toolbar + avatar menu) take this path.
            AppCommands.syncNow = { [weak self] in
                Task { @MainActor in
                    await self?.syncTimer?.pokeNow()
                    HeroEvents.shared.celebrate()
                }
            }

            // Voice capture: long-press the configured modifier → mic →
            // route to ChatGPT (or web fallback).
            self.voiceController = VoiceController()
            self.voiceController?.start()

            if cloudKitOn {
                Task.detached {
                    do {
                        try await CloudKitBootstrap.ensureZonesAndSubscriptions()
                    } catch {
                        KhanLog.sync.error("CloudKit bootstrap failed: \(String(describing: error), privacy: .public)")
                    }
                }
            }
        }
    }

    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String: Any]) {
        Task { @MainActor in
            await silentPushHandler?.handleRemoteNotification(userInfo)
        }
    }
}
