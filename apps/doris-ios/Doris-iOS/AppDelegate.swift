import UIKit
import BackgroundTasks
import SwiftData
import DorisCore
import DorisIPC
import UserNotifications

@MainActor
final class DorisAppDelegate: NSObject, UIApplicationDelegate {
    private var router: NotificationRouter?
    private var silentPushHandler: SilentPushHandler?
    private var syncTimer: SyncTimer?
    private var outbox: OutboxPublisher?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // BGTaskScheduler must be registered synchronously on the main thread
        // during launch — UIKit will hard-crash if we register inside a
        // detached Task. Hook it up before doing async setup work.
        BGTaskScheduler.shared.register(forTaskWithIdentifier: DorisIdentifiers.bgRefreshTaskID, using: nil) { [weak self] task in
            Task { @MainActor in
                await self?.syncTimer?.pokeNow()
                task.setTaskCompleted(success: true)
            }
        }

        Task { @MainActor in
            try? IPCDirectory.ensureDirectories()
            _ = try? KeychainSecretStore.ensureSecret()

            // Single shared container (see DorisRuntime). Same backing store
            // as the SwiftUI scene, so anything written from a silent push
            // handler shows up in the foreground UI immediately.
            let container = DorisRuntime.shared.container
            let cloudKitOn = SyncSettings.shared.cloudKitEnabled

            let router = NotificationRouter(modelContainer: container)
            self.router = router
            if cloudKitOn {
                let outbox = OutboxPublisher()
                self.outbox = outbox
                router.setOutbox(outbox)
            }
            router.setPresenter(DorisIOSPresenter())

            self.silentPushHandler = SilentPushHandler(router: router)
            self.syncTimer = SyncTimer(container: container, interval: 60)
            await self.syncTimer?.start()

            // Wire the manual "Sync Now" hook so the iOS Settings button
            // and the future widget Intent both reach the same actor.
            AppCommands.syncNow = { [weak self] in
                Task { @MainActor in
                    await self?.syncTimer?.pokeNow()
                }
            }

            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
            application.registerForRemoteNotifications()

            if cloudKitOn {
                Task.detached {
                    do {
                        try await CloudKitBootstrap.ensureZonesAndSubscriptions()
                    } catch {
                        DorisLog.sync.error("bootstrap failed: \(String(describing: error), privacy: .public)")
                    }
                }
            }
        }
        return true
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        guard let handler = silentPushHandler else { return .noData }
        let handled = await handler.handleRemoteNotification(userInfo)
        return handled ? .newData : .noData
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        scheduleNextRefresh()
    }

    private func scheduleNextRefresh() {
        let request = BGProcessingTaskRequest(identifier: DorisIdentifiers.bgRefreshTaskID)
        request.requiresExternalPower = false
        request.requiresNetworkConnectivity = true
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}

@MainActor
final class DorisIOSPresenter: NotificationPresenter {
    nonisolated func presentBanner(_ message: PresentableMessage) {
        // On iOS, when app is foregrounded the inbox UI updates via SwiftData query.
        // When backgrounded, silent push triggers a UN notification fallback.
        Task { @MainActor in
            let content = UNMutableNotificationContent()
            content.title = message.title
            if let body = message.body { content.body = body }
            content.sound = .default
            let request = UNNotificationRequest(identifier: message.id.uuidString, content: content, trigger: nil)
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    nonisolated func presentFix(_ message: PresentableMessage) {
        // Fix mode on iOS = same as banner with no auto-dismiss expectation; the inbox carries it.
        presentBanner(message)
    }

    nonisolated func dismiss(messageID: UUID) {
        Task { @MainActor in
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [messageID.uuidString])
        }
    }
}
