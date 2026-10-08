#!/usr/bin/env bash
# Act V smoke test (milestone 12), runs side by side, each a headless server and a bot.
#  1. Off Isla Ceniza at Ocaso's workshop: the bot fills a bucket and douses a brazier.
#  2. Off Cutlass Cay on Every Hand: the bot goes ashore and lights the beacon.
#  3. Off the Maw: the bot mans a cannon and breaks a joint of the Bone Colossus.
#
#   tests/smoke/act5_test.sh            (needs `godot` on PATH, or set GODOT=/path/to/godot)
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PORT="${PORT:-25050}"
RUN_FOR="${RUN_FOR:-150}"
LOGS="$(mktemp -d)"
trap 'rm -rf "$LOGS"' EXIT
run() { "$GODOT" --headless --path "$ROOT" -- "$@"; }
QUIT=$((RUN_FOR + 6))

run --server --no-save --calm --no-ai --start-near 6 --chapter e2 --chapter-step 1 --port "$PORT" --quit-after "$QUIT" >"$LOGS/ceniza.log" 2>&1 &
run --server --no-save --calm --no-ai --start-near 0 --chapter e3 --chapter-step 1 --port "$((PORT + 1))" --quit-after "$QUIT" >"$LOGS/beacon.log" 2>&1 &
run --server --no-save --calm --no-ai --start-near maw --chapter e5 --port "$((PORT + 2))" --quit-after "$QUIT" >"$LOGS/giant.log" 2>&1 &
sleep 2
run --bot brazier --port "$PORT" --quit-after "$RUN_FOR" >"$LOGS/ceniza_bot.log" 2>&1 &
run --bot beacon --port "$((PORT + 1))" --quit-after "$RUN_FOR" >"$LOGS/beacon_bot.log" 2>&1 &
run --bot giant --port "$((PORT + 2))" --quit-after "$RUN_FOR" >"$LOGS/giant_bot.log" 2>&1 &
wait

fail=0
check() {
	if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi
}
check "a brazier was doused" 'grep -q "a brazier was doused" "$LOGS/ceniza.log"'
check "a beacon was lit" 'grep -q "lit the beacon on Cutlass Cay" "$LOGS/beacon.log"'
check "a joint of the Colossus broke" 'grep -q "a joint of the Colossus breaks" "$LOGS/giant.log"'
check "no corrections" '! grep -h "RESULT server" "$LOGS"/*.log | grep -qv "corrections=0"'
check "no script errors" '! grep -l "SCRIPT ERROR" "$LOGS"/*.log'
if [ "$fail" -ne 0 ]; then
	for log in "$LOGS"/*.log; do echo "----- $log"; grep -v "phase=" "$log" | tail -20; done
fi
exit "$fail"
