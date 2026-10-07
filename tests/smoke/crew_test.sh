#!/usr/bin/env bash
# Crew-vs-crew smoke test (milestone 5): three servers side by side, each with two crews whose
# ships start close together and no skeletons.
#  1. Duel: one bot from each crew jumps in and fights the other.
#  2. Broadsides: a gunner bot in each crew shoots at the other crew's ship.
#  3. Theft: a bot of crew 1 steals the chest on crew 2's deck and stows it on its own ship.
#
#   tests/smoke/crew_test.sh            (needs `godot` on PATH, or set GODOT=/path/to/godot)
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PORT="${PORT:-24710}"
RUN_FOR="${RUN_FOR:-100}"
LOGS="$(mktemp -d)"
trap 'rm -rf "$LOGS"' EXIT
run() { "$GODOT" --headless --path "$ROOT" -- "$@"; }

servers=()
run --server --no-ai --crews-close --port "$PORT" --quit-after "$((RUN_FOR + 6))" >"$LOGS/duel.log" 2>&1 &
servers+=($!)
run --server --no-ai --crews-close --port "$((PORT + 1))" --quit-after "$((RUN_FOR + 6))" >"$LOGS/guns.log" 2>&1 &
servers+=($!)
run --server --no-ai --crews-close --test-steal --port "$((PORT + 2))" --quit-after "$((RUN_FOR + 6))" >"$LOGS/theft.log" 2>&1 &
servers+=($!)
sleep 2
bots=()
for crew in 1 2; do
	run --bot duelist --crew "$crew" --port "$PORT" --quit-after "$RUN_FOR" >"$LOGS/duel_bot_$crew.log" 2>&1 &
	bots+=($!)
	run --bot gunner --crew "$crew" --port "$((PORT + 1))" --quit-after "$RUN_FOR" >"$LOGS/guns_bot_$crew.log" 2>&1 &
	bots+=($!)
done
run --bot thief --crew 1 --port "$((PORT + 2))" --quit-after "$RUN_FOR" >"$LOGS/theft_bot.log" 2>&1 &
bots+=($!)
for pid in "${bots[@]}" "${servers[@]}"; do wait "$pid" || true; done

fail=0
check() {
	if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi
}
field() { grep '^RESULT server' "$1" | sed -n "s/.* $2=\([^ ]*\).*/\1/p"; }
check "players landed on two crews" 'grep -q "joined crew 1" "$LOGS/duel.log" && grep -q "joined crew 2" "$LOGS/duel.log"'
check "the duel felled someone ($(field "$LOGS/duel.log" pvp_falls))" '[ "$(field "$LOGS/duel.log" pvp_falls)" -ge 1 ]'
check "both ships were holed" 'grep -q "We.re hit" "$LOGS/guns_bot_1.log" && grep -q "We.re hit" "$LOGS/guns_bot_2.log"'
check "the chest was stolen" 'grep -q "stole a" "$LOGS/theft.log"'
check "and stowed aboard ship 1" 'grep -q "stowed a .* aboard ship 1" "$LOGS/theft.log"'
check "no script errors" '! grep -l "SCRIPT ERROR" "$LOGS"/*.log'
if [ "$fail" -ne 0 ]; then
	for log in "$LOGS"/*.log; do echo "----- $log"; grep -v "phase=" "$log" | tail -15; done
fi
exit "$fail"
