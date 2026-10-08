#!/usr/bin/env bash
# Export the Windows client, the macOS client (universal: Intel and Apple Silicon, ad-hoc
# signed) and the Linux dedicated server into build/.
# Needs Godot 4.7.2 on PATH (or GODOT=...) with its export templates installed
# (Editor > Manage Export Templates, or unpack the .tpz into
# ~/.local/share/godot/export_templates/4.7.2.stable/).
set -euo pipefail
GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/build/windows" "$ROOT/build/mac" "$ROOT/build/server"
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$ROOT" --export-release "Windows" "$ROOT/build/windows/PirateGame.exe"
"$GODOT" --headless --path "$ROOT" --export-release "macOS" "$ROOT/build/mac/PirateGame-macos.zip"
"$GODOT" --headless --path "$ROOT" --export-release "Linux Server" "$ROOT/build/server/pirate-game-server.x86_64"
# A zip of the Windows build, ready to hand to friends.
rm -f "$ROOT/build/PirateGame-windows.zip"
(cd "$ROOT/build/windows" && zip -q -9 ../PirateGame-windows.zip PirateGame.exe)
ls -la "$ROOT/build/windows" "$ROOT/build/mac" "$ROOT/build/server" "$ROOT/build/PirateGame-windows.zip"
