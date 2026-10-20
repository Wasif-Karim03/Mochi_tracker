#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
APP="dist/Typing Companion.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/TypingCompanion" "$APP/Contents/MacOS/TypingCompanion"
cp -R "$BIN_DIR/TypingCompanion_TypingCompanion.bundle" "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>local.wasif.typingcompanion</string>
<key>CFBundleName</key><string>Typing Companion</string>
<key>CFBundleDisplayName</key><string>Typing Companion</string>
<key>CFBundleExecutable</key><string>TypingCompanion</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.4.1</string>
<key>CFBundleVersion</key><string>6</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSInputMonitoringUsageDescription</key><string>Match your key positions to the companion's paws and count presses. Typed text and key positions are never recorded.</string>
</dict></plist>
PLIST
codesign --force --sign "${SIGNING_IDENTITY:--}" --timestamp=none --identifier local.wasif.typingcompanion "$APP"
codesign --verify --deep --strict "$APP"
echo "Built $APP"
