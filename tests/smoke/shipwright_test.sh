#!/usr/bin/env bash
# Shipwright smoke test (milestone 19): a headless server at Port Merrow and two bots.
#  1. The first goes ashore to Old Hobb on the pier, buys black sails and has them fitted; the
#     second, in another crew, sees them.
#  2. The fort as a port after the story (milestone 21): a bot whose pirate has finished it goes
#     in through the gate to Isabel and buys a rapier.
#
#   tests/smoke/shipwright_test.sh       (needs `godot` on PATH, or set GODOT=/path/to/godot)
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PORT="${PORT:-25080}"
RUN_FOR="${RUN_FOR:-90}"
LOGS="$(mktemp -d)"
trap 'rm -rf "$LOGS"' EXIT
run() { "$GODOT" --headless --path "$ROOT" -- "$@"; }
QUIT=$((RUN_FOR + 6))

run --server --at-sea --no-save --calm --no-ai --start-near outpost --gold 2000 --port "$PORT" --quit-after "$QUIT" >"$LOGS/server.log" 2>&1 &
run --server --at-sea --no-save --calm --no-ai --start-near 4 --gold 2000 --done e6 --port "$((PORT + 1))" --quit-after "$QUIT" >"$LOGS/fort.log" 2>&1 &
sleep 2
run --bot fortarms --port "$((PORT + 1))" --quit-after "$RUN_FOR" >"$LOGS/fort_bot.log" 2>&1 &
run --bot wright --port "$PORT" --quit-after "$RUN_FOR" >"$LOGS/wright_bot.log" 2>&1 &
run --bot watcher --crew 2 --port "$PORT" --quit-after "$RUN_FOR" >"$LOGS/watcher_bot.log" 2>&1 &
wait

fail=0
check() {
	if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi
}
check "black sails were bought" 'grep -q "bought Black sails" "$LOGS/server.log"'
check "and fitted" 'grep -q "fitted Black sails to" "$LOGS/server.log"'
check "another crew saw them" 'grep -q "saw crew 1.s ship with sails 7" "$LOGS/watcher_bot.log"'
check "the fort was our port" 'grep -q "the fort is our port" "$LOGS/fort_bot.log"'
check "Isabel sold a rapier there" 'grep -q "bought Rapier for 600 gold from Isabel" "$LOGS/fort.log"'
check "no corrections" '! grep -h "RESULT server" "$LOGS"/*.log | grep -qv "corrections=0"'
check "no script errors" '! grep -l "SCRIPT ERROR" "$LOGS"/*.log'
if [ "$fail" -ne 0 ]; then
	for log in "$LOGS"/*.log; do echo "----- $log"; grep -v "phase=" "$log" | tail -20; grep "phase=" "$log" | tail -3; done
fi
exit "$fail"
