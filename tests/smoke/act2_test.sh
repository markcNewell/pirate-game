#!/usr/bin/env bash
# Act II smoke test (milestone 9), runs side by side, each a headless server and a bot.
#  1. Off Parrot Rock on The Drowned Bells: the bot goes ashore and shoots the bell down.
#  2. Off Gull Isle on The Admiral's Story, at the dive: the bot swims to the San Telmo and dives.
#  3. Off Fuerte del Cuervo: the bot shoots the powder by the gate and blows the gate in.
#
#   tests/smoke/act2_test.sh            (needs `godot` on PATH, or set GODOT=/path/to/godot)
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PORT="${PORT:-25020}"
RUN_FOR="${RUN_FOR:-150}"
LOGS="$(mktemp -d)"
trap 'rm -rf "$LOGS"' EXIT
run() { "$GODOT" --headless --path "$ROOT" -- "$@"; }
QUIT=$((RUN_FOR + 6))

run --server --at-sea --no-save --calm --no-ai --start-near 1 --chapter b4 --port "$PORT" --quit-after "$QUIT" >"$LOGS/bells.log" 2>&1 &
run --server --at-sea --no-save --calm --no-ai --start-near 2 --chapter b2 --port "$((PORT + 1))" --quit-after "$QUIT" >"$LOGS/dive.log" 2>&1 &
run --server --at-sea --no-save --calm --no-ai --start-near 4 --chapter b6 --port "$((PORT + 2))" --quit-after "$QUIT" >"$LOGS/fort.log" 2>&1 &
sleep 2
run --bot bells --port "$PORT" --quit-after "$RUN_FOR" >"$LOGS/bells_bot.log" 2>&1 &
run --bot diver --port "$((PORT + 1))" --quit-after "$RUN_FOR" >"$LOGS/dive_bot.log" 2>&1 &
run --bot kegs --port "$((PORT + 2))" --quit-after "$RUN_FOR" >"$LOGS/fort_bot.log" 2>&1 &
wait

fail=0
check() {
	if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi
}
check "a drowned bell was shot down" 'grep -q "a drowned bell was shot down" "$LOGS/bells.log"'
check "the San Telmo's logbook was found" 'grep -q "dived to the San Telmo" "$LOGS/dive.log"'
check "the fort's powder went up" 'grep -q "a powder keg exploded" "$LOGS/fort.log"'
check "and the gate with it" 'grep -q "the fort.s gate was blown" "$LOGS/fort.log"'
check "no corrections" '! grep -h "RESULT server" "$LOGS"/*.log | grep -qv "corrections=0"'
check "no script errors" '! grep -l "SCRIPT ERROR" "$LOGS"/*.log'
if [ "$fail" -ne 0 ]; then
	for log in "$LOGS"/*.log; do echo "----- $log"; grep -v "phase=" "$log" | tail -20; grep "phase=" "$log" | tail -3; done
fi
exit "$fail"
