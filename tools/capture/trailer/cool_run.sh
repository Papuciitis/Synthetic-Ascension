#!/usr/bin/env bash
# cool_run.sh <command...>: run on 2 cores at low priority; pause its ffmpeg
# children while the CPU package is at or above 85 C, resume at 75 C.
temp() { for hw in /sys/class/hwmon/hwmon*; do [ "$(cat $hw/name)" = coretemp ] && for l in $hw/temp*_label; do [ "$(cat $l)" = "Package id 0" ] && echo $(( $(cat ${l%_label}_input)/1000 )); done; done; }
taskset -c ${CORES:-2,3} nice -n 15 "$@" &
job=$!; paused=0; peak=0; pauses=0
while kill -0 $job 2>/dev/null; do
  t=$(temp); [ "$t" -gt "$peak" ] && peak=$t
  if [ $paused = 0 ] && [ "$t" -ge ${HOT:-85} ]; then pkill -STOP -f '^/home/user/Nauris/Synthetic-Ascension/.superpowers/handoff-linux/video-tool/imageio_ffmpeg/binaries/ffmpeg' ; paused=1; pauses=$((pauses+1)); fi
  if [ $paused = 1 ] && [ "$t" -le ${COOL:-75} ]; then pkill -CONT -f '^/home/user/Nauris/Synthetic-Ascension/.superpowers/handoff-linux/video-tool/imageio_ffmpeg/binaries/ffmpeg'; paused=0; fi
  sleep 1
done
pkill -CONT -f '^/home/user/Nauris/Synthetic-Ascension/.superpowers/handoff-linux/video-tool/imageio_ffmpeg/binaries/ffmpeg' 2>/dev/null
wait $job; rc=$?
echo "cool_run: exit $rc, peak ${peak} C, thermal pauses $pauses"
exit $rc
