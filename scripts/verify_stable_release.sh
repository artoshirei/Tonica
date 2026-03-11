#!/usr/bin/env bash
set -euo pipefail

TAG=""
VERSION=""

usage() {
  cat <<'EOF'
Usage: ./scripts/verify_stable_release.sh --tag vX.Y.Z --version X.Y.Z

Verify Tonica stable release state:
- GitHub Release contains Tonica.dmg
- latest-download DMG URL resolves
- raw GitHub appcast resolves and references the expected version/tag
EOF
}

die() {
  echo "$*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag)
      [[ $# -ge 2 ]] || die "Missing value for --tag"
      TAG="$2"
      shift 2
      ;;
    --version)
      [[ $# -ge 2 ]] || die "Missing value for --version"
      VERSION="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

[[ -n "$TAG" ]] || die "--tag is required"
[[ -n "$VERSION" ]] || die "--version is required"
[[ "$TAG" == "v$VERSION" ]] || die "--tag must match --version exactly"

command -v gh >/dev/null 2>&1 || die "gh is required"
command -v jq >/dev/null 2>&1 || die "jq is required"
command -v curl >/dev/null 2>&1 || die "curl is required"

RELEASE_JSON="$(gh release view "$TAG" --json tagName,url,assets)"

jq -e --arg tag "$TAG" '.tagName == $tag' >/dev/null <<<"$RELEASE_JSON" \
  || die "GitHub Release tag mismatch for $TAG"

ASSET_URL="$(jq -r '.assets[] | select(.name == "Tonica.dmg") | .url' <<<"$RELEASE_JSON" | head -n 1)"
[[ -n "$ASSET_URL" ]] || die "GitHub Release $TAG does not contain Tonica.dmg"

TAG_URL="https://github.com/artoshirei/Tonica/releases/download/${TAG}/Tonica.dmg"
LATEST_URL="https://github.com/artoshirei/Tonica/releases/latest/download/Tonica.dmg"
APPCAST_URL="https://raw.githubusercontent.com/artoshirei/Tonica/main/docs/appcast.xml"

curl --fail --silent --show-error --location --head "$TAG_URL" >/dev/null
curl --fail --silent --show-error --location --head "$LATEST_URL" >/dev/null

APPCAST_CONTENT="$(curl --fail --silent --show-error --location "$APPCAST_URL")"

grep -Fq "<sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>" <<<"$APPCAST_CONTENT" \
  || die "Appcast does not contain version ${VERSION}"

grep -Fq "releases/download/${TAG}/Tonica.dmg" <<<"$APPCAST_CONTENT" \
  || die "Appcast does not reference ${TAG}"

echo "Verified GitHub Release asset: $ASSET_URL"
echo "Verified stable latest-download URL: $LATEST_URL"
echo "Verified stable appcast URL: $APPCAST_URL"
