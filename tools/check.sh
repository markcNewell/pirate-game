#!/usr/bin/env bash
# Import the project (failing on any script parse or compile error) and run the unit tests.
# Use before committing: tools/check.sh && git commit ...
set -uo pipefail
GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
errors="$("$GODOT" --headless --path "$ROOT" --import 2>&1 | grep -E "Parse Error|Compile Error" -A1 || true)"
if [ -n "$errors" ]; then
	echo "$errors"
	exit 1
fi
out="$("$GODOT" --headless --path "$ROOT" -s tests/run_tests.gd 2>&1)"
status=$?
grep -E "FAIL|tests," <<<"$out" || true
exit "$status"
