# Capture Viewer

`tools/perf/capture_viewer.html` shows the performance flight-recorder captures
as charts and tables, so you do not have to read the CSV and JSON files yourself.

It is one file. It needs no install and no internet connection. The capture files
are read by your browser and never leave your computer.

## Open it

1. Double-click `tools/perf/capture_viewer.html` (Chrome or Edge recommended).
2. Click **Open capture folder…** and pick one day's folder, for example
   `performance_results/2026-10-01`. The browser asks once whether the page may
   read that folder; say yes.
   - You can also drag the folder onto the page, or use **Open files…** to pick
     individual `.csv` / `.json` files.
   - Other files in the folder (notes, screenshots, zips) are ignored.
3. No captures to hand? Click **Load demo data** (made-up data), or open the
   page with `#demo` at the end of the address.

A day with about 340 captures loads in two or three seconds. Folders from
before September that only have `.json` files take a little longer; a progress
bar shows how far it is.

## Read it, top to bottom

- **Session** – one run of the game, from launch to quit. A day's folder can
  hold several; pick one. **Segment** is the level. **Only count frames with
  active enemies** leaves out menus, loading and empty moments.
- **Incident-window statistics** – median, 95th and 99th percentile frame time,
  and how many frames were slower than 28, 33, 50 and 100 ms. The recorder only
  saves the seconds around each hitch, so these numbers describe the bad
  moments. They are not an average of the whole play session.
- **Timeline** – frame time on top, then a strip of hitch marks, then enemy and
  projectile counts, all on the same clock. Scroll to zoom, drag to pan,
  double-click to reset. Shaded stretches are time the recorder did not save.
- **Frame detail** – click a hitch mark (or a row under **Worst hitches**) to
  see that one frame: when it happened, the level, how many enemies and
  projectiles, how many physics ticks ran, a bar showing which measured costs
  filled the frame and how much is unexplained, and the game events within
  1.5 seconds of it.
- **What the hitches were tagged as** – how often each tag appears. Click a tag
  to filter the worst-hitches table.

## How much to trust what you see

Every piece of evidence carries one of three labels:

| Label | Meaning |
|---|---|
| **Measured** | A timer recorded this cost. (Some timers are refreshed only about twice a second; the detail view says which.) |
| **Correlated** | Close in time, or a tag chosen because it was the largest measured cost. A lead to follow, not proof. |
| **Unknown** | Frame time that no timer covers. |

Two things are easy to misread:

- `physics_catchup` means two or more physics ticks ran in one rendered frame.
  It is a measured symptom: Godot runs extra ticks to catch up after an earlier
  frame ran long, so it may not identify what started the delay.
- Unmeasured time is not necessarily work. On an ordinary 16.7 ms frame most of
  it is the game waiting for the next screen refresh (vsync). It is the time
  above about 16.7 ms that needs explaining.
- `scene_change` marks a frame in which the game changed scene (into the hub
  or into a run). These are the half-second to two-second frames; a loading
  card covers them in play. Captures from build `8d6e124` and earlier do not
  carry the mark, so there the same frames read `unattributed`: a frame of
  half a second or more with no enemies, right where a segment ends or
  begins, is almost certainly a scene change.

Captures from builds after `8d6e124` also say where each frame went. Open a
frame and look for **Frame phases**: scripts, end-of-frame work, and draw +
present. With physics next to them, that is the whole frame. **Ascension
engines** in the same place splits the skill tree's tick by engine (BR, PR,
OR, ...), and a tick of 8 ms or more also appears among the nearby events as
`ascension · slow_tick`.

**Wall time** is the real time between two frames and is what the viewer shows.
Captures from before late September did not record it; for those the viewer
falls back to Godot's own frame delta, which is capped and under-reports long
hitches, and says so on screen. Anything a capture did not record is shown as
"not recorded", never as 0.

The words used on the page are explained again at the bottom of the page
(**What the words mean**), and most labels have a tooltip.

## Good to know

- Clock times are worked out from the file names, so they can be a second or
  two off. The segment also comes from the file name: frames in the few seconds
  before a level change can be listed under the next level.
- Timeline, statistics and tables come from the small `.csv` files. The large
  `.json` file is opened only when you click a frame. If you load `.csv` files
  alone, the detail view has fewer timers and no events.
- In some browsers (Firefox, Safari) the folder dialog says "upload". That is
  only the browser's wording: nothing is sent anywhere. The viewer was checked
  in Chrome and Edge.

## For whoever maintains it

- All logic that does not touch the page (file names, CSV reading, sessions,
  de-duplication, percentiles, the hitch tagger ported from
  `autoload/performance/PerformanceHitchTagger.gd`) sits in the
  `<script id="core">` block of the HTML. If the tagger changes in the game,
  change it there too.
- Tests: `node tools/perf/capture_viewer_test.mjs`
  (set `CAPTURE_VIEWER_REAL_DIR` to a copy of the 2026-10-01 folder to also
  re-check the reference numbers).
- Sample captures: `tools/perf/capture_viewer_samples/` (synthetic, small).
  Regenerate with `node tools/perf/capture_viewer_samples/generate_samples.mjs`.
  The empty `.gdignore` there stops Godot importing the `.csv` files.
- New columns in the CSV, or new fields in the JSON, do not break the viewer:
  columns are read by name and unknown ones are skipped. `physics_ticks`,
  `physics_frame_ms` and `sampling_usec` columns are picked up when present
  (the recorder also writes `process_phase_ms`, `deferred_ms` and
  `render_present_ms`; the viewer shows those from the JSON's `frame_phases`);
  `frame_phases` and `ascension.engine_usec` maps are drawn as bar lists in the
  detail view.
