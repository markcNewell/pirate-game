#!/usr/bin/env bash
# Combat smoke test (milestone 2), in two parts, each a headless server plus bot players.
#  1. A fight: a skeleton ship arrives at once; two gunner bots shoot back and a repair bot
#     patches holes and bails. Passes when cannonballs fly, hit both ships, holes get patched
#     and the skeleton ship takes damage.
#  2. A sinking: the crew's ship starts holed with nobody bailing. Passes when it sinks,
#     comes back, and the bot ends up on deck again.
#
#   tests/smoke/combat_test.sh            (needs `godot` on PATH, or set GODOT=/path/to/godot)
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PORT="${PORT:-24692}"
LOGS="$(mktemp -d)"
trap 'rm -rf "$LOGS"' EXIT
run() { "$GODOT" --headless --path "$ROOT" -- "$@"; }

fail=0
check() {
	if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi
}
field() { sed -n "s/.* $1=\([^ ]*\).*/\1/p" <<<"$2"; }

# --- 1. the fight ---
FIGHT=150
run --server --no-save --calm --ai-delay 3 --port "$PORT" --quit-after "$((FIGHT + 6))" >"$LOGS/fight.log" 2>&1 &
server=$!
sleep 2
bots=()
for role in gunner gunner repair; do
	run --bot "$role" --port "$PORT" --quit-after "$FIGHT" >"$LOGS/fight_bot_$role$RANDOM.log" 2>&1 &
	bots+=($!)
done
for pid in "${bots[@]}"; do wait "$pid" || true; done
wait "$server" || true
r="$(grep '^RESULT server' "$LOGS/fight.log" || true)"
skel_holes="$( (grep -o 'skeleton[0-9]*=([^)]*holes [0-9]*' "$LOGS/fight.log" || true) | sed 's/.*holes //' | sort -n | tail -1)"
check "a skeleton ship came ($(field ai_spawned "$r"))" '[ "$(field ai_spawned "$r")" -ge 1 ]'
check "cannons fired ($(field shots "$r") shots)" '[ "$(field shots "$r")" -ge 10 ]'
check "hulls were holed ($(field holes "$r"))" '[ "$(field holes "$r")" -ge 3 ]'
check "holes were patched ($(field patched "$r"))" '[ "$(field patched "$r")" -ge 1 ]'
check "the skeleton ship was hit (most holes ${skel_holes:-0}, sunk $(field ai_sunk "$r"))" \
	'[ "${skel_holes:-0}" -ge 1 ] || [ "$(field ai_sunk "$r")" -ge 1 ]'
check "a sunk skeleton ship leaves loot" \
	'[ "$(field ai_sunk "$r")" -eq 0 ] || [ "$(field loot_spawned "$r")" -ge 3 ]'

# --- 2. the sinking ---
SINK=70
run --server --no-save --calm --no-ai --test-holes 6 --port "$((PORT + 1))" --quit-after "$((SINK + 4))" >"$LOGS/sink.log" 2>&1 &
server=$!
sleep 2
run --bot anchor --port "$((PORT + 1))" --quit-after "$SINK" >"$LOGS/sink_bot.log" 2>&1 || true
wait "$server" || true
r="$(grep '^RESULT server' "$LOGS/sink.log" || true)"
check "the holed ship sank ($(field crew_sunk "$r"))" '[ "$(field crew_sunk "$r")" -ge 1 ]'
check "the ship came back" 'grep -q "the crew.s ship is back" "$LOGS/sink.log"'
check "the bot ended up back on deck" 'grep -q "RESULT client.*active=true mode=0" "$LOGS/sink_bot.log"'

check "no script errors" '! grep -l "SCRIPT ERROR" "$LOGS"/*.log'
if [ "$fail" -ne 0 ]; then
	for log in "$LOGS"/*.log; do echo "----- $log"; grep -v "phase=" "$log" | tail -20; grep "phase=" "$log" | tail -3; done
fi
exit "$fail"
