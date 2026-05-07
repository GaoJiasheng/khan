import Foundation
import KhanIPC
import CloudKit

public enum CloudKitBootstrap {
    public static let outboxSubscriptionID = "khan-outbox-sub-v1"

    public static func ensureZonesAndSubscriptions() async throws {
        let container = CKContainer(identifier: KhanIdentifiers.cloudKitContainer)
        let db = container.privateCloudDatabase

        // 1. Ensure custom zones
        let zoneOp = CKModifyRecordZonesOperation(
            recordZonesToSave: CloudKitZones.customZones,
            recordZoneIDsToDelete: nil
        )
        zoneOp.qualityOfService = .userInitiated
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            zoneOp.modifyRecordZonesResultBlock = { result in
                switch result {
                case .success: cont.resume()
                case .failure(let error):
                    if let ckError = error as? CKError, ckError.code == .partialFailure {
                        cont.resume()
                    } else {
                        cont.resume(throwing: error)
                    }
                }
            }
            db.add(zoneOp)
        }

        // 2. Ensure subscription on outbox
        let subscription = CKQuerySubscription(
            recordType: CloudKitZones.recordTypeOutboxItem,
            predicate: NSPredicate(value: true),
            subscriptionID: outboxSubscriptionID,
            options: [.firesOnRecordCreation]
        )
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true     // silent push
        info.shouldBadge = false
        info.alertBody = nil
        subscription.notificationInfo = info

        let subOp = CKModifySubscriptionsOperation(
            subscriptionsToSave: [subscription],
            subscriptionIDsToDelete: nil
        )
        subOp.qualityOfService = .userInitiated
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            subOp.modifySubscriptionsResultBlock = { result in
                switch result {
                case .success: cont.resume()
                case .failure(let error):
                    if let ckError = error as? CKError,
                       ckError.code == .serverRejectedRequest || ckError.code == .partialFailure {
                        // Subscription likely already exists.
                        cont.resume()
                    } else {
                        cont.resume(throwing: error)
                    }
                }
            }
            db.add(subOp)
        }

        KhanLog.sync.info("CloudKit zones + outbox subscription ensured")
    }
}
