#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="Tonica"
SCHEME="Tonica"
PROJECT="Tonica.xcodeproj"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/.derived_ci}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
TEAM_ID="${APPLE_TEAM_ID:-XSBK4ZK282}"
SIGN_IDENTITY="${APPLE_DEVELOPER_ID_APPLICATION_IDENTITY:-Developer ID Application: Artur Karapetyan (XSBK4ZK282)}"

ARCHIVE_PATH="$DIST_DIR/${APP_NAME}.xcarchive"
EXPORT_PATH="$DIST_DIR/export"
XCRESULT_PATH="$DIST_DIR/${APP_NAME}Archive.xcresult"
APP_PATH="$EXPORT_PATH/${APP_NAME}.app"
DMG_PATH="$DIST_DIR/${APP_NAME}.dmg"
NOTARIZE_ZIP="$DIST_DIR/${APP_NAME}-notarize.zip"

[[ "$SIGN_IDENTITY" == "Developer ID Application:"* ]] || { echo "Developer ID required" >&2; exit 1; }
export APPLE_NOTARY_KEYCHAIN_PROFILE="${APPLE_NOTARY_KEYCHAIN_PROFILE:-fowl-notary}"
xcrun notarytool history --keychain-profile "$APPLE_NOTARY_KEYCHAIN_PROFILE" >/dev/null
mkdir -p "$DIST_DIR"
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH" "$XCRESULT_PATH" "$NOTARIZE_ZIP"

xcodegen generate

xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -resultBundlePath "$XCRESULT_PATH" \
  ARCHS="arm64 x86_64" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  ENABLE_HARDENED_RUNTIME=YES \
  OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime"

cat > "$DIST_DIR/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>${SIGN_IDENTITY}</string>
    <key>stripSwiftSymbols</key>
    <true/>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$DIST_DIR/ExportOptions.plist"

test -f "$APP_PATH/Contents/MacOS/$APP_NAME"
chmod +x "$ROOT_DIR/scripts/ensure_app_icon.sh"
"$ROOT_DIR/scripts/ensure_app_icon.sh" "$APP_PATH"
codesign --force --sign "$SIGN_IDENTITY" --timestamp --options runtime \
  --preserve-metadata=entitlements "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

if [[ -n "${APPLE_NOTARY_KEYCHAIN_PROFILE:-}" || -n "${APPLE_NOTARY_API_KEY_PATH:-}" || -n "${APPLE_ID:-}" ]]; then
  ditto -c -k --keepParent "$APP_PATH" "$NOTARIZE_ZIP"
  "$ROOT_DIR/scripts/notarize_archive.sh" "$NOTARIZE_ZIP"
  xcrun stapler staple "$APP_PATH"
  xcrun stapler validate "$APP_PATH"
  spctl --assess --type exec -vv "$APP_PATH"
fi

CI=1 "$ROOT_DIR/scripts/build_dmg.sh" "$APP_PATH" "$DMG_PATH" "$APP_NAME"
codesign --force --sign "$SIGN_IDENTITY" --timestamp --verbose=2 "$DMG_PATH"
codesign --verify --verbose=2 "$DMG_PATH"

if [[ -n "${APPLE_NOTARY_KEYCHAIN_PROFILE:-}" || -n "${APPLE_NOTARY_API_KEY_PATH:-}" || -n "${APPLE_ID:-}" ]]; then
  "$ROOT_DIR/scripts/notarize_archive.sh" "$DMG_PATH"
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
  spctl --assess --type open --context context:primary-signature -vv "$DMG_PATH"
fi

echo "Release artifacts:"
echo "  app: $APP_PATH"
echo "  dmg: $DMG_PATH"
