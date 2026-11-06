#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
DEST="${1:-../键盘小憩.app}"
mkdir -p "$DEST/Contents/MacOS" "$DEST/Contents/Resources"
ICON_WORK="$(mktemp -d)"
trap 'rm -rf "$ICON_WORK"' EXIT
xcrun swift MakeIcon.swift "$ICON_WORK/AppIcon.iconset"
cp "$ICON_WORK/AppIcon.iconset/icon_512x512@2x.png" ../键盘小憩-Logo.png
iconutil -c icns "$ICON_WORK/AppIcon.iconset" -o "$DEST/Contents/Resources/KeyboardPauseIcon.icns"
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx13.0 -framework AppKit -framework ApplicationServices LockPolicy.swift KeyboardView.swift main.swift -o "$DEST/Contents/MacOS/KeyboardPause"
cat > "$DEST/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>KeyboardPause</string>
<key>CFBundleIdentifier</key><string>local.keyboardpause.app</string>
<key>CFBundleName</key><string>键盘小憩</string>
<key>CFBundleDisplayName</key><string>键盘小憩</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleIconFile</key><string>KeyboardPauseIcon.icns</string>
<key>CFBundleShortVersionString</key><string>1.2.1</string>
<key>CFBundleVersion</key><string>6</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
codesign --force --sign - "$DEST"
codesign --verify --strict "$DEST"
echo "Built: $DEST"
