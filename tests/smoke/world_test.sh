#!/usr/bin/env bash
# World events smoke test (milestone 13), side by side, each a headless server and its bots.
#  1. Off Gull Isle with a Green Fire burning there: a bot fills a bucket and douses all three.
#  2. Off Parrot Rock with the Raven Patrol close by: she turns on the crew and a bot fights back.
#  3. Off Fuerte del Cuervo with the dead holding it (M18): a bot goes ashore and fights them.
#  4. By the Maw as it stirs (M18): a bot's cannon breaks a joint of the lesser colossus.
#
#   tests/smoke/world_test.sh            (needs `godot` on PATH, or set GODOT=/path/to/godot)
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PORT="${PORT:-25060}"
RUN_FOR="${RUN_FOR:-180}"
LOGS="$(mktemp -d)"
trap 'rm -rf "$LOGS"' EXIT
run() { "$GODOT" --headless --path "$ROOT" -- "$@"; }
QUIT=$((RUN_FOR + 6))

run --server --at-sea --no-save --calm --no-ai --start-near 2 --event green_fire --port "$PORT" --quit-after "$QUIT" >"$LOGS/fire.log" 2>&1 &
run --server --at-sea --no-save --calm --no-ai --start-near 1 --event patrol --port "$((PORT + 1))" --quit-after "$QUIT" >"$LOGS/patrol.log" 2>&1 &
run --server --at-sea --no-save --calm --no-ai --start-near 4 --event fort --port "$((PORT + 2))" --quit-after "$QUIT" >"$LOGS/fort.log" 2>&1 &
run --server --at-sea --no-save --calm --no-ai --start-near maw --event maw --port "$((PORT + 3))" --quit-after "$QUIT" >"$LOGS/maw.log" 2>&1 &
sleep 2
run --bot lights --port "$PORT" --quit-after "$RUN_FOR" >"$LOGS/fire_bot.log" 2>&1 &
run --bot gunner --port "$((PORT + 1))" --quit-after "$RUN_FOR" >"$LOGS/patrol_bot.log" 2>&1 &
run --bot fighter --port "$((PORT + 2))" --quit-after "$RUN_FOR" >"$LOGS/fort_bot.log" 2>&1 &
run --bot giant --port "$((PORT + 3))" --quit-after "$RUN_FOR" >"$LOGS/maw_bot.log" 2>&1 &
wait

fail=0
check() {
	if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi
}
check "the green fire event began" 'grep -q "world event: Green Fire" "$LOGS/fire.log"'
check "and was won" 'grep -q "world event over: Green Fire (won)" "$LOGS/fire.log"'
check "the Raven Patrol turned on the crew" 'grep -q "the Raven Patrol turns on a crew" "$LOGS/patrol.log"'
check "the crew fought back" 'grep -q "took station" "$LOGS/patrol_bot.log"'
check "the dead held the fort" 'grep -q "world event: Fuerte del Cuervo" "$LOGS/fort.log"'
check "and were fought" 'grep -q "felled skeleton" "$LOGS/fort.log"'
check "the Maw stirred" 'grep -q "world event: The Maw Stirs" "$LOGS/maw.log"'
check "a joint of the giant broke" 'grep -q "a joint of the lesser colossus breaks" "$LOGS/maw.log"'
check "no corrections" '! grep -h "RESULT server" "$LOGS"/*.log | grep -qv "corrections=0"'
check "no script errors" '! grep -l "SCRIPT ERROR" "$LOGS"/*.log'
if [ "$fail" -ne 0 ]; then
	for log in "$LOGS"/*.log; do echo "----- $log"; grep -v "phase=" "$log" | tail -20; grep "phase=" "$log" | tail -3; done
fi
exit "$fail"
