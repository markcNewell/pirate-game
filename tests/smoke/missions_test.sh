#!/usr/bin/env bash
# Missions smoke test (milestone 6), four runs side by side, each a headless server and a bot.
#  1. Off Parrot Rock: the bot takes the Lantern Order's bounty, swims ashore, beats the
#     skeleton captain and his crew, and carries the captain's skull back aboard.
#  2. Off Port Merrow with a skull aboard: the bot sells it to Mother Wren.
#  3. Off Port Merrow: the bot takes a Merrow Traders cargo run, fetches a crate from the
#     pier and stows it aboard.
#  4. Off Gull Isle with a cargo run under way and its crate on deck: the bot carries the crate
#     ashore and hands it to the trader.
#
#   tests/smoke/missions_test.sh            (needs `godot` on PATH, or set GODOT=/path/to/godot)
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PORT="${PORT:-24700}"
RUN_FOR="${RUN_FOR:-150}"
LOGS="$(mktemp -d)"
trap 'rm -rf "$LOGS"' EXIT
run() { "$GODOT" --headless --path "$ROOT" -- "$@"; }
QUIT=$((RUN_FOR + 6))

run --server --at-sea --no-save --calm --no-ai --start-near 1 --voyage-island 1 --mission bounty --port "$PORT" --quit-after "$QUIT" >"$LOGS/bounty.log" 2>&1 &
run --server --at-sea --no-save --calm --no-ai --start-near outpost --test-skull --port "$((PORT + 1))" --quit-after "$QUIT" >"$LOGS/skull.log" 2>&1 &
run --server --at-sea --no-save --calm --no-ai --start-near outpost --mission cargo --voyage-island 2 --port "$((PORT + 2))" --quit-after "$QUIT" >"$LOGS/cargo.log" 2>&1 &
run --server --at-sea --no-save --calm --no-ai --start-near 2 --test-cargo --voyage-island 2 --port "$((PORT + 3))" --quit-after "$QUIT" >"$LOGS/courier.log" 2>&1 &
sleep 2
run --bot bounty --port "$PORT" --quit-after "$RUN_FOR" >"$LOGS/bounty_bot.log" 2>&1 &
run --bot seller --port "$((PORT + 1))" --quit-after "$RUN_FOR" >"$LOGS/skull_bot.log" 2>&1 &
run --bot cargo --port "$((PORT + 2))" --quit-after "$RUN_FOR" >"$LOGS/cargo_bot.log" 2>&1 &
run --bot courier --port "$((PORT + 3))" --quit-after "$RUN_FOR" >"$LOGS/courier_bot.log" 2>&1 &
wait

fail=0
check() {
	if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi
}
check "a bounty was taken" 'grep -q "took a bounty mission" "$LOGS/bounty.log"'
check "the captain fell and dropped his skull" 'grep -q "has fallen; his skull" "$LOGS/bounty.log"'
check "the skull was carried back aboard" 'grep -q "stowed the skull" "$LOGS/bounty_bot.log"'
check "Mother Wren bought a skull" 'grep -q "sold a captain.s skull for [0-9]* gold" "$LOGS/skull.log"'
check "a cargo run was taken" 'grep -q "took a cargo mission" "$LOGS/cargo.log"'
check "a crate was fetched from the pier and stowed" 'grep -q "stowed the crate" "$LOGS/cargo_bot.log"'
check "a crate was delivered to the trader" 'grep -q "delivered a crate of .* for [0-9]* gold" "$LOGS/courier.log"'
check "and the run finished" 'grep -q "finished" "$LOGS/courier.log"'
check "no corrections" '! grep -h "RESULT server" "$LOGS"/*.log | grep -qv "corrections=0"'
check "no script errors" '! grep -l "SCRIPT ERROR" "$LOGS"/*.log'
if [ "$fail" -ne 0 ]; then
	for log in "$LOGS"/*.log; do echo "----- $log"; grep -v "phase=" "$log" | tail -20; grep "phase=" "$log" | tail -3; done
fi
exit "$fail"
