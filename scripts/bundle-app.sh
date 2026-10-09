#!/usr/bin/env bash
# Builds build/Margin.app from the SwiftPM executable (no Xcode required).
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release --product Margin
BIN="$(swift build -c release --show-bin-path)/Margin"
APP=build/Margin.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/Margin"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Margin</string>
    <key>CFBundleDisplayName</key><string>Margin</string>
    <key>CFBundleIdentifier</key><string>nl.productlabs.margin</string>
    <key>CFBundleExecutable</key><string>Margin</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST
codesign --force --sign - "$APP"
echo "Built $APP"
