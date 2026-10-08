#!/usr/bin/env bash
# Act I smoke test (milestone 8), runs side by side, each a headless server and a bot.
#  1. Off Gull Isle on Salt the Earth with the salt aboard: the bot carries a crate ashore and
#     salts a grave.
#  2. Off Cutlass Cay on Captain Coco's Warning: the bot finds the powder store and shoots a keg.
#  3. Off Cutlass Cay on Dig Faster: the bot fights the Spanish diggers.
#  4. Off Cutlass Cay on The Sergeant's Camp: the bot fills a bucket and throws it on the bonfire.
#
#   tests/smoke/act1_test.sh            (needs `godot` on PATH, or set GODOT=/path/to/godot)
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PORT="${PORT:-24960}"
RUN_FOR="${RUN_FOR:-150}"
LOGS="$(mktemp -d)"
trap 'rm -rf "$LOGS"' EXIT
run() { "$GODOT" --headless --path "$ROOT" -- "$@"; }
QUIT=$((RUN_FOR + 6))

run --server --no-save --calm --no-ai --start-near 2 --chapter a2 --chapter-aboard --port "$PORT" --quit-after "$QUIT" >"$LOGS/salt.log" 2>&1 &
run --server --no-save --calm --no-ai --start-near 0 --chapter a3 --port "$((PORT + 1))" --quit-after "$QUIT" >"$LOGS/kegs.log" 2>&1 &
run --server --no-save --calm --no-ai --start-near 0 --chapter a1 --port "$((PORT + 2))" --quit-after "$QUIT" >"$LOGS/dig.log" 2>&1 &
run --server --no-save --calm --no-ai --start-near 0 --chapter a6 --port "$((PORT + 3))" --quit-after "$QUIT" >"$LOGS/camp.log" 2>&1 &
sleep 2
run --bot salter --port "$PORT" --quit-after "$RUN_FOR" >"$LOGS/salt_bot.log" 2>&1 &
run --bot kegs --port "$((PORT + 1))" --quit-after "$RUN_FOR" >"$LOGS/kegs_bot.log" 2>&1 &
run --bot fighter --port "$((PORT + 2))" --quit-after "$RUN_FOR" >"$LOGS/dig_bot.log" 2>&1 &
run --bot lights --port "$((PORT + 3))" --quit-after "$RUN_FOR" >"$LOGS/camp_bot.log" 2>&1 &
wait

fail=0
check() {
	if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi
}
field() { grep -h "RESULT server" "$1" | tr ' ' '\n' | grep "^$2=" | cut -d= -f2; }
check "a salt crate was carried ashore" 'grep -q "picked up a salt crate" "$LOGS/salt_bot.log"'
check "and a grave salted" 'grep -q "salted a grave" "$LOGS/salt.log"'
check "a powder keg was shot" 'grep -q "a powder keg exploded" "$LOGS/kegs.log"'
check "the Spanish diggers landed" 'grep -q "began chapter a1" "$LOGS/dig.log"'
check "and were fought ($(field "$LOGS/dig.log" kills) felled)" '[ "$(field "$LOGS/dig.log" kills)" -ge 1 ]'
check "the bonfire took a bucket" 'grep -q "doused a green fire" "$LOGS/camp.log"'
check "no corrections" '! grep -h "RESULT server" "$LOGS"/*.log | grep -qv "corrections=0"'
check "no script errors" '! grep -l "SCRIPT ERROR" "$LOGS"/*.log'
if [ "$fail" -ne 0 ]; then
	for log in "$LOGS"/*.log; do echo "----- $log"; grep -v "phase=" "$log" | tail -20; done
fi
exit "$fail"
