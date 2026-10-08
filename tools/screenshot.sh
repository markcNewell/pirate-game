#!/usr/bin/env bash
# Render the game without a monitor: runs Godot in a container with a virtual display and
# software OpenGL, hosts a local game and saves a screenshot.
#
#   tools/screenshot.sh OUT.png [VIEW] [EXTRA ARGS...]
#   VIEW: deck (first person, default), wheel, outside, bow, high, crew, island[N], lighthouse, tavern, stern, swim, flag, ghost, swing, patch, help, mouselook,
#         board, bounty, cargo, trader (missions: --voyage-island N picks the island),
#         moll (talking to her), fire (with --chapter p1 --chapter-step 1), thieves (with --chapter p2),
#         diggers (a1), graves (a2), store (a3), galleon (a4), camp (a6), sergeant (a6, step 1),
#         gallery (c1), cannons (c2), battery (c6), viuda (c6, step 2), ocaso (c6, step 3),
#         linnet (t10, with --time 0.9), hulk (d1), carving (d2), ghost (d3), lanterns (d4),
#         golondrina (d5), admiral (d6, step 2), workshop (e2, step 1), beacon (e3, step 1),
#         colossus (e5), anvil (e5, step 1), deeds, worldmark (a world event on the compass),
#         hobb (his counter), refit, trophies, figurehead (a refitted ship with every trophy),
#         crew with --armour 1 or 2 (crewmates in armour; BOTS="sails wheel anchor"), fortport,
#         title (the title screen: nothing is hosted), ship (--shot-from X,Y,Z --shot-look X,Y,Z in the ship's frame)
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
	' _ $([ "$VIEW" = title ] || echo --host) --name Mark --screenshot "/out/$(basename "$OUT")" --shot-view "$VIEW" --shot-delay "${DELAY:-6}" "$@" \
	2>&1 | grep -E "screenshot|SCRIPT ERROR|ERROR" | grep -vE "audio|ALSA|init_output_device" || true
