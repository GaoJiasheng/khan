import UIKit
import BackgroundTasks
import SwiftData
import KhanCore
import KhanIPC
import UserNotifications

@MainActor
final class KhanAppDelegate: NSObject, UIApplicationDelegate {
    private var router: NotificationRouter?
    private var silentPushHandler: SilentPushHandler?
    private var syncTimer: SyncTimer?
    private var outbox: OutboxPublisher?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        Task { @MainActor in
            try? IPCDirectory.ensureDirectories()
            _ = try? KeychainSecretStore.ensureSecret()

            guard let container = try? ModelContainerFactory.make(useCloudKit: true)
                ?? ModelContainerFactory.make(useCloudKit: false) else {
                return
            }

            let router = NotificationRouter(modelContainer: container)
            self.router = router
            let outbox = OutboxPublisher()
            self.outbox = outbox
            router.setOutbox(outbox)
            router.setPresenter(KhanIOSPresenter())

            self.silentPushHandler = SilentPushHandler(router: router)
            self.syncTimer = SyncTimer(container: container, interval: 60)
            await self.syncTimer?.start()

            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
            application.registerForRemoteNotifications()

            BGTaskScheduler.shared.register(forTaskWithIdentifier: KhanIdentifiers.bgRefreshTaskID, using: nil) { task in
                Task { @MainActor in
                    await self.syncTimer?.pokeNow()
                    task.setTaskCompleted(success: true)
                }
            }

            Task.detached {
                do {
                    try await CloudKitBootstrap.ensureZonesAndSubscriptions()
                } catch {
                    KhanLog.sync.error("bootstrap failed: \(String(describing: error), privacy: .public)")
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
        let request = BGProcessingTaskRequest(identifier: KhanIdentifiers.bgRefreshTaskID)
        request.requiresExternalPower = false
        request.requiresNetworkConnectivity = true
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}

@MainActor
final class KhanIOSPresenter: NotificationPresenter {
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
