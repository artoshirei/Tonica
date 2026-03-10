#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <app_path>" >&2
  exit 1
fi

APP_PATH="$1"
ICON_DEST="$APP_PATH/Contents/Resources/Tonica.icns"
FALLBACK_ICON="$ROOT_DIR/Resources/Tonica.icns"

if [[ -f "$ICON_DEST" ]]; then
  exit 0
fi

if [[ ! -f "$FALLBACK_ICON" ]]; then
  echo "fallback icon not found: $FALLBACK_ICON" >&2
  exit 1
fi

mkdir -p "$(dirname "$ICON_DEST")"
cp "$FALLBACK_ICON" "$ICON_DEST"
echo "Injected fallback app icon at $ICON_DEST"
