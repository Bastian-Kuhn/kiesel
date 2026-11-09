#!/bin/sh
# Builds build/Kiesel.app (release, with icon). Usage: tools/build-app.sh
set -eu
cd "$(dirname "$0")/.."

swift build -c release --product Kiesel
BIN="$(swift build -c release --show-bin-path)"
APP=build/Kiesel.app

rm -rf "$APP" build/AppIcon.iconset
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/AppIcon.iconset

cp "$BIN/Kiesel" "$APP/Contents/MacOS/Kiesel"
cp -R "$BIN/Kiesel_KieselApp.bundle" "$APP/Contents/Resources/"

ICON=Sources/KieselApp/Resources/AppIcon.png
for s in 16 32 128 256 512; do
  sips -z $s $s "$ICON" --out "build/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
  sips -z $((s * 2)) $((s * 2)) "$ICON" --out "build/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Kiesel</string>
  <key>CFBundleDisplayName</key><string>Kiesel</string>
  <key>CFBundleIdentifier</key><string>de.bastian-kuhn.kiesel</string>
  <key>CFBundleExecutable</key><string>Kiesel</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleDevelopmentRegion</key><string>de</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "built $APP"
