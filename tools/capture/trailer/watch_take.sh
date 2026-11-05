#!/usr/bin/env bash
# watch_take.sh <label> <capture task output file>: stream a capture's marks,
# failures and errors; exit when its engine is gone or the pre-flight failed.
B=/home/user/Nauris/Synthetic-Ascension/.superpowers/claude-city-20261021/runs
label=$1; out=$2
while :; do
  RUN=$(ls -d $B/$label-[0-9]*-1 2>/dev/null | head -1)
  [ -n "$RUN" ] && break
  if grep -q 'PREFLIGHT FAILED' "$out" 2>/dev/null; then grep -A8 'PREFLIGHT FAILED' "$out"; exit 0; fi
  sleep 3
done
echo "native run started: $(basename $RUN)"
tail -n +1 -F $RUN/logs/stdout.log $RUN/logs/stderr.log 2>/dev/null \
  | grep --line-buffered -E 'TrailerMark|TrailerDirector|SCRIPT ERROR|Parse Error|recorded in|TrailerPace frame=[0-9]*(00|50)0 ' &
TP=$!
sleep 20
while ps -eo args | grep -qE "^/home/user/Downloads/Godot_v4[^ ]* --path /var/tmp/sa-trailer --log-file $RUN/"; do sleep 5; done
sleep 3; kill $TP 2>/dev/null; echo "engine exited ($(basename $RUN))"
