# Building and releasing

## Continuous builds

`.github/workflows/build.yml` runs on every push, pull request and tag. It uses an Apple silicon `macos-15` runner and runs these steps:

1. `swift test`: the whole suite must pass. Nothing is published if it fails.
2. `scripts/bundle-app.sh` builds `build/Margin.app` (arm64), with `VERSION` and `BUILD_NUMBER` taken from the tag and run number.
3. If signing secrets are configured, `scripts/notarize.sh sign-app` signs it with Developer ID and the hardened runtime.
4. `scripts/make-dmg.sh` packages `build/Margin.dmg` with a drag-to-Applications layout.
5. If signing secrets are configured, `scripts/notarize.sh notarize-dmg` signs, notarizes and staples the DMG.
6. Publishing:
   - Every build: the DMG is attached to the workflow run as an artifact.
   - Push to `main`: the rolling [`latest`](https://github.com/jonra/margin/releases/tag/latest) pre-release is replaced, so this link always points at the newest passing build: <https://github.com/jonra/margin/releases/download/latest/Margin.dmg>
   - Tag `vX.Y.Z`: a versioned release `Margin vX.Y.Z` is created.

To cut a versioned release:

```bash
git tag v0.2.0
git push origin v0.2.0
```

## Making the DMG open without warnings (notarization)

Without notarization, macOS Gatekeeper blocks the first launch of a downloaded app. Users then have to click **Open Anyway** in System Settings › Privacy & Security. To ship a DMG that opens normally:

1. Join the [Apple Developer Program](https://developer.apple.com/programs/) (paid, yearly).
2. Create a **Developer ID Application** certificate (Xcode › Settings › Accounts › Manage Certificates, or developer.apple.com). Export it from Keychain Access as a `.p12` with a password.
3. Create an [app-specific password](https://support.apple.com/102654) for your Apple ID.
4. Add these repository secrets (GitHub › Settings › Secrets and variables › Actions):

| Secret | Value |
|---|---|
| `MACOS_CERT_P12` | `base64 -i DeveloperID.p12 \| pbcopy`, then paste |
| `MACOS_CERT_PASSWORD` | password of the `.p12` |
| `APPLE_ID` | your Apple ID email |
| `APPLE_TEAM_ID` | your 10-character Team ID |
| `APPLE_APP_PASSWORD` | the app-specific password |

The next build detects the secrets and signs and notarizes automatically. You can also set them from the CLI, for example `gh secret set APPLE_ID`.

## Building a DMG locally

```bash
swift test
./scripts/bundle-app.sh
./scripts/make-dmg.sh      # → build/Margin.dmg (ad-hoc signed)
```
