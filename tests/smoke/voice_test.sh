#!/usr/bin/env bash
# Voice smoke test (milestone 25): a dedicated server, a bot on crew 1's ship "speaking" a tone
# through the real packing and network path (--voice-tone), a crew-mate on the same deck and a
# bot on crew 2's ship, which starts some 200 m away. The crew-mate must hear the speaker; the
# far bot must hear nothing; and the server must have passed voice on.
#
#   tests/smoke/voice_test.sh            (needs `godot` on PATH, or set GODOT=/path/to/godot)
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PORT="${PORT:-24900}"
RUN_FOR="${RUN_FOR:-30}"
LOGS="$(mktemp -d)"
trap 'rm -rf "$LOGS"' EXIT

run() { "$GODOT" --headless --path "$ROOT" -- "$@"; }

run --server --at-sea --no-save --calm --no-ai --port "$PORT" --quit-after "$((RUN_FOR + 6))" >"$LOGS/server.log" 2>&1 &
server=$!
sleep 2
bots=()
run --bot wheel --crew 1 --voice-tone --port "$PORT" --quit-after "$RUN_FOR" >"$LOGS/speaker.log" 2>&1 &
bots+=($!)
run --bot anchor --crew 1 --port "$PORT" --quit-after "$RUN_FOR" >"$LOGS/near.log" 2>&1 &
bots+=($!)
run --bot wheel --crew 2 --port "$PORT" --quit-after "$RUN_FOR" >"$LOGS/far.log" 2>&1 &
bots+=($!)
for pid in "${bots[@]}"; do wait "$pid" || true; done
wait "$server" || true

fail=0
check() {
	if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi
}
client() { grep '^RESULT client' "$1" | sed -n "s/.* $2=\([^ ]*\).*/\1/p"; }
server() { grep '^RESULT server' "$LOGS/server.log" | sed -n "s/.* $1=\([^ ]*\).*/\1/p"; }
sent="$(client "$LOGS/speaker.log" voice_sent)"
near="$(client "$LOGS/near.log" voice_heard)"
far="$(client "$LOGS/far.log" voice_heard)"
passed="$(server voice)"

check "the speaker sent voice (${sent:-none} packets)" '[ "${sent:-0}" -ge 100 ]'
check "the server passed it on (${passed:-none})" '[ "${passed:-0}" -ge 100 ]'
check "the crew-mate on deck heard it (${near:-none})" '[ "${near:-0}" -ge 100 ] && grep -q "\[voice\] hearing Bot wheel 1" "$LOGS/near.log"'
check "the far ship heard nothing (${far:-none})" '[ "${far:-x}" = "0" ] && ! grep -q "\[voice\] hearing" "$LOGS/far.log"'
check "the speaker did not hear itself" '! grep -q "\[voice\] hearing" "$LOGS/speaker.log"'
check "no script errors" '! grep -l "SCRIPT ERROR" "$LOGS"/*.log'
if [ "$fail" -ne 0 ]; then
	for log in "$LOGS"/*.log; do echo "----- $log"; grep -v "phase=" "$log" | tail -15; done
fi
exit "$fail"
