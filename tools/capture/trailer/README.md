# First trailer: capture and edit

Tools for the first gameplay trailer (4–5 November 2026). Takes are recorded
from the actual Game at `codex/trailer-build` `a2720c2d` by Godot's offline
Movie Maker, then assembled by `build_trailer.py`. The delivered cut, its cut
list, take logs and pickup list are in
`docs/art/2026-11-05-first-trailer/`.

## Why the capture needs a preload

Movie Maker renders every frame at a fixed 60 FPS however long the frame takes.
The game times enemy strides, hit flashes, HUD pulses and SFX throttles with
`Time.get_ticks_*`, which follows the wall clock, so offline those would race
ahead of the footage. `movieclock.so` (built from `movieclock.c`) makes that
clock advance by exactly one frame per recorded frame once the director starts
ticking it. It also reports the mouse position the director chooses, so mouse
aim and bag hover work while the window stays off-screen and unfocused. Game
code is unchanged. `MovieClockCheck.tscn` verifies both (frame steps of
16 667 µs and the pointer reaching the viewport).

```sh
gcc -O2 -shared -fPIC -o movieclock.so tools/capture/trailer/movieclock.c -ldl -lpthread
```

## Recording a take

`TrailerDirector.tscn` stages one take per run in segment 7 (Canal Services,
world seed 16102028): `find` (street fight, doorway, item, bag choice, Momentum
payoff), `vigil` (the Ward Vigil with the found rule worn) and the `street`
pilot. Every staging step and frame-stamped mark is written to `--log`; a
one-frame magenta slate opens the usable footage (movie frame = logged
process frame).

Run one engine at a time, through the thermal guard, never during a human
playtest. `capture.sh` does a headless parse pre-flight (a script error would
otherwise record a blank window until the timeout), isolates the profile and
runs the guarded native capture. The paths inside it are this machine's.

```sh
cp tools/capture/trailer/override.cfg.example override.cfg   # 1920x1080 borderless, V-Sync off, MJPEG 0.95
START_TEMP=65 BURST=90 capture.sh <label> res://tools/capture/trailer/TrailerDirector.tscn \
  /abs/take.avi 7200 10 -- --take=vigil --log=/abs/take.json
watch_take.sh <label> <capture output file>    # streams marks until the engine exits
```

At 10% duty a 36 s take records in about 35 minutes at 50–65 °C on the
UHD 620 laptop; 25% duty overheated on the Vigil (sustained 85 °C stop).

## Rebuilding the trailer

```sh
python3 tools/capture/trailer/make_cards.py . <cards dir>
CORES=3 HOT=80 COOL=70 cool_run.sh python3 tools/capture/trailer/build_trailer.py \
  docs/art/2026-11-05-first-trailer/cutlist.json <work dir> <out.mp4>
```

The cut list is the editable project: source frame ranges, an optional crop
(punch-in) or caption overlay per cut, an audio tail under the next cut, the
title card, the S10 score cues and the mix. Pieces whose cut and source are
unchanged are reused from the work dir. `cool_run.sh` keeps ffmpeg on the given
cores at low priority and pauses it at `HOT` °C until `COOL`. `review_take.py`
writes labelled contact sheets for choosing frames and for the small-screen
check.
