# Releasing Doris for Mac

Ship a signed + notarized DMG with one command. `scripts/release.sh` does
the whole archive → notarize → staple → DMG pipeline; the rest of this
document is the one-time setup you need to do before that script works.

## One-time setup

### 1. Apple Developer Program enrollment

Already done if you can sign into <https://developer.apple.com/account>
and see a Team ID under "Membership details."

### 2. Install the Developer ID Application certificate

Xcode → Settings → Accounts → your Apple ID → click your team → Manage
Certificates → `+` → **Developer ID Application**. Verify:

```bash
security find-identity -v -p codesigning | grep "Developer ID Application"
```

…should print one line like
`Developer ID Application: <Your Name> (TEAMID1234)`.

### 3. Store notarization credentials in the keychain

Generate an App-Specific Password at
<https://appleid.apple.com> → Sign-In and Security → App-Specific
Passwords → `Generate an app-specific password`. Then run **once**:

```bash
xcrun notarytool store-credentials doris-notary \
  --apple-id   <your-apple-id-email> \
  --team-id    <YOUR_TEAM_ID> \
  --password   <19-char-app-specific-password>
```

This drops the credentials into your login keychain under the profile
name `doris-notary`. `release.sh` references that profile, so your real
password is never on disk in plain text and never appears on the command
line during a release.

To rotate later: regenerate the app-specific password on appleid.apple.com
(old one auto-invalidates) and re-run `store-credentials`.

### 4. Install `create-dmg`

```bash
brew install create-dmg
```

### 5. Register Bundle IDs + iCloud Container in the Developer Portal

In <https://developer.apple.com/account/resources/identifiers/list>:

| Type | Identifier | Capabilities needed |
|---|---|---|
| App ID | `com.gavin.doris` | iCloud (CloudKit), Push Notifications, App Groups |
| App ID | `com.gavin.doris.share-mac` | App Groups |
| App ID | `com.gavin.doris.widget-mac` | iCloud (CloudKit), App Groups |
| App ID | `com.gavin.doris.intents-mac` | App Groups |
| App ID | `com.gavin.doris.doris-cli` | App Groups |
| iCloud Container | `iCloud.com.gavin.doris` | (n/a) |
| App Group | `group.com.gavin.doris.shared` | (n/a) |

Bundle IDs that aren't registered yet are usually auto-created by Xcode
during the first archive with automatic signing — but pre-creating them
avoids surprises.

### 6. Deploy the CloudKit schema to Production (one-time, after first signed run)

After your first successful Release build creates record types in the
Development environment, go to <https://icloud.developer.apple.com/dashboard>
→ your container → Schema → **Deploy Schema to Production**. Without
this, users running the shipped build can't read/write because Apple's
Production CloudKit is empty until you push.

You only do this once per major schema change.

## Cutting a release

Every release after the one-time setup is one command:

```bash
export DORIS_TEAM_ID=<YOUR_TEAM_ID>
./scripts/release.sh
```

The script will:

1. **Archive** the Doris-macOS scheme in Release configuration with your
   Developer ID. Embeds + signs the bundled `doris` CLI inside
   `Doris.app/Contents/Resources/`.
2. **Export** the signed `.app` from the archive using
   `scripts/ExportOptions.plist` (method=developer-id).
3. **Verify** that the embedded CLI is Developer ID + hardened-runtime
   signed (fails the build if either is missing — would otherwise blow up
   in notarization).
4. **Notarize** the `.app` via Apple's notary service. Takes 5–15 minutes
   for the service to respond.
5. **Staple** the notarization ticket onto the `.app`.
6. **Build** the DMG with `create-dmg` — drag-to-Applications layout.
7. **Notarize + staple** the DMG itself (required for offline first-launch
   without a Gatekeeper spinner).
8. **Validate** the ticket and run a `spctl` assessment as a sanity check.

Output lands at `build/release-<version>/Doris-<version>.dmg`. That's the
file you upload to a download page or GitHub Releases.

## Versioning

`MARKETING_VERSION` in `project.yml` (under `Doris-macOS` target settings)
is the single source of truth. Bump it before running a release. The
script reads that value to name the build folder and DMG.

## Troubleshooting

### "No Developer ID Application cert found"

You're missing step 2. Re-run `security find-identity -v -p codesigning`
to confirm. If still empty, the cert may have been revoked or is in a
different keychain — try Xcode Settings → Accounts → Download Manual
Profiles.

### Notary submission rejected

`xcrun notarytool log <submission-id> --keychain-profile doris-notary`
fetches the JSON log. Most common issues:

- An embedded binary missing `--options runtime` (hardened runtime).
  Confirm step 3 of `release.sh`'s preflight pass.
- An embedded binary signed by the wrong team. All nested binaries must
  carry the same team identifier.
- Missing `--timestamp` on an embedded binary signature. (The CLI target
  in `project.yml` sets this explicitly.)

### "Gatekeeper still warns about unidentified developer"

The DMG isn't stapled — check `xcrun stapler validate <path>`. If the
.app inside isn't stapled either, Gatekeeper falls back to per-file
assessment.

### First-launch CloudKit failures on the shipped build

Confirm step 6 (schema deploy to Production). The shipped build's logs
will say "CloudKit Production schema not yet deployed" or similar in
Console.app.

### CI / GitHub Actions

Not wired up yet. The local script is the only path for now. When CI
matters, the keychain profile pattern doesn't translate cleanly — you'll
want to pass the app-specific password as a secret env var to a fresh
`notarytool store-credentials` call inside the runner.
