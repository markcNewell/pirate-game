#!/usr/bin/env bash
# Rebuild Blender models: runs each asset script in art/blender/ headless, writing
# art/models/*.glb. Needs Blender 5.2 on the PATH (or BLENDER=/path/to/blender).
#
#   tools/build_models.sh                 every script
#   tools/build_models.sh props           one script (all its models)
#   tools/build_models.sh props barrel    one script, named models only
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BLENDER="${BLENDER:-blender}"
# Keep heavy work off the workstation's faulty core (CPUs 8 and 9) when it is that machine.
PIN=()
if command -v taskset >/dev/null && [ "$(nproc)" -ge 32 ]; then PIN=(taskset -c 0-7,10-31); fi
scripts=("$@")
if [ ${#scripts[@]} -eq 0 ]; then
	# Every asset script; kit.py, rig.py and shipshape.py are shared libraries, not assets.
	mapfile -t scripts < <(cd "$ROOT/art/blender" && ls ./*.py | grep -vE "/(kit|rig|shipshape)\.py$" | sed 's|^\./||; s|\.py$||')
	names=()
else
	names=("${scripts[@]:1}")
	scripts=("${scripts[0]}")
fi
status=0
for s in "${scripts[@]}"; do
	out="$("${PIN[@]}" "$BLENDER" -b --factory-startup --python "$ROOT/art/blender/$s.py" -- "${names[@]}" 2>&1)" || status=1
	grep -E "EXPORTED|Error|Traceback|File \"" <<<"$out" | grep -v HIPEW || true
	grep -q Traceback <<<"$out" && status=1
done
# The game only picks up changed models once Godot has imported them again.
"${GODOT:-godot}" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
exit "$status"
