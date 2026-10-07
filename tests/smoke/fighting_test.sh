#!/usr/bin/env bash
# Fighting smoke test (milestone 4), two runs side by side, each a headless server and a bot.
#  1. Anchored off Parrot Rock: the bot swims ashore, wakes the skeleton camp and fights it.
#  2. A skeleton ship lies alongside: the bot swims over, climbs its ladder and fights its crew.
#     Falling is fine: it should come back aboard its own ship and try again.
#
#   tests/smoke/fighting_test.sh            (needs `godot` on PATH, or set GODOT=/path/to/godot)
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PORT="${PORT:-24697}"
RUN_FOR="${RUN_FOR:-90}"
LOGS="$(mktemp -d)"
trap 'rm -rf "$LOGS"' EXIT
run() { "$GODOT" --headless --path "$ROOT" -- "$@"; }

run --server --no-ai --start-near 1 --port "$PORT" --quit-after "$((RUN_FOR + 6))" >"$LOGS/island.log" 2>&1 &
s1=$!
run --server --no-ai --test-boarding --port "$((PORT + 1))" --quit-after "$((RUN_FOR + 6))" >"$LOGS/board.log" 2>&1 &
s2=$!
sleep 2
run --bot fighter --port "$PORT" --quit-after "$RUN_FOR" >"$LOGS/island_bot.log" 2>&1 &
b1=$!
run --bot boarder --port "$((PORT + 1))" --quit-after "$RUN_FOR" >"$LOGS/board_bot.log" 2>&1 &
b2=$!
for pid in $b1 $b2 $s1 $s2; do wait "$pid" || true; done

fail=0
check() {
	if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi
}
count() { grep -c "$1" "$2" || true; }
check "the island camp woke" 'grep -q "skeletons of Parrot Rock awake" "$LOGS/island.log"'
check "island skeletons were felled ($(count "felled skeleton" "$LOGS/island.log"))" '[ "$(count "felled skeleton" "$LOGS/island.log")" -ge 2 ]'
check "the skeleton ship was boarded" 'grep -q "boarded skeleton ship" "$LOGS/board.log"'
check "its crew were felled ($(count "felled skeleton" "$LOGS/board.log"))" '[ "$(count "felled skeleton" "$LOGS/board.log")" -ge 2 ]'
check "skeletons fought back" 'grep -q "skeleton_swings=[1-9]" "$LOGS/board.log" || grep -q "skeleton_swings=[1-9]" "$LOGS/island.log"'
check "no script errors" '! grep -l "SCRIPT ERROR" "$LOGS"/*.log'
if [ "$fail" -ne 0 ]; then
	for log in "$LOGS"/*.log; do echo "----- $log"; grep -v "phase=" "$log" | tail -20; done
fi
exit "$fail"
