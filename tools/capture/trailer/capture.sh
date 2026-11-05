#!/usr/bin/env bash
# capture.sh <label> <scene res path> <movie path|-> <timeout s> [duty 10|25] [-- extra user args]
# Guarded native Movie Maker capture of the trailer worktree with movieclock.so.
set -u
G=/home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/guarded_engine.py
W=${PROJECT:-/var/tmp/sa-trailer}
label=$1; scene=$2; movie=$3; timeout=$4; duty=${5:-25}; shift 5 2>/dev/null || shift $#
[ "${1:-}" = "--" ] && shift
profile=/var/tmp/sa-trailer-takes/profile/$label
# Pre-flight: a headless load of the scene must parse cleanly, or a native
# Movie Maker run would record an empty window until its timeout.
pre=$(python3 $G --label "$label-parse-$(date +%H%M%S)" --project "$W" --timeout 120 --start-temperature 70 --duty-percent 25 -- --headless "$scene" -- --take=parse 2>&1)
pre_run=$(ls -dt /home/user/Nauris/Synthetic-Ascension/.superpowers/claude-city-20261021/runs/$label-parse-*-1 2>/dev/null | head -1)
if grep -qE 'SCRIPT ERROR|Parse Error|Failed to load script' "$pre_run/logs/stderr.log" "$pre_run/logs/stdout.log" 2>/dev/null; then
  echo "PREFLIGHT FAILED for $scene:"; grep -hE 'SCRIPT ERROR|Parse Error|Failed to load|at: ' "$pre_run/logs/stderr.log" | head -8; exit 3
fi
mkdir -p "$profile/data" "$profile/config"
args=(--rendering-driver opengl3)
[ "$movie" != "-" ] && { mkdir -p "$(dirname "$movie")"; args+=(--write-movie "$movie"); }
args+=("$scene")
[ $# -gt 0 ] && args+=(-- "$@")
LD_PRELOAD=${NOPRELOAD:+}${NOPRELOAD:-/var/tmp/sa-trailer-takes/movieclock.so} XDG_DATA_HOME=$profile/data XDG_CONFIG_HOME=$profile/config \
  python3 $G --label "$label-$(date +%H%M%S)" --project "$W" --timeout "$timeout" --start-temperature ${START_TEMP:-70} ${BURST:+--burst-temperature $BURST} --duty-percent "$duty" ${RELEASE:+--release-marker "$RELEASE"} -- "${args[@]}" 2>&1 \
  | grep -vE '^\s*$' | grep -E 'stop_reason|THERMAL|MovieClock|Trailer|SCRIPT ERROR|ERROR:|Parse Error|FAIL' | cut -c1-400 | head -40
