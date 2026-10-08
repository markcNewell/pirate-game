#!/usr/bin/env bash
# Armoury smoke test (milestone 14), side by side, each a headless server and a bot.
#  1. At Port Merrow with gold to spend: the bot buys a rapier and a blunderbuss from Martha.
#  2. Off Parrot Rock carrying a rapier and a blunderbuss: the bot fights the island's dead.
#
#   tests/smoke/armoury_test.sh            (needs `godot` on PATH, or set GODOT=/path/to/godot)
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PORT="${PORT:-25070}"
RUN_FOR="${RUN_FOR:-120}"
LOGS="$(mktemp -d)"
trap 'rm -rf "$LOGS"' EXIT
run() { "$GODOT" --headless --path "$ROOT" -- "$@"; }
QUIT=$((RUN_FOR + 6))

run --server --no-save --calm --no-ai --start-near outpost --gold 2000 --port "$PORT" --quit-after "$QUIT" >"$LOGS/shop.log" 2>&1 &
run --server --no-save --calm --no-ai --start-near 1 --blade 1 --gun 1 --port "$((PORT + 1))" --quit-after "$QUIT" >"$LOGS/fight.log" 2>&1 &
sleep 2
run --bot armourer --port "$PORT" --quit-after "$RUN_FOR" >"$LOGS/shop_bot.log" 2>&1 &
run --bot fighter --port "$((PORT + 1))" --quit-after "$RUN_FOR" >"$LOGS/fight_bot.log" 2>&1 &
wait

fail=0
check() {
	if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi
}
check "a rapier was bought" 'grep -q "bought Rapier" "$LOGS/shop.log"'
check "and carried" 'grep -q "carries the Rapier" "$LOGS/shop.log"'
check "a blunderbuss too" 'grep -q "carries the Blunderbuss" "$LOGS/shop.log"'
check "the dead were fought with them" 'grep -q "Bot fighter felled skeleton" "$LOGS/fight.log"'
check "no corrections" '! grep -h "RESULT server" "$LOGS"/*.log | grep -qv "corrections=0"'
check "no script errors" '! grep -l "SCRIPT ERROR" "$LOGS"/*.log'
if [ "$fail" -ne 0 ]; then
	for log in "$LOGS"/*.log; do echo "----- $log"; grep -v "phase=" "$log" | tail -20; grep "phase=" "$log" | tail -3; done
fi
exit "$fail"
