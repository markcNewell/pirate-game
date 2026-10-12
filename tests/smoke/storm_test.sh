#!/usr/bin/env bash
# Storm smoke test: the storm pinned over crew 1's ship, one sailor aboard. Lightning should
# strike her within the minute, holing the hull, and nothing should error.
#
#   tests/smoke/storm_test.sh            (needs `godot` on PATH, or set GODOT=/path/to/godot)
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PORT="${PORT:-24720}"
RUN_FOR="${RUN_FOR:-70}"
LOGS="$(mktemp -d)"
trap 'rm -rf "$LOGS"' EXIT
run() { "$GODOT" --headless --path "$ROOT" -- "$@"; }

run --server --at-sea --no-save --no-ai --storm 0,0 --port "$PORT" --quit-after "$((RUN_FOR + 6))" >"$LOGS/server.log" 2>&1 &
server=$!
sleep 2
run --bot sails --port "$PORT" --quit-after "$RUN_FOR" >"$LOGS/bot.log" 2>&1 &
bot=$!
wait "$bot" || true
wait "$server" || true

fail=0
check() {
	if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi
}
field() { grep '^RESULT server' "$1" | sed -n "s/.* $2=\([^ ]*\).*/\1/p"; }
check "lightning struck the ship ($(field "$LOGS/server.log" lightning))" '[ "$(field "$LOGS/server.log" lightning)" -ge 1 ]'
check "the crew were told" 'grep -q "Lightning strikes the mainmast" "$LOGS/bot.log"'
check "the bot still sees the ship" 'grep -q "snapshots_ok=true" "$LOGS/bot.log"'
check "no script errors" '! grep -l "SCRIPT ERROR" "$LOGS"/*.log'
if [ "$fail" -ne 0 ]; then
	for log in "$LOGS"/*.log; do echo "----- $log"; grep -v "phase=" "$log" | tail -15; done
fi
exit "$fail"
