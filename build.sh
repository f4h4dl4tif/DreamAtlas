#!/bin/zsh
# Builds DreamAtlas.app (Apple Silicon, macOS 14+) into build/.
# Needs Xcode installed (the macOS 27 SDK implements SwiftUI's @State as a macro, which ships with Xcode only).
set -e
if [[ -z "$DEVELOPER_DIR" && -d /Applications/Xcode.app ]]; then export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer; fi
cd "$(dirname "$0")"
APP=build/DreamAtlas.app
VERSION=1.1
rm -rf "$APP" build/DreamAtlas.iconset
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

xcrun swiftc -O -swift-version 5 -parse-as-library -target arm64-apple-macos14.0 Sources/*.swift -o "$APP/Contents/MacOS/DreamAtlas"

swift Tools/make_icon.swift build/DreamAtlas.iconset
iconutil -c icns build/DreamAtlas.iconset -o "$APP/Contents/Resources/DreamAtlas.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>DreamAtlas</string>
  <key>CFBundleDisplayName</key><string>DreamAtlas</string>
  <key>CFBundleIdentifier</key><string>app.dreamatlas.mac</string>
  <key>CFBundleExecutable</key><string>DreamAtlas</string>
  <key>CFBundleIconFile</key><string>DreamAtlas</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>2</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.lifestyle</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>DreamAtlas — a private dream journal</string>
</dict></plist>
PLIST

codesign --force --deep --sign - "$APP"
echo "Built $APP"
