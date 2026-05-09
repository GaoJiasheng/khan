import Foundation
import DorisIPC
import CloudKit

public enum CloudKitZones {
    public static let recordTypeOutboxItem = "CK_OutboxItem"
    public static let recordTypeDevice = "CK_Device"

    public static var notesZoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: DorisZones.notes, ownerName: CKCurrentUserDefaultName)
    }

    public static var messagesZoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: DorisZones.messages, ownerName: CKCurrentUserDefaultName)
    }

    public static var outboxZoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: DorisZones.outbox, ownerName: CKCurrentUserDefaultName)
    }

    public static var devicesZoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: DorisZones.devices, ownerName: CKCurrentUserDefaultName)
    }

    public static var customZones: [CKRecordZone] {
        [
            CKRecordZone(zoneID: notesZoneID),
            CKRecordZone(zoneID: messagesZoneID),
            CKRecordZone(zoneID: outboxZoneID),
            CKRecordZone(zoneID: devicesZoneID)
        ]
    }
}

public enum OutboxRecordKeys {
    public static let payloadJSON = "payloadJSON"
    public static let originDeviceID = "originDeviceID"
    public static let originalMessageID = "originalMessageID"
    public static let createdAt = "createdAt"
}
