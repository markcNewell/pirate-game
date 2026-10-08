#!/usr/bin/env bash
# Story smoke test (milestone 7), runs side by side, each a headless server and a bot.
#  1. Off Gull Isle on chapter P1: the bot swims ashore, reads the journal, fills a bucket in
#     the sea, douses the green fire and fells the Spanish dead that climb out.
#  2. Off Port Merrow at P1's last step: the bot swims ashore and tells Moll; the chapter ends.
#  3. Off Parrot Rock on chapter P2: the bot beats Black-Eyed Bess and gets her skull aboard,
#     with the Spanish thieves after it.
#  4. A pirate is remembered: a bot sells a skull on a server keeping profiles in a folder; a
#     second server on the same folder tells the bot it has that gold.
#
#   tests/smoke/story_test.sh            (needs `godot` on PATH, or set GODOT=/path/to/godot)
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PORT="${PORT:-24900}"
RUN_FOR="${RUN_FOR:-150}"
LOGS="$(mktemp -d)"
trap 'rm -rf "$LOGS"' EXIT
run() { "$GODOT" --headless --path "$ROOT" -- "$@"; }
QUIT=$((RUN_FOR + 6))

run --server --no-save --calm --no-ai --start-near 2 --chapter p1 --port "$PORT" --quit-after "$QUIT" >"$LOGS/lights.log" 2>&1 &
run --server --no-save --calm --no-ai --start-near outpost --chapter p1 --chapter-step 2 --port "$((PORT + 1))" --quit-after "$QUIT" >"$LOGS/moll.log" 2>&1 &
run --server --no-save --calm --no-ai --start-near 1 --chapter p2 --port "$((PORT + 2))" --quit-after "$QUIT" >"$LOGS/bess.log" 2>&1 &
run --server --profiles "$LOGS/profiles" --calm --no-ai --start-near outpost --test-skull --port "$((PORT + 3))" --quit-after 70 >"$LOGS/keep.log" 2>&1 &
sleep 2
run --bot lights --port "$PORT" --quit-after "$RUN_FOR" >"$LOGS/lights_bot.log" 2>&1 &
run --bot moll --port "$((PORT + 1))" --quit-after "$RUN_FOR" >"$LOGS/moll_bot.log" 2>&1 &
run --bot bounty --port "$((PORT + 2))" --quit-after "$RUN_FOR" >"$LOGS/bess_bot.log" 2>&1 &
run --bot seller --port "$((PORT + 3))" --quit-after 60 >"$LOGS/keep_bot.log" 2>&1 &
# The pirate's second visit, once the first server has written its profile and stopped.
(
	sleep 75
	run --server --profiles "$LOGS/profiles" --calm --no-ai --port "$((PORT + 4))" --quit-after 25 >"$LOGS/again.log" 2>&1 &
	sleep 2
	run --bot seller --port "$((PORT + 4))" --quit-after 15 >"$LOGS/again_bot.log" 2>&1
	wait
) &
wait

fail=0
check() {
	if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi
}
check "chapter P1 began on the server" 'grep -q "began chapter p1" "$LOGS/lights.log"'
check "the journal was read" 'grep -q "read A Spanish sailor.s journal" "$LOGS/lights.log"'
check "a bucket was filled in the sea" 'grep -q "filled the bucket" "$LOGS/lights_bot.log"'
check "the green fire was doused" 'grep -q "doused a green fire" "$LOGS/lights.log"'
check "and its dead were felled" 'grep -q "put out the green fire and beat its dead" "$LOGS/lights.log"'
check "Moll heard the news and the chapter ended" 'grep -q "finished chapter p1" "$LOGS/moll.log"'
check "with XP for it" 'grep -q "earned 300 XP for the chapter Strange Lights" "$LOGS/moll.log"'
check "Bess fell and dropped her skull" 'grep -q "Black-Eyed Bess has fallen; her skull" "$LOGS/bess.log"'
check "her skull was carried back aboard" 'grep -q "stowed the skull" "$LOGS/bess_bot.log"'
check "the skull was sold on the keeping server" 'grep -q "sold a captain.s skull for [0-9]* gold" "$LOGS/keep.log"'
check "the profile was written" '[ -f "$LOGS/profiles/bot_seller.json" ]'
check "the second server remembered the gold" 'grep -q "profile xp=[0-9]* gold=[1-9]" "$LOGS/again_bot.log"'
check "no corrections" '! grep -h "RESULT server" "$LOGS"/*.log | grep -qv "corrections=0"'
check "no script errors" '! grep -l "SCRIPT ERROR" "$LOGS"/*.log'
if [ "$fail" -ne 0 ]; then
	for log in "$LOGS"/*.log; do echo "----- $log"; grep -v "phase=" "$log" | tail -20; done
fi
exit "$fail"
