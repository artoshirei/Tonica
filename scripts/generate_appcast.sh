#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 || $# -gt 5 ]]; then
  echo "Usage: $0 <archive-path> <output-path> <download-url-prefix> [full-release-notes-url] [product-link]" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ARCHIVE_PATH="$1"
OUTPUT_PATH="$2"
DOWNLOAD_URL_PREFIX="$3"
FULL_RELEASE_NOTES_URL="${4:-}"
PRODUCT_LINK="${5:-https://artoshi.work/tonica}"
TOOL_PATH=""
for candidate in \
  "$ROOT_DIR/.build/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast" \
  "$ROOT_DIR/.derived_ci/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast" \
  "$ROOT_DIR/.derived/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast"
do
  if [[ -x "$candidate" ]]; then
    TOOL_PATH="$candidate"
    break
  fi
done

if [[ -z "$TOOL_PATH" ]]; then
  echo "Sparkle generate_appcast tool not found in local SourcePackages artifacts" >&2
  exit 1
fi

if [[ ! -f "$ARCHIVE_PATH" ]]; then
  echo "Archive not found: $ARCHIVE_PATH" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/tonica-appcast.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

ARCHIVE_NAME="$(basename "$ARCHIVE_PATH")"
OUTPUT_NAME="$(basename "$OUTPUT_PATH")"
mkdir -p "$(dirname "$OUTPUT_PATH")"
cp "$ARCHIVE_PATH" "$TMP_DIR/$ARCHIVE_NAME"

args=(
  --download-url-prefix "$DOWNLOAD_URL_PREFIX"
  --link "$PRODUCT_LINK"
  -o "$OUTPUT_NAME"
)

if [[ -n "$FULL_RELEASE_NOTES_URL" ]]; then
  args+=(--full-release-notes-url "$FULL_RELEASE_NOTES_URL")
fi

if [[ -n "${SPARKLE_PRIVATE_ED_KEY:-}" ]]; then
  printf '%s' "$SPARKLE_PRIVATE_ED_KEY" | "$TOOL_PATH" --ed-key-file - "${args[@]}" "$TMP_DIR"
elif [[ -n "${SPARKLE_PRIVATE_KEY_FILE:-}" ]]; then
  "$TOOL_PATH" --ed-key-file "$SPARKLE_PRIVATE_KEY_FILE" "${args[@]}" "$TMP_DIR"
else
  "$TOOL_PATH" --account "${SPARKLE_KEYCHAIN_ACCOUNT:-tonica}" "${args[@]}" "$TMP_DIR"
fi

GENERATED_PATH=""
for candidate in \
  "$OUTPUT_PATH" \
  "$PWD/$OUTPUT_NAME" \
  "$TMP_DIR/$OUTPUT_NAME" \
  "$TMP_DIR/appcast.xml"
do
  if [[ -f "$candidate" ]]; then
    GENERATED_PATH="$candidate"
    break
  fi
done

if [[ -z "$GENERATED_PATH" ]]; then
  echo "Failed to locate generated appcast output" >&2
  exit 1
fi

cp "$GENERATED_PATH" "$OUTPUT_PATH"
echo "Wrote Sparkle appcast to $OUTPUT_PATH"
