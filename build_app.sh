#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "🔨 正在編譯 MacTranslator (Release)..."

APP_NAME="MacTranslator"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}" /tmp/swift-module-cache

swiftc -O \
    -module-cache-path /tmp/swift-module-cache \
    -target arm64-apple-macosx13.0 \
    -framework AppKit \
    -framework SwiftUI \
    -framework Carbon \
    -framework Vision \
    -framework AVFoundation \
    Sources/MacTranslator/*.swift \
    -o "${MACOS_DIR}/${APP_NAME}_arm64"

swiftc -O \
    -module-cache-path /tmp/swift-module-cache \
    -target x86_64-apple-macosx13.0 \
    -framework AppKit \
    -framework SwiftUI \
    -framework Carbon \
    -framework Vision \
    -framework AVFoundation \
    Sources/MacTranslator/*.swift \
    -o "${MACOS_DIR}/${APP_NAME}_x86_64"

lipo -create -output "${MACOS_DIR}/${APP_NAME}" \
    "${MACOS_DIR}/${APP_NAME}_arm64" \
    "${MACOS_DIR}/${APP_NAME}_x86_64"

rm -f "${MACOS_DIR}/${APP_NAME}_arm64" "${MACOS_DIR}/${APP_NAME}_x86_64"
chmod +x "${MACOS_DIR}/${APP_NAME}"

cat > "${CONTENTS_DIR}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_TW</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.mactranslator.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>MacTranslator</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Ad-hoc 簽章讓 macOS 本機執行更順暢
codesign --force --deep --sign - "${APP_BUNDLE}" 2>/dev/null || true

echo "✅ 已成功打包：$(pwd)/${APP_BUNDLE}"

# 建立 DMG 磁碟映像檔（內含 MacTranslator.app 與 Applications 捷徑）
DMG_NAME="${APP_NAME}.dmg"
DMG_STAGING="/tmp/${APP_NAME}_dmg_staging"
rm -rf "${DMG_STAGING}" "${DMG_NAME}"
mkdir -p "${DMG_STAGING}"
cp -R "${APP_BUNDLE}" "${DMG_STAGING}/"
ln -s /Applications "${DMG_STAGING}/Applications"

if hdiutil create -volname "${APP_NAME}" -srcfolder "${DMG_STAGING}" -ov -format UDZO "${DMG_NAME}" >/dev/null 2>&1; then
    echo "💿 已成功建立磁碟映像檔：$(pwd)/${DMG_NAME}"
fi
rm -rf "${DMG_STAGING}"
