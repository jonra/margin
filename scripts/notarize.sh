#!/usr/bin/env bash
# Developer ID signing + notarization, used by CI when signing secrets are configured.
#   scripts/notarize.sh sign-app      sign build/Margin.app (hardened runtime)
#   scripts/notarize.sh notarize-dmg  sign, notarize and staple build/Margin.dmg
# Required environment (see docs/RELEASING.md):
#   MACOS_CERT_P12        base64 of a "Developer ID Application" certificate exported as .p12
#   MACOS_CERT_PASSWORD   password of that .p12
#   APPLE_ID, APPLE_TEAM_ID, APPLE_APP_PASSWORD (app-specific password) for notarytool
set -euo pipefail
cd "$(dirname "$0")/.."
WORK="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
KEYCHAIN="$WORK/margin-signing.keychain-db"
IDENTITY_FILE="build/.signing-identity"

case "${1:-}" in
  sign-app)
    KEYCHAIN_PASSWORD=$(uuidgen)
    security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
    security set-keychain-settings -lut 21600 "$KEYCHAIN"
    security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
    printf '%s' "$MACOS_CERT_P12" | base64 --decode > "$WORK/margin-cert.p12"
    security import "$WORK/margin-cert.p12" -k "$KEYCHAIN" -P "$MACOS_CERT_PASSWORD" -T /usr/bin/codesign
    rm -f "$WORK/margin-cert.p12"
    security set-key-partition-list -S apple-tool:,apple: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null
    # shellcheck disable=SC2046
    security list-keychains -d user -s "$KEYCHAIN" $(security list-keychains -d user | tr -d '"')
    IDENTITY=$(security find-identity -v -p codesigning "$KEYCHAIN" | awk -F'"' '/Developer ID Application/ { print $2; exit }')
    [ -n "$IDENTITY" ] || { echo "error: no 'Developer ID Application' identity in the certificate" >&2; exit 1; }
    codesign --force --options runtime --timestamp --sign "$IDENTITY" build/Margin.app
    codesign --verify --strict --verbose=2 build/Margin.app
    printf '%s' "$IDENTITY" > "$IDENTITY_FILE"
    echo "Signed build/Margin.app with: $IDENTITY"
    ;;
  notarize-dmg)
    IDENTITY=$(cat "$IDENTITY_FILE")
    codesign --force --timestamp --sign "$IDENTITY" build/Margin.dmg
    xcrun notarytool submit build/Margin.dmg \
      --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_PASSWORD" --wait
    xcrun stapler staple build/Margin.dmg
    spctl --assess --type open --context context:primary-signature --verbose build/Margin.dmg
    echo "Notarized and stapled build/Margin.dmg"
    ;;
  *)
    echo "usage: $0 sign-app | notarize-dmg" >&2
    exit 2
    ;;
esac
