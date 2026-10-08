#!/usr/bin/env bash
# Run every smoke test at once (each on its own ports) and print one summary.
# Exits non-zero if any of them failed. Takes about as long as the slowest (~5 min).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT
tests=(smoke_test combat_test treasure_test fighting_test crew_test storm_test missions_test story_test act1_test)
port=24800
pids=()
for t in "${tests[@]}"; do
	if [ -x "$ROOT/tests/smoke/$t.sh" ]; then
		PORT=$port "$ROOT/tests/smoke/$t.sh" >"$OUT/$t.out" 2>&1 &
		pids+=($!)
		port=$((port + 10))
	fi
done
status=0
for pid in "${pids[@]}"; do wait "$pid" || status=1; done
for t in "${tests[@]}"; do
	[ -f "$OUT/$t.out" ] || continue
	echo "== $t"
	grep -E "^(ok|FAIL)" "$OUT/$t.out"
	if grep -q "^FAIL" "$OUT/$t.out"; then grep -v "^ok" "$OUT/$t.out" | tail -40; fi
done
exit "$status"
