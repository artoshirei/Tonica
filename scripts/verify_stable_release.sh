#!/usr/bin/env bash
set -euo pipefail
[[ $# == 1 ]] || { echo 'usage: verify_stable_release.sh vX.Y.Z' >&2; exit 2; }
exec "$(dirname "$0")/release.sh" verify "$1"
