#!/usr/bin/env bash
# Shipyards smoke test (milestone 26): three servers side by side.
#  1. Embark: a real game's start on Port Merrow's pier; a bot of each of two crews walks to the
#     end beside its ship and climbs aboard.
#  2. Sloop: crew 1's ship starts sunk off Gull Isle (--wreck-at 3); a broke bot swims to the
#     yard, takes the free sloop, winches her anchor up and sails off.
#  3. Galleon: the same off Port Merrow (--wreck-at 0) with 600 gold; the bot buys a galleon
#     from Old Hobb.
#
#   tests/smoke/shipyard_test.sh            (needs `godot` on PATH, or set GODOT=/path/to/godot)
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PORT="${PORT:-24920}"
RUN_FOR="${RUN_FOR:-80}"
LOGS="$(mktemp -d)"
if [ -n "${KEEP_LOGS:-}" ]; then echo "logs in $LOGS"; else trap 'rm -rf "$LOGS"' EXIT; fi
run() { "$GODOT" --headless --path "$ROOT" -- "$@"; }

servers=()
run --server --no-save --calm --no-ai --port "$PORT" --quit-after "$((RUN_FOR + 6))" >"$LOGS/embark.log" 2>&1 &
servers+=($!)
run --server --at-sea --no-save --calm --no-ai --wreck-at 3 --port "$((PORT + 1))" --quit-after "$((RUN_FOR + 6))" >"$LOGS/sloop.log" 2>&1 &
servers+=($!)
run --server --at-sea --no-save --calm --no-ai --wreck-at 0 --gold 600 --port "$((PORT + 2))" --quit-after "$((RUN_FOR + 6))" >"$LOGS/galleon.log" 2>&1 &
servers+=($!)
sleep 2
bots=()
for crew in 1 2; do
	run --bot embark --crew "$crew" --port "$PORT" --quit-after "$RUN_FOR" >"$LOGS/embark_bot_$crew.log" 2>&1 &
	bots+=($!)
done
run --bot shipyard --crew 1 --port "$((PORT + 1))" --quit-after "$RUN_FOR" >"$LOGS/sloop_bot.log" 2>&1 &
bots+=($!)
run --bot shipyard --crew 1 --port "$((PORT + 2))" --quit-after "$RUN_FOR" >"$LOGS/galleon_bot.log" 2>&1 &
bots+=($!)
for pid in "${bots[@]}" "${servers[@]}"; do wait "$pid" || true; done

fail=0
check() {
	if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi
}
check "crew 1 climbed aboard from the pier" 'grep -q "aboard our ship from the pier" "$LOGS/embark_bot_1.log"'
check "crew 2 climbed aboard from the pier" 'grep -q "aboard our ship from the pier" "$LOGS/embark_bot_2.log"'
check "a broke crew got the free sloop at Gull Isle" 'grep -q "bought a sloop at Gull Isle for crew 1 (0 gold)" "$LOGS/sloop.log"'
check "and sailed her" 'grep -q "under sail in the sloop" "$LOGS/sloop_bot.log"'
check "600 gold bought a galleon from Old Hobb" 'grep -q "bought a galleon at Port Merrow for crew 1 (500 gold)" "$LOGS/galleon.log"'
check "leaving 100 gold" 'grep -q "aboard our new galleon, 100 gold left" "$LOGS/galleon_bot.log"'
check "no script errors" '! grep -l "SCRIPT ERROR" "$LOGS"/*.log'
if [ "$fail" -ne 0 ]; then
	for log in "$LOGS"/*.log; do echo "----- $log"; grep -v "phase=" "$log" | tail -15; done
fi
exit "$fail"
