#!/usr/bin/env bash
# Act IV smoke test (milestone 11), runs side by side, each a headless server and a bot.
#  1. Alongside the prison hulk on The Prison Hulk: the bot boards her, fells the jailer and
#     opens Isabel's cage.
#  2. Off the West Stack on Lanterns of the Deep: the bot goes ashore and shoots the lantern.
#  3. At the Black Reef at the battle's end: the bot boards the crippled Cuervo Negro and
#     fights the Raven Admiral.
#
#   tests/smoke/act4_test.sh            (needs `godot` on PATH, or set GODOT=/path/to/godot)
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PORT="${PORT:-25040}"
RUN_FOR="${RUN_FOR:-150}"
LOGS="$(mktemp -d)"
trap 'rm -rf "$LOGS"' EXIT
run() { "$GODOT" --headless --path "$ROOT" -- "$@"; }
QUIT=$((RUN_FOR + 6))

run --server --no-save --calm --no-ai --start-near hulk --chapter d1 --port "$PORT" --quit-after "$QUIT" >"$LOGS/hulk.log" 2>&1 &
run --server --no-save --calm --no-ai --start-near 7 --chapter d4 --port "$((PORT + 1))" --quit-after "$QUIT" >"$LOGS/lanterns.log" 2>&1 &
run --server --no-save --calm --no-ai --start-near reef --chapter d6 --chapter-step 2 --port "$((PORT + 2))" --quit-after "$QUIT" >"$LOGS/duel.log" 2>&1 &
sleep 2
run --bot sneak --port "$PORT" --quit-after "$RUN_FOR" >"$LOGS/hulk_bot.log" 2>&1 &
run --bot lanterns --port "$((PORT + 1))" --quit-after "$RUN_FOR" >"$LOGS/lanterns_bot.log" 2>&1 &
run --bot duel --port "$((PORT + 2))" --quit-after "$RUN_FOR" >"$LOGS/duel_bot.log" 2>&1 &
wait

fail=0
check() {
	if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi
}
check "the jailer was felled" 'grep -q "the jailer has fallen" "$LOGS/hulk.log"'
check "Isabel was freed from the hulk" 'grep -q "freed Isabel from the hulk" "$LOGS/hulk.log"'
check "a lantern of the deep was smashed" 'grep -q "a lantern of the deep was smashed" "$LOGS/lanterns.log"'
check "the Raven Admiral was wounded" 'grep -q "the Raven Admiral is wounded" "$LOGS/duel.log"'
check "no corrections" '! grep -h "RESULT server" "$LOGS"/*.log | grep -qv "corrections=0"'
check "no script errors" '! grep -l "SCRIPT ERROR" "$LOGS"/*.log'
if [ "$fail" -ne 0 ]; then
	for log in "$LOGS"/*.log; do echo "----- $log"; grep -v "phase=" "$log" | tail -20; done
fi
exit "$fail"
