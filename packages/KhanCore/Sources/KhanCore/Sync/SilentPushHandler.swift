import Foundation
import KhanIPC
import CloudKit

@MainActor
public final class SilentPushHandler {
    private let router: NotificationRouter
    private let container: CKContainer
    private let dedup: DedupCache

    public init(
        router: NotificationRouter,
        container: CKContainer = CKContainer(identifier: KhanIdentifiers.cloudKitContainer),
        dedup: DedupCache = DedupCache()
    ) {
        self.router = router
        self.container = container
        self.dedup = dedup
    }

    /// Process a CloudKit-delivered remote notification dictionary. Returns true if the
    /// payload was a recognised CloudKit notification and was processed.
    @discardableResult
    public func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) async -> Bool {
        guard let ckInfo = userInfo as? [String: NSObject],
              let notification = CKNotification(fromRemoteNotificationDictionary: ckInfo)
        else {
            return false
        }
        guard let queryNotification = notification as? CKQueryNotification else {
            return false
        }
        guard let recordID = queryNotification.recordID else { return false }
        do {
            let record = try await container.privateCloudDatabase.record(for: recordID)
            try await ingest(record)
        } catch {
            KhanLog.push.error("silent push fetch failed: \(String(describing: error), privacy: .public)")
        }
        return true
    }

    public func drainOutbox() async throws {
        let db = container.privateCloudDatabase
        let query = CKQuery(recordType: CloudKitZones.recordTypeOutboxItem, predicate: NSPredicate(value: true))
        let (matches, _) = try await db.records(matching: query, inZoneWith: CloudKitZones.outboxZoneID)
        for (_, result) in matches {
            if case .success(let record) = result {
                try? await ingest(record)
            }
        }
    }

    private func ingest(_ record: CKRecord) async throws {
        guard let originString = record[OutboxRecordKeys.originDeviceID] as? String,
              let originUUID = UUID(uuidString: originString),
              let originalIDString = record[OutboxRecordKeys.originalMessageID] as? String,
              let originalID = UUID(uuidString: originalIDString),
              let payloadData = record[OutboxRecordKeys.payloadJSON] as? Data
        else {
            KhanLog.push.error("malformed outbox record \(record.recordID.recordName, privacy: .public)")
            return
        }
        if originUUID == DeviceIdentity.current() {
            // own broadcast echoed back - ignore
            return
        }
        guard await dedup.record(originalID) else { return }

        var payload = try IPCEncoding.decoder.decode(IPCNotifyPayload.self, from: payloadData)
        // do not re-broadcast on the receiver
        payload.broadcast = .local

        let request = IPCRequest(id: originalID, kind: .notify, payload: .notify(payload))
        await router.handle(request)
    }
}
