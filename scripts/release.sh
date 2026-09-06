#!/usr/bin/env bash
set -euo pipefail
# Machine-readable GitHub output must ignore interactive shell color overrides.
unset GH_FORCE_TTY CLICOLOR_FORCE FORCE_COLOR
export NO_COLOR=1
cd "$(dirname "$0")/.."
exec python3 scripts/release.py "$@"
