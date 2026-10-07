#!/usr/bin/env bash
# A contact sheet of one Blender model, rendered by the game itself (its toon light and ink),
# without a monitor: the model from several sides, or an animation's poses.
#
#   tools/model_sheet.sh OUT.png MODEL [EXTRA ARGS...]
#   e.g. tools/model_sheet.sh /tmp/pirate.png pirate --sheet-recolor 1
#        tools/model_sheet.sh /tmp/walk.png pirate --sheet-anim walk --sheet-frames 8
#        tools/model_sheet.sh /tmp/head.png pirate --sheet-focus 1.4,2.1
# Options are listed at the top of game/dev/model_sheet.gd. Uses the same container as
# tools/screenshot.sh.
set -euo pipefail
OUT="$(realpath -m "$1")"
MODEL="$2"
shift 2
ENGINE="${ENGINE:-podman}"
GODOT_BIN="${GODOT_BIN:-$(readlink -f "$(command -v godot)")}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SIZE="${SIZE:-1600x900}"
mkdir -p "$(dirname "$OUT")"
"$ENGINE" run --rm \
	-v "$ROOT:/game:Z" -v "$GODOT_BIN:/usr/local/bin/godot:ro,Z" -v "$(dirname "$OUT"):/out:Z" \
	pirate-render bash -c '
		Xvfb :5 -screen 0 '"${SIZE}"'x24 >/dev/null 2>&1 &
		sleep 1
		DISPLAY=:5 timeout 120 godot --path /game --rendering-driver opengl3 --resolution '"$SIZE"' -- "$@"
	' _ --model-sheet "$MODEL" --screenshot "/out/$(basename "$OUT")" "$@" \
	2>&1 | grep -E "sheet saved|SCRIPT ERROR|ERROR|at: " | grep -vE "audio|ALSA|init_output_device" || true
