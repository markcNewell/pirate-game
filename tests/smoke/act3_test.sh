#!/usr/bin/env bash
# Act III smoke test (milestone 10), runs side by side, each a headless server and a bot.
#  1. Off Port Merrow on Ashes on the Wind: the bot fills a bucket, climbs the lighthouse,
#     douses the green fire in the lamp, then carries the lamp oil up.
#  2. Off Port Merrow at the siege: the bot stands by Merrow's battery while it fires on the
#     galleons.
#  3. Off Port Merrow at La Viuda: the bot shoots her down from its own deck.
#
#   tests/smoke/act3_test.sh            (needs `godot` on PATH, or set GODOT=/path/to/godot)
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PORT="${PORT:-25030}"
RUN_FOR="${RUN_FOR:-150}"
LOGS="$(mktemp -d)"
trap 'rm -rf "$LOGS"' EXIT
run() { "$GODOT" --headless --path "$ROOT" -- "$@"; }
QUIT=$((RUN_FOR + 6))

run --server --at-sea --no-save --calm --no-ai --start-near outpost --chapter c1 --port "$PORT" --quit-after "$QUIT" >"$LOGS/lamp.log" 2>&1 &
run --server --at-sea --no-save --calm --no-ai --start-near outpost --chapter c6 --port "$((PORT + 1))" --quit-after "$QUIT" >"$LOGS/battery.log" 2>&1 &
run --server --at-sea --no-save --calm --no-ai --start-near outpost --chapter c6 --chapter-step 2 --port "$((PORT + 2))" --quit-after "$QUIT" >"$LOGS/viuda.log" 2>&1 &
sleep 2
run --bot keeper --port "$PORT" --quit-after "$RUN_FOR" >"$LOGS/lamp_bot.log" 2>&1 &
run --bot battery --port "$((PORT + 1))" --quit-after "$RUN_FOR" >"$LOGS/battery_bot.log" 2>&1 &
run --bot viuda --port "$((PORT + 2))" --quit-after "$RUN_FOR" >"$LOGS/viuda_bot.log" 2>&1 &
wait

fail=0
check() {
	if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi
}
check "the lighthouse was climbed" 'grep -q "climbed the lighthouse" "$LOGS/lamp.log"'
check "the green fire in the lamp was doused" 'grep -q "doused a green fire" "$LOGS/lamp.log"'
check "the lamp burns true" 'grep -q "finished chapter c1" "$LOGS/lamp.log"'
check "Merrow's battery fired" 'grep -q "battery opened fire" "$LOGS/battery.log"'
check "La Viuda was shot down" 'grep -q "La Viuda has fallen" "$LOGS/viuda.log"'
check "no corrections" '! grep -h "RESULT server" "$LOGS"/*.log | grep -qv "corrections=0"'
check "no script errors" '! grep -l "SCRIPT ERROR" "$LOGS"/*.log'
if [ "$fail" -ne 0 ]; then
	for log in "$LOGS"/*.log; do echo "----- $log"; grep -v "phase=" "$log" | tail -20; grep "phase=" "$log" | tail -3; done
fi
exit "$fail"
