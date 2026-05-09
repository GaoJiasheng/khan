import Foundation
import DorisIPC
import CloudKit

public final class OutboxPublisher: OutboxPublishing, @unchecked Sendable {
    private let container: CKContainer

    public init(container: CKContainer = CKContainer(identifier: DorisIdentifiers.cloudKitContainer)) {
        self.container = container
    }

    public func publish(_ payload: IPCNotifyPayload, originDeviceID: UUID, originalMessageID: UUID) async throws {
        let recordID = CKRecord.ID(
            recordName: "outbox-\(originalMessageID.uuidString)",
            zoneID: CloudKitZones.outboxZoneID
        )
        let record = CKRecord(recordType: CloudKitZones.recordTypeOutboxItem, recordID: recordID)
        let payloadData = try IPCEncoding.encoder.encode(payload)
        record[OutboxRecordKeys.payloadJSON] = payloadData as NSData
        record[OutboxRecordKeys.originDeviceID] = originDeviceID.uuidString as NSString
        record[OutboxRecordKeys.originalMessageID] = originalMessageID.uuidString as NSString
        record[OutboxRecordKeys.createdAt] = Date() as NSDate

        let db = container.privateCloudDatabase
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let op = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
            op.savePolicy = .changedKeys
            op.qualityOfService = .userInitiated
            op.modifyRecordsResultBlock = { result in
                switch result {
                case .success: cont.resume()
                case .failure(let error): cont.resume(throwing: error)
                }
            }
            db.add(op)
        }
        DorisLog.push.info("outbox publish ok for \(originalMessageID.uuidString, privacy: .public)")
    }

    public func sweepOldRecords(olderThan seconds: TimeInterval = 86_400) async throws {
        let db = container.privateCloudDatabase
        let cutoff = Date().addingTimeInterval(-seconds)
        let predicate = NSPredicate(format: "%K < %@", OutboxRecordKeys.createdAt, cutoff as NSDate)
        let query = CKQuery(recordType: CloudKitZones.recordTypeOutboxItem, predicate: predicate)
        let (matches, _) = try await db.records(matching: query, inZoneWith: CloudKitZones.outboxZoneID)
        let stale = matches.compactMap { _, result -> CKRecord.ID? in
            if case .success(let record) = result { return record.recordID }
            return nil
        }
        guard !stale.isEmpty else { return }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let op = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: stale)
            op.qualityOfService = .utility
            op.modifyRecordsResultBlock = { result in
                switch result {
                case .success: cont.resume()
                case .failure(let error): cont.resume(throwing: error)
                }
            }
            db.add(op)
        }
        DorisLog.push.debug("outbox swept \(stale.count, privacy: .public) stale records")
    }
}
