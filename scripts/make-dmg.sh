#!/usr/bin/env bash
# Packages build/Margin.app into build/Margin.dmg (drag-to-Applications layout).
# Run scripts/bundle-app.sh first.
set -euo pipefail
cd "$(dirname "$0")/.."
APP=build/Margin.app
DMG=build/Margin.dmg
[ -d "$APP" ] || { echo "error: $APP not found; run scripts/bundle-app.sh first" >&2; exit 1; }
STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG"
hdiutil create -volname "Margin" -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
echo "Built $DMG ($(du -h "$DMG" | cut -f1))"
