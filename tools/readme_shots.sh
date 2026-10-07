#!/usr/bin/env bash
# Retake every screenshot in the README (docs/screenshots/), one after another.
#   tools/readme_shots.sh            all of them
#   tools/readme_shots.sh tavern     just the named ones
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/docs/screenshots"
shot() {
	local name="$1"
	shift
	if [ ${#WANT[@]} -gt 0 ] && [[ ! " ${WANT[*]} " =~ " $name " ]]; then return; fi
	echo "== $name"
	"$ROOT/tools/screenshot.sh" "$OUT/$name.png" "$@" | grep -E "SCRIPT ERROR|saved" || true
}
WANT=("$@")
DELAY=8 shot title title --time 0.765
DELAY=10 shot ship-under-sail outside --demo --time 0.42 --calm
DELAY=10 shot at-the-wheel wheel --demo --time 0.42 --calm
BOTS="sails wheel anchor" DELAY=16 shot crew-and-island deck --time 0.42 --calm --shot-yaw 0.35
DELAY=10 shot island island --time 0.42 --calm
DELAY=26 shot skeleton-ship enemy --demo --ai-delay 1 --time 0.42 --calm
DELAY=10 shot lower-deck patch --test-holes 2 --time 0.42 --calm
DELAY=10 shot outpost outpost --time 0.42 --calm
DELAY=10 shot treasure-map map --time 0.42 --calm
DELAY=14 shot skeletons fight --time 0.42 --calm
DELAY=14 shot two-crews high --crews-close --demo --time 0.45 --calm
DELAY=10 shot sunset outside --demo --time 0.79 --calm
DELAY=10 shot night outside --demo --time 0.97 --calm
DELAY=10 shot storm deck --time 0.42 --storm 0,-450 --shot-yaw 0.0
DELAY=12 shot in-the-storm outside --demo --time 0.42 --storm 0,0
DELAY=10 shot lighthouse-night lighthouse --time 0.97 --calm
DELAY=10 shot gull-isle-arch island2 --time 0.42 --calm
DELAY=10 shot tavern tavern --time 0.42 --calm
