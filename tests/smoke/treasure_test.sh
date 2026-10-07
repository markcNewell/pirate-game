#!/usr/bin/env bash
# Treasure smoke test (milestone 3), two runs side by side, each a headless server and a bot.
#  1. Anchored off Parrot Rock: the bot takes a voyage at the map table, swims ashore, digs up
#     the chest at the X, carries it back up the ladder and puts it down on deck.
#  2. Anchored off Port Merrow with a chest aboard: the bot carries it to the merchant, sells it,
#     walks out along the pier and restocks the ship from a supply barrel.
#
#   tests/smoke/treasure_test.sh            (needs `godot` on PATH, or set GODOT=/path/to/godot)
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PORT="${PORT:-24695}"
RUN_FOR="${RUN_FOR:-110}"
LOGS="$(mktemp -d)"
trap 'rm -rf "$LOGS"' EXIT
run() { "$GODOT" --headless --path "$ROOT" -- "$@"; }

run --server --calm --no-ai --start-near 1 --voyage-island 1 --port "$PORT" --quit-after "$((RUN_FOR + 6))" >"$LOGS/hunt.log" 2>&1 &
s1=$!
run --server --calm --no-ai --start-near outpost --test-chest --port "$((PORT + 1))" --quit-after "$((RUN_FOR + 6))" >"$LOGS/sell.log" 2>&1 &
s2=$!
sleep 2
run --bot treasure --port "$PORT" --quit-after "$RUN_FOR" >"$LOGS/hunt_bot.log" 2>&1 &
b1=$!
run --bot seller --port "$((PORT + 1))" --quit-after "$RUN_FOR" >"$LOGS/sell_bot.log" 2>&1 &
b2=$!
for pid in $b1 $b2 $s1 $s2; do wait "$pid" || true; done

fail=0
check() {
	if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi
}
check "a voyage was taken" 'grep -q "voyage to Parrot Rock" "$LOGS/hunt.log"'
check "the chest was dug up" 'grep -q "dug up a" "$LOGS/hunt.log"'
check "it was carried back aboard and put down" 'grep -q "stowed the chest" "$LOGS/hunt_bot.log"'
check "a chest was sold" 'grep -q "sold a .* for [0-9]* gold" "$LOGS/sell.log"'
check "the ship was restocked" 'grep -q "restocked the ship" "$LOGS/sell_bot.log"'
check "no corrections" 'grep -q "corrections=0" "$LOGS/hunt.log" && grep -q "corrections=0" "$LOGS/sell.log"'
check "no script errors" '! grep -l "SCRIPT ERROR" "$LOGS"/*.log'
if [ "$fail" -ne 0 ]; then
	for log in "$LOGS"/*.log; do echo "----- $log"; grep -v "phase=" "$log" | tail -20; done
fi
exit "$fail"
