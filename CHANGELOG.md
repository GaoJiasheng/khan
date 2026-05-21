# Doris — Changelog

Versions follow [semver](https://semver.org). `MARKETING_VERSION` in
`project.yml` is the single source of truth; bump it before running
`scripts/release.sh` to cut a release.

---

## 0.2.0 — 2026-05-21

First Developer-ID-signed + notarized release. Ready for distribution
via DMG download.

### Added

- **App integrations** (Settings → 应用集成): pluggable
  `IntegrationProvider` framework so Claude Code / Codex / ChatGPT
  task-completion notifications route through Doris instead of macOS
  Notification Center.
  - Claude Code: full automatic registration via
    `~/.claude/settings.json` Stop hook.
  - Codex / ChatGPT: `.manual` tier with tutorial links until those
    tools expose hook APIs.
- **`doris://notify` URL scheme** for triggering banners from
  `open doris://notify?title=...&source=...&click=...`. Useful for
  Shortcuts / web bookmarklets.
- **CLI man page** at `docs/cli-manual.md`, also bundled as PDF in
  the shipped DMG.
- **Doris CLI embedded inside Doris.app** at
  `Contents/Resources/doris`, signed with the team's Developer ID +
  hardened runtime + cli.entitlements (App Group only, no sandbox).
- **TODO row due-date chip** replaces the modified-at relative time;
  smart labels (今天 / 明天 / 周X / 5月20日), color-coded by urgency,
  click-to-open date picker.
- **Today tab** on mac main window + dropdown popup, mirroring iOS.
  Shared `TodayPinnedCard` / `TodayCalendarRow` across all three
  surfaces.

### Changed

- **Banner cards halved** in height (84pt → 42pt for auto-dismiss,
  108pt → 54pt for fix-mode), corner radius 22 → 10 (overall
  rectangular shape, lightly rounded).
- **Click-to-open** on a banner now opens the source app via its URL
  scheme (`claude://`, `chatgpt://`, etc.) using
  `NSWorkspace.OpenConfiguration.activates = true` — previously
  collapsed Doris's own dropdown instead.
- **Default integration level** raised from `info` (1.5s) to
  `reminder` (4s + orange progress bar) — info disappeared before
  the user could react to "task done".
- **Today tab section colors swapped**: pinned now pink (warm /
  attention), upcoming now cyan (calmer / scheduled).
- **Localization pass**: every Settings tab item, label, button, and
  toggle now flips between English and 中文 via the shared `L()`
  helper.
- **Hook command bug fix**: was emitting `--click` (unknown to the
  CLI), now `--click-url` — Claude Stop hooks were silently exiting
  64 every session before the fix.

### Internal

- Release pipeline: `scripts/release.sh` builds, signs, notarizes,
  and packages the DMG end-to-end via App Store Connect API key
  (`~/.appstoreconnect/private_keys/AuthKey_*.p8`).
- Provisioning: 5 bundle IDs auto-managed via
  `-allowProvisioningUpdates` with the team's Mac device registered
  for the Apple Development cert path.
- `docs/release.md` walks through the one-time signing setup.

---

## 0.1.0 — Initial pre-release

Foundation: SwiftData store, anchor + dropdown UI, IPC inbox/outbox,
CLI scaffold, CloudKit sync (when properly signed), iOS app, share
extension, widget, App Intents.
