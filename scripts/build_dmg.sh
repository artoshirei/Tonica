#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RENDER_BG_SCRIPT="$ROOT_DIR/scripts/render_dmg_background.swift"

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <app_path> <output_dmg_path> [volume_name]" >&2
  exit 1
fi

APP_PATH="$1"
OUTPUT_DMG_PATH="$2"
VOLUME_NAME="${3:-Tonica}"
APP_NAME="$(basename "$APP_PATH")"

if [[ ! -d "$APP_PATH" ]]; then
  echo "app bundle not found: $APP_PATH" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
DEVICE=""
MOUNT_POINT=""
MOUNT_NAME=""
trap '{
  if [[ -n "$DEVICE" ]]; then
    hdiutil detach "$DEVICE" -quiet -force || true
  elif [[ -n "$MOUNT_POINT" && -d "$MOUNT_POINT" ]]; then
    hdiutil detach "$MOUNT_POINT" -quiet -force || true
  fi
  rm -rf "$TMP_DIR"
}' EXIT

STAGING_DIR="$TMP_DIR/staging"
BACKGROUND_DIR="$TMP_DIR/background"
RW_DMG_PATH="$TMP_DIR/${VOLUME_NAME}-rw.dmg"
BACKGROUND_PNG="$BACKGROUND_DIR/background.png"
mkdir -p "$STAGING_DIR" "$BACKGROUND_DIR"

ditto "$APP_PATH" "$STAGING_DIR/$APP_NAME"
swift "$RENDER_BG_SCRIPT" "$BACKGROUND_PNG"

ICON_SOURCE="$APP_PATH/Contents/Resources/Tonica.icns"

STAGING_KB="$(du -sk "$STAGING_DIR" | awk '{print $1}')"
SIZE_MB=$(( (STAGING_KB + 24 * 1024 + 1023) / 1024 ))
SIZE_MB=$(( SIZE_MB < 80 ? 80 : SIZE_MB ))

hdiutil create \
  -size "${SIZE_MB}m" \
  -fs APFS \
  -volname "$VOLUME_NAME" \
  "$RW_DMG_PATH" \
  >/dev/null

ATTACH_OUTPUT="$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG_PATH")"
DEVICE="$(printf '%s\n' "$ATTACH_OUTPUT" | awk -F '\t' 'index($NF, "/Volumes/") == 1 {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $1); print $1; exit}')"
MOUNT_POINT="$(printf '%s\n' "$ATTACH_OUTPUT" | awk -F '\t' 'index($NF, "/Volumes/") == 1 {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $NF); print $NF; exit}')"
MOUNT_NAME="$(basename "$MOUNT_POINT")"

if [[ -z "$DEVICE" || ! -d "$MOUNT_POINT" || -z "$MOUNT_NAME" ]]; then
  echo "failed to mount dmg" >&2
  printf '%s\n' "$ATTACH_OUTPUT" >&2
  exit 1
fi

ditto "$STAGING_DIR/$APP_NAME" "$MOUNT_POINT/$APP_NAME"

# Give Finder and IconServices a moment to index the copied app bundle before
# we persist the DMG window layout, otherwise the app tile can get cached with
# a generic placeholder icon in the mounted installer window.
sleep 2
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f -R "$MOUNT_POINT/$APP_NAME" >/dev/null 2>&1 || true

mkdir -p "$MOUNT_POINT/.background"
cp "$BACKGROUND_PNG" "$MOUNT_POINT/.background/background.png"

if [[ -f "$ICON_SOURCE" ]]; then
  cp "$ICON_SOURCE" "$MOUNT_POINT/.VolumeIcon.icns"
  "$(xcrun --find SetFile)" -a C "$MOUNT_POINT" 2>/dev/null || true
fi

for _pass in 1 2; do
  osascript <<EOF
tell application "Finder"
  tell disk "${MOUNT_NAME}"
    open
    delay 1

    set dmgWindow to container window
    if not (exists item "Applications" of dmgWindow) then
      set appsAlias to make new alias file at dmgWindow to POSIX file "/Applications"
      set name of appsAlias to "Applications"
    end if

    set current view of dmgWindow to icon view
    set toolbar visible of dmgWindow to false
    set statusbar visible of dmgWindow to false
    set pathbar visible of dmgWindow to false
    set sidebar width of dmgWindow to 0

    set the bounds of dmgWindow to {200, 200, 760, 560}

    set opts to the icon view options of dmgWindow
    set arrangement of opts to not arranged
    set icon size of opts to 116
    set text size of opts to 13
    set label position of opts to bottom
    set background picture of opts to file ".background:background.png"

    set position of item "${APP_NAME}" of dmgWindow to {145, 188}
    set position of item "Applications" of dmgWindow to {415, 188}

    update
    delay 2
    close
  end tell
end tell
EOF
  sleep 1
done

for dotitem in "$MOUNT_POINT"/.*; do
  [[ "$(basename "$dotitem")" == "." || "$(basename "$dotitem")" == ".." ]] && continue
  chflags hidden "$dotitem" 2>/dev/null || true
  "$(xcrun --find SetFile)" -a V "$dotitem" 2>/dev/null || true
done

sync
bless --folder "$MOUNT_POINT" --openfolder "$MOUNT_POINT" >/dev/null 2>&1 || true

hdiutil detach "$DEVICE" -quiet
sleep 1

rm -f "$OUTPUT_DMG_PATH"
hdiutil convert "$RW_DMG_PATH" -format ULFO -o "$OUTPUT_DMG_PATH" >/dev/null

echo "Built styled DMG: $OUTPUT_DMG_PATH"
