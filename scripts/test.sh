#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_DIR="$(mktemp -d /tmp/tonica-tests.XXXXXX)"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc Sources/CircleData.swift Sources/AppPreferences.swift Sources/AppModel.swift Tests/TheoryTests.swift -o "$TEST_DIR/TheoryTests"
"$TEST_DIR/TheoryTests"
python3 -m unittest discover -s Tests -p '*_test.py'
