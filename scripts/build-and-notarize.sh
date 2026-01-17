#!/bin/bash
set -e

# === CONFIGURATION ===
APP_NAME="VibeStatus"
SCHEME="VibeStatus"
BUNDLE_ID="com.vibestatus.app"

# === CREDENTIALS ===
APPLE_ID="${APPLE_ID:-kodormit@gmail.com}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-7MKQAN7HM5}"
APPLE_APP_PASSWORD="${APPLE_APP_PASSWORD}"

if [ -z "$APPLE_APP_PASSWORD" ]; then
    echo "Error: Missing APPLE_APP_PASSWORD"
    echo "Run with: APPLE_APP_PASSWORD=xxxx-xxxx-xxxx-xxxx ./scripts/build-and-notarize.sh"
    exit 1
fi

# === PATHS ===
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
APP_PATH="$EXPORT_PATH/$APP_NAME.app"
ZIP_PATH="$BUILD_DIR/$APP_NAME.zip"

# === COLORS ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo_step() { echo -e "${GREEN}==>${NC} $1"; }
echo_error() { echo -e "${RED}Error:${NC} $1"; exit 1; }

# === CLEANUP ===
echo_step "Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# === REGENERATE PROJECT ===
echo_step "Regenerating Xcode project..."
cd "$PROJECT_DIR"
xcodegen generate

# === BUILD ARCHIVE ===
echo_step "Building archive..."
xcodebuild -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  archive

# === EXPORT APP ===
echo_step "Exporting app..."

cat > "$BUILD_DIR/ExportOptions.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>destination</key>
    <string>export</string>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist"

# === VERIFY SIGNATURE ===
echo_step "Verifying code signature..."
codesign --verify --deep --strict "$APP_PATH"
echo "  Signature: OK"
codesign -dv --verbose=2 "$APP_PATH" 2>&1 | grep "Authority"

# === CREATE ZIP FOR NOTARIZATION ===
echo_step "Creating ZIP for notarization..."
cd "$EXPORT_PATH"
zip -r "$ZIP_PATH" "$APP_NAME.app"

# === NOTARIZE ===
echo_step "Submitting for notarization..."
xcrun notarytool submit "$ZIP_PATH" \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$APPLE_APP_PASSWORD" \
  --wait

# === STAPLE ===
echo_step "Stapling notarization ticket..."
xcrun stapler staple "$APP_PATH"

# === VERIFY NOTARIZATION ===
echo_step "Verifying notarization..."
spctl --assess --type execute --verbose "$APP_PATH"

# === RECREATE ZIP WITH STAPLED APP ===
echo_step "Recreating ZIP with stapled app..."
rm "$ZIP_PATH"
zip -r "$ZIP_PATH" "$APP_NAME.app"

# === DONE ===
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  BUILD COMPLETE${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "  App: $APP_PATH"
echo "  ZIP: $ZIP_PATH"
echo ""
echo "  Ready for distribution!"
