# khan

A native macOS + iOS notification, notes, and notch helper. Replaces a paid SideNotes-style sidebar with cross-device push, a CLI bridge, and minute-level iCloud sync.

See [plan/v1-design.md](plan/v1-design.md) for the v1 architecture and [docs/](docs/) for module-level docs.

## Repo layout

```
project.yml                  XcodeGen spec — one source of truth for all targets
apps/khan-mac/               macOS app + Share + Widget extensions
apps/khan-ios/               iOS/iPadOS app + Share + Widget extensions
extensions/KhanIntents/      App Intents (Add Note, Push Notification, …)
cli/khan/                    `khan` command-line binary (Swift Package)
packages/KhanCore/           SwiftData models + CloudKit sync (KhanCore product)
                             plus pure-Foundation IPC types (KhanIPC product)
packages/KhanUI/             Shared SwiftUI views
packages/KhanMacChrome/      Mac-only chrome (DynamicNotchKit, NSPanel, HotSide)
scripts/                     Build / project-generation helpers
plan/                        Design docs
```

## Bootstrap (first time)

```bash
# 1. Install Xcode 15+ from the Mac App Store. Command Line Tools alone is not enough —
#    SwiftData macros and SwiftUI #Preview macros need Xcode.
xcode-select -p   # should point at /Applications/Xcode.app/Contents/Developer

# 2. Install XcodeGen.
brew install xcodegen

# 3. Set your Apple Developer team id (used by signing).
export KHAN_TEAM_ID=ABCDE12345

# 4. Generate the Xcode project from project.yml.
./scripts/generate-project.sh

# 5. Open the project, set the team, build the Khan-macOS scheme.
open Khan.xcodeproj
```

## CLI quickstart

After building once, the bundled CLI is at `Khan.app/Contents/Resources/khan` (or `cli/khan/.build/release/khan` for standalone builds). On first launch the app offers to symlink it into your PATH.

```bash
khan notify --title "build done" --body "tests passed" --mode banner
khan notify --title "deploy ok" --mode fix --click-url "https://example.com"
khan notify --all-devices --title "lunch?"
khan note add --title "shopping" --body "milk, bread"
khan inbox dismiss <uuid>
khan sync
khan auth init
khan auth path
```

## Standalone builds without Xcode

`KhanIPC` and the `khan` CLI are pure Swift / Foundation and build with the toolchain shipped via Command Line Tools:

```bash
cd packages/KhanCore && swift build --target KhanIPC
cd cli/khan && swift build
```

Targets that depend on SwiftData (`KhanCore`'s SwiftData product, `KhanUI`, the apps) require Xcode because `@Model` and `#Preview` are external macros not bundled with Command Line Tools.

### Local dev override for the App Group container

When the CLI binary is unsigned (`swift build` debug builds), it cannot resolve the App Group container — `containermanagerd` may block waiting on entitlement checks. Set `KHAN_IPC_ROOT` to a writable directory and the CLI uses that instead:

```bash
export KHAN_IPC_ROOT=/tmp/khan-dev
./cli/khan/.build/debug/khan notify --title "smoke" --no-launch
ls $KHAN_IPC_ROOT/IPC/inbox/
```

Production builds (signed and entitled with the App Group) use the real shared container automatically.

## Architecture at a glance

External script → `khan notify ...` → `<AppGroup>/IPC/inbox/*.json` → `IPCInboxDrainer` → `NotificationRouter` → (a) SwiftData `Message` (synced to CloudKit `MessagesZone`), (b) `DynamicNotchAdapter` for banner/fix display, (c) `OutboxPublisher` for cross-device broadcast. The receiver wakes via `CKQuerySubscription` silent push, fetches the outbox record, and routes it locally.

Full architecture lives in [docs/architecture.md](docs/architecture.md).
