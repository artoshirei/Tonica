#!/usr/bin/env bash
set -euo pipefail
# Compatibility entrypoint. Candidate and publication are now separate local commands.
exec "$(dirname "$0")/release.sh" "$@"
