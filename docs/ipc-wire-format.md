# doris IPC wire format

Files dropped into `<AppGroup>/IPC/inbox/` are JSON-encoded `IPCRequest` envelopes.

## Filename

```
<unix-ms>-<uuid>.json
```

The unix-ms prefix makes lexicographic sort match arrival order; the UUID is the request id used for dedup.

## Envelope

```json
{
  "v": 1,
  "id": "AB72D9...uuid",
  "kind": "notify",
  "payload": { ... },
  "hmac": "0a1b2c... hex"
}
```

- `v` — schema version, currently `1`.
- `id` — UUID, used by the router for dedup (across both local and cross-device echoes).
- `kind` — one of `notify`, `noteAdd`, `inboxList`, `inboxDismiss`, `inboxDone`, `sync`, `ping`.
- `payload` — discriminated union; see types below.
- `hmac` — lowercase-hex HMAC-SHA256 over canonical JSON (sorted keys) of the envelope **with `hmac` set to `null`**, keyed by the App Group keychain secret.

## Canonical encoding

```swift
let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]
encoder.dateEncodingStrategy = .iso8601
```

## Payload — `notify`

```json
{
  "title": "build done",
  "body": "tests passed",
  "iconName": "checkmark.seal",
  "displayMode": "banner",
  "source": "claudeCode",
  "sourceAppId": "claude-code",
  "clickAction": { "kind": "openURL", "url": "https://..." },
  "broadcast": { "kind": "local" }
}
```

`broadcast.kind` ∈ `local` | `allDevices` | `device` (with `deviceID`).
`clickAction.kind` ∈ `openURL` | `openNote` | `runIntent` | `markDone`.

## Payload — `noteAdd`

```json
{
  "title": "shopping",
  "body": "milk\nbread",
  "folderName": "Personal",
  "tags": ["chores"]
}
```

## Payload — `inboxList`

```json
{
  "source": "claudeCode",
  "sinceSeconds": 3600,
  "unreadOnly": true,
  "limit": 20,
  "follow": false
}
```

## Payload — `inboxDismiss` / `inboxDone`

```json
{ "id": "AB72D9...uuid" }
```

## Payload — `sync` / `ping`

Empty bodies; the kind alone is the request.
