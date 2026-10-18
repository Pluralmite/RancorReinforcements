#!/bin/bash
# Full offline check of the dev script and its release copy. Usage: ./check.sh [dev_script] [fights]
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DEV="${1:-/home/claude/RancorReinforcements_v1.lua}"
FIGHTS="${2:-300}"
REL="$HERE/out/RancorReinforcements_release.lua"
mkdir -p "$HERE/out"
status=0
echo "=== 1. dev build ==="
python3 "$HERE/run_harness.py" "$DEV" --json "$HERE/out/dev.json" || status=1
echo; echo "=== 2. release build ==="
python3 "$HERE/make_release.py" "$DEV" "$REL" && python3 "$HERE/run_harness.py" "$REL" --release --json "$HERE/out/release.json" || status=1
echo; echo "=== 3. simulated Rancor fights (dev build, your config) ==="
python3 "$HERE/run_sim.py" "$DEV" --fights "$FIGHTS" --config "$HERE/configs/current.json" --json "$HERE/out/sim.json" || status=1
exit $status
