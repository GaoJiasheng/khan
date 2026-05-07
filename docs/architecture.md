# khan architecture

This document is the long-form companion to [plan/v1-design.md](../plan/v1-design.md). It summarizes how the pieces fit together for someone reading the codebase fresh.

## Module graph

```
                  ┌─────────────────────────────────────────────┐
                  │                  Khan-macOS                 │
                  │  KhanApp · AppDelegate · Sidebar · Notch    │
                  │  IPCFSEventReader · AppleScript handlers    │
                  └─────────┬─────────────┬─────────────────────┘
                            │             │
       ┌────────────────────▼──────┐  ┌───▼─────────────────────┐
       │       KhanMacChrome       │  │         KhanUI          │
       │  PanelMaker · HotSide     │  │  Note/Inbox/Tag views   │
       │  DynamicNotchAdapter      │  │                         │
       └─────────────┬─────────────┘  └─────────┬───────────────┘
                     │                          │
                     ▼                          ▼
              ┌──────────────────────────────────────────┐
              │                 KhanCore                 │
              │  SwiftData @Model · NotificationRouter   │
              │  Sync (CKZones · OutboxPublisher · …)    │
              └──────────┬───────────────────────────────┘
                         │
                         ▼
                ┌────────────────────┐
                │      KhanIPC       │ ◀───────────── khan CLI
                │  Wire types · HMAC │       (ArgumentParser)
                │  Keychain · Darwin │
                └────────────────────┘
```

`KhanIPC` is intentionally pure Foundation + CryptoKit — no SwiftData, no UI — so the CLI, share extensions, intents, and tests can build it standalone.

## Lifecycle

1. `KhanAppDelegate.applicationDidFinishLaunching` sets up the SwiftData container, ensures the App Group keychain secret, and wires the router.
2. The router's input fans in from three sources:
   - `IPCInboxDrainer` (file-drop queue from CLI / share extensions)
   - `IPCFSEventReader` + `DarwinNotify` (low-latency wake from external writes)
   - `SilentPushHandler` (cross-device CloudKit notifications)
3. Output fans out to:
   - SwiftData (always: every notification is also persisted as a `Message`)
   - `KhanPresenter` (banner via `DynamicNotchAdapter`, fix-mode via custom notch panel)
   - `OutboxPublisher` (when broadcast is `allDevices` or `device(...)`)

## Cross-device push

```
device A: khan notify --all-devices ...
   → IPCWriter file in App Group inbox
   → Router (persists Message + outbox publish)
   → CloudKit OutboxZone CKRecord write

device B: APNs silent push
   → SilentPushHandler.handleRemoteNotification
   → fetch CKRecord
   → re-route through NotificationRouter (broadcast=.local on receiver to prevent loops)
```

Origin device dedup uses `originDeviceId` on the outbox record; receivers ignore their own broadcasts.

## File / disk layout (App Group)

```
~/Library/Group Containers/group.com.gavin.khan.shared/
├── IPC/
│   ├── inbox/          ← CLI / extension drops
│   ├── outbox/         ← app → CLI replies (e.g. inbox tail)
│   └── processed/      ← archived requests, .ok / .error / .rejected suffix
├── Attachments/        ← <uuid>.<ext> binary blobs
├── Backups/<yyyymmdd>/ ← snapshot copies of the SwiftData store
├── Logs/khan-debug.log ← (future) rotating log
└── Store/              ← SwiftData SQLite + journal + CK metadata
```

## Why the unusual pieces

- **Two libraries (`KhanIPC` + `KhanCore`) inside one Swift Package**: the CLI must build without SwiftData macros (which require Xcode). Splitting keeps everything compilable from `swift build` for the parts that don't touch SwiftData.
- **File-drop IPC instead of XPC or loopback HTTP**: works whether the app is running, requires no extra entitlement (`network.server`), and the team-scoped App Group container provides authentication on top of HMAC.
- **Raw CloudKit for the Outbox, SwiftData+CloudKit for everything else**: SwiftData's auto-sync is great for ambient data, but cross-device push needs immediate-fire silent-push subscriptions on a known record type, which is easier with raw `CKModifyRecordsOperation`.
