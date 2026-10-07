#!/usr/bin/env bash
# Render the game without a monitor: runs Godot in a container with a virtual display and
# software OpenGL, hosts a local game and saves a screenshot.
#
#   tools/screenshot.sh OUT.png [VIEW] [EXTRA ARGS...]
#   VIEW: deck (first person, default), wheel, outside, bow, high, island[N], lighthouse, tavern, stern
#   e.g. tools/screenshot.sh /tmp/shot.png outside --demo
#   BOTS="sails wheel" adds headless bot players to the hosted game first.
#
# Needs podman (or ENGINE=docker) and the render image, built once with:
#   podman build -t pirate-render -f tools/render.Containerfile tools
set -euo pipefail
OUT="$(realpath -m "$1")"
VIEW="${2:-deck}"
shift $(( $# >= 2 ? 2 : 1 ))
ENGINE="${ENGINE:-podman}"
GODOT_BIN="${GODOT_BIN:-$(readlink -f "$(command -v godot)")}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SIZE="${SIZE:-1280x720}"
mkdir -p "$(dirname "$OUT")"
# shellcheck disable=SC2016
"$ENGINE" run --rm \
	-v "$ROOT:/game:Z" -v "$GODOT_BIN:/usr/local/bin/godot:ro,Z" -v "$(dirname "$OUT"):/out:Z" \
	pirate-render bash -c '
		Xvfb :5 -screen 0 '"${SIZE}"'x24 >/dev/null 2>&1 &
		sleep 2
		( sleep 4; for role in '"${BOTS:-}"'; do
			timeout 150 godot --headless --path /game -- --bot "$role" >/dev/null 2>&1 &
		done ) &
		DISPLAY=:5 timeout 150 godot --path /game --rendering-driver opengl3 --resolution '"$SIZE"' -- "$@"
	' _ --host --name Mark --screenshot "/out/$(basename "$OUT")" --shot-view "$VIEW" --shot-delay "${DELAY:-6}" "$@" \
	2>&1 | grep -E "screenshot|SCRIPT ERROR|ERROR" | grep -vE "audio|ALSA|init_output_device" || true
