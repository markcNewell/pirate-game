#!/usr/bin/env bash
# Bot smoke test: a headless dedicated server plus four bot players in separate processes.
# The bots walk to the anchor, the main sails and the wheel, and one jumps overboard and climbs
# back up a ladder. Passes when the ship sails and turns, every job was taken, the swimmer got
# back aboard, nobody needed correcting, every bot saw snapshots, and no script errors appeared.
#
#   tests/smoke/smoke_test.sh            (needs `godot` on PATH, or set GODOT=/path/to/godot)
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PORT="${PORT:-24690}"
RUN_FOR="${RUN_FOR:-45}"
LOGS="$(mktemp -d)"
trap 'rm -rf "$LOGS"' EXIT

run() { "$GODOT" --headless --path "$ROOT" -- "$@"; }

run --server --no-ai --port "$PORT" --quit-after "$((RUN_FOR + 6))" >"$LOGS/server.log" 2>&1 &
server=$!
sleep 2
bots=()
for role in anchor sails wheel swimmer; do
	run --bot "$role" --port "$PORT" --quit-after "$RUN_FOR" >"$LOGS/bot_$role.log" 2>&1 &
	bots+=($!)
done
for pid in "${bots[@]}"; do wait "$pid" || true; done
wait "$server" || true

fail=0
check() {
	if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi
}
result="$(grep '^RESULT server' "$LOGS/server.log" || true)"
field() { sed -n "s/.* $1=\([^ ]*\).*/\1/p" <<<"$result"; }
final_x="$(grep '^\[server\] t=' "$LOGS/server.log" | tail -1 | sed -n 's/.*ship=(\([-0-9.]*\),.*/\1/p')"

check "server printed a result" '[ -n "$result" ]'
check "ship sailed more than 50 m (moved=$(field moved))" 'awk "BEGIN{exit !($(field moved) > 50)}"'
check "wheel turned the ship to starboard (x=$final_x)" 'awk "BEGIN{exit !(${final_x:-0} > 2)}"'
check "three stations taken ($(field stations_taken))" '[ "$(field stations_taken)" -ge 3 ]'
check "swimmer climbed back aboard ($(field climbs))" '[ "$(field climbs)" -ge 1 ]'
check "no corrections ($(field corrections))" '[ "$(field corrections)" -eq 0 ]'
for role in anchor sails wheel swimmer; do
	check "bot $role saw snapshots" 'grep -q "RESULT client.*active=true.*snapshots_ok=true" "$LOGS/bot_$role.log"'
done
check "no script errors" '! grep -l "SCRIPT ERROR" "$LOGS"/*.log'

if [ "$fail" -ne 0 ]; then
	for log in "$LOGS"/*.log; do echo "----- $log"; tail -25 "$log"; done
fi
exit "$fail"
