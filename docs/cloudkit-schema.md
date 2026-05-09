# doris CloudKit schema

All records live in the **private database** of `iCloud.com.gavin.doris`.

## Custom zones

| Zone           | Contents                                                    |
| -------------- | ----------------------------------------------------------- |
| `NotesZone`    | Folder, Note, ChecklistItem, Tag (synced via SwiftData)     |
| `MessagesZone` | Message + message-scoped Attachment (synced via SwiftData)  |
| `OutboxZone`   | `CK_OutboxItem` records (raw CloudKit)                      |
| `DevicesZone`  | `CK_Device` records (raw CloudKit)                          |

## `CK_OutboxItem`

```
recordType: CK_OutboxItem
recordName: outbox-<originalMessageID>

fields:
  payloadJSON       : Bytes      // IPCNotifyPayload, JSON, sortedKeys, ISO8601
  originDeviceID    : String     // UUID string
  originalMessageID : String     // UUID string
  createdAt         : Date
```

A `CKQuerySubscription` on this record type with `firesOnRecordCreation` and `shouldSendContentAvailable = true` produces the silent-push delivery on receivers.

## `CK_Device`

```
recordType: CK_Device
recordName: device-<deviceUUID>

fields:
  name         : String
  platform     : String   // macOS | iOS | iPadOS
  lastSeenAt   : Date
```

Each device upserts its own record on launch; the Devices tab in the app reads from this zone.

## Notes/Messages via SwiftData

SwiftData with `ModelConfiguration(cloudKitDatabase: .private("iCloud.com.gavin.doris"))` mirrors the `@Model` types into the matching custom zone automatically. The CloudKit dashboard shows them under `CD_<ClassName>` record types.

## Cleanup

The originating device sweeps `CK_OutboxItem` records older than 24 hours via a periodic `CKQueryOperation`. Receivers do not delete; they only consume.
