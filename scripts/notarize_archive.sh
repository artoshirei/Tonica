#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <archive-path>" >&2
  exit 1
fi

ARCHIVE_PATH="$1"
TIMEOUT="${APPLE_NOTARY_TIMEOUT:-20m}"

if [[ ! -e "$ARCHIVE_PATH" ]]; then
  echo "archive not found: $ARCHIVE_PATH" >&2
  exit 1
fi

submit_args=(
  submit
  "$ARCHIVE_PATH"
  --wait
  --timeout "$TIMEOUT"
)

if [[ -n "${APPLE_NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
  submit_args+=(--keychain-profile "$APPLE_NOTARY_KEYCHAIN_PROFILE")

  if [[ -n "${APPLE_NOTARY_KEYCHAIN_PATH:-}" ]]; then
    submit_args+=(--keychain "$APPLE_NOTARY_KEYCHAIN_PATH")
  fi
elif [[ -n "${APPLE_NOTARY_API_KEY_PATH:-}" && -n "${APPLE_NOTARY_KEY_ID:-}" ]]; then
  submit_args+=(
    --key "$APPLE_NOTARY_API_KEY_PATH"
    --key-id "$APPLE_NOTARY_KEY_ID"
  )

  if [[ -n "${APPLE_NOTARY_ISSUER_ID:-}" ]]; then
    submit_args+=(--issuer "$APPLE_NOTARY_ISSUER_ID")
  fi
elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" && -n "${APPLE_TEAM_ID:-}" ]]; then
  submit_args+=(
    --apple-id "$APPLE_ID"
    --password "$APPLE_APP_SPECIFIC_PASSWORD"
    --team-id "$APPLE_TEAM_ID"
  )
else
  cat >&2 <<'EOF'
Missing notarization credentials.

Supported auth modes:
1. APPLE_NOTARY_KEYCHAIN_PROFILE [+ APPLE_NOTARY_KEYCHAIN_PATH]
2. APPLE_NOTARY_API_KEY_PATH + APPLE_NOTARY_KEY_ID [+ APPLE_NOTARY_ISSUER_ID]
3. APPLE_ID + APPLE_APP_SPECIFIC_PASSWORD + APPLE_TEAM_ID
EOF
  exit 1
fi

echo "Submitting $(basename "$ARCHIVE_PATH") for notarization..."
xcrun notarytool "${submit_args[@]}"

