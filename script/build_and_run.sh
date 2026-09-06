#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
MODE="${1:-run}"
case "$MODE" in run|--build-only|--verify|--logs|--telemetry|--debug) ;; *) echo "usage: $0 [--build-only|--verify|--logs|--telemetry|--debug]" >&2; exit 2;; esac
BUNDLE="$ROOT/.build-preview/Tonica Preview.app"
# Only stop the preview from this project's exact build path.
while IFS= read -r pid; do
  [[ "$(ps -p "$pid" -o comm=)" == "$BUNDLE/Contents/MacOS/Tonica Preview" ]] && kill "$pid"
done < <(pgrep -x 'Tonica Preview' || true)
xcodegen generate
xcodebuild -project Tonica.xcodeproj -scheme Tonica -configuration Debug \
  -derivedDataPath .build-preview build CODE_SIGNING_ALLOWED=NO \
  PRODUCT_BUNDLE_IDENTIFIER=com.playground.tonica.preview ENABLE_DEBUG_DYLIB=NO
/usr/bin/ditto "$ROOT/.build-preview/Build/Products/Debug/Tonica.app" "$BUNDLE"
mv "$BUNDLE/Contents/MacOS/Tonica" "$BUNDLE/Contents/MacOS/Tonica Preview"
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable Tonica Preview" "$BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName Tonica Preview" "$BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Tonica Preview" "$BUNDLE/Contents/Info.plist"
# The preview cannot contact Sparkle, even if updater guards regress.
/usr/libexec/PlistBuddy -c 'Delete :SUFeedURL' "$BUNDLE/Contents/Info.plist" 2>/dev/null || true
python3 - "$ROOT/Tonica.entitlements" "$ROOT/.build-preview/Preview.entitlements" <<'PYTHON'
import plistlib, sys
from pathlib import Path
text = Path(sys.argv[1]).read_text().replace('$(PRODUCT_BUNDLE_IDENTIFIER)', 'com.playground.tonica.preview')
Path(sys.argv[2]).write_bytes(plistlib.dumps(plistlib.loads(text.encode())))
PYTHON
/usr/bin/codesign --force --sign - --entitlements "$ROOT/.build-preview/Preview.entitlements" "$BUNDLE"
[[ "$MODE" == --build-only ]] && exit 0
if [[ "$MODE" == --debug ]]; then lldb "$BUNDLE/Contents/MacOS/Tonica Preview"; exit; fi
/usr/bin/open -n "$BUNDLE"
if [[ "$MODE" == --verify ]]; then
  sleep 2
  pgrep -x 'Tonica Preview'
  /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$BUNDLE/Contents/Info.plist"
elif [[ "$MODE" == --logs || "$MODE" == --telemetry ]]; then
  /usr/bin/log stream --info --style compact --predicate 'process == "Tonica Preview"'
fi
