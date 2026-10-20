# Linux S2 home/street review packet — 20 October 2026

Received Windows checkpoint: `b5de9d53d081fa5fecde4188f811bf38d3f97cff`.
Implementation: `5f851103` on `codex/linux-world-production`.
**Prepared for Windows lead review; no visual acceptance is claimed.**

The packet establishes the monitored Linux lane and supplies the missing native
views of the two actual generated homes. It changes capture/test tooling, not
city generation, source art, ground materials, furnishings or gameplay rules.

## Start with these images

| Actual generated home | Small, 960×540 | Normal, 1280×720 |
| --- | --- | --- |
| seed 16102026, chunk (0,3), building 944996572; irregular south-entry row_house, herb-bed variant 0 | [exterior](bed-small/exterior.png) | [exterior](bed-normal/exterior.png) |
| seed 17, chunk (-3,5), building 2128236757; north-entry row_house, overhead fruit-tree variant 1 | [exterior](tree-small/exterior.png) | [exterior](tree-normal/exterior.png) |

[The runtime survey](natural-streets.json) resolves IDs from actual
IndoorVolume-to-RoofOverlay signal ownership, rather than assuming a visual seed
is an identity. The bed home has two indoor volumes with one presentation entry;
the tree home has one. Their added neighboring parcels are workshops, not homes.

Both assets retain the supplied alpha/aspect/scale and measured contact anchors.
The bed uses source anchor (955,485), uniform scale 115/1761; the overhead tree
uses root anchor (660,1060), scale 135/1167. Native results expose actual local
transforms, contacts and source paths. No asset resize, repaint or fit correction
was warranted by this first inspection. This is a production observation,
not the art lead's keep decision. Tended lawn and broader ground care remain L2.

## Physical entry and moving review

| Run | Cutaway / restoration / occupied fight | Moving artifact |
| --- | --- | --- |
| Bed home, normal | [interior](bed-walk-normal/interior.png), [restored](bed-walk-normal/restored-exterior.png), [fight](bed-walk-normal/fight.png) | [walkthrough](bed-walk-normal/walkthrough.mp4) |
| Tree home, small | [interior](tree-walk-small/interior.png), [restored](tree-walk-small/restored-exterior.png), [fight](tree-walk-small/fight.png) | [walkthrough](tree-walk-small/walkthrough.mp4) |
| Bed home, Reduced Motion / Combat Flashes Off | [interior](bed-walk-reduced/interior.png), [restored](bed-walk-reduced/restored-exterior.png), [fight](bed-walk-reduced/fight.png) | [walkthrough](bed-walk-reduced/walkthrough.mp4) |

Each full run uses physical input/collision along all five perimeter waypoints,
real entry/exit signals, roof cutaway/restoration, and a 12-second moving exterior
fight. Its `capture-info.json` records streamed architectural/garden equality,
zero wall instances after unload, restored instances, attacks, hits, projectiles,
deaths, native frame timings, failures and save-write delta. The herb bed remains
visible in the cutaway. The empty/pale interiors are intentionally documented as
the current L3 baseline, not presented as furnished homes.

These use production Game, ordinary ground/foliage/actors/HUD and the existing
north-up camera/zoom. Transient introductory tips clear before capture. Normal
milestone toasts can appear during combat. Scripted input and god mode are on;
the ambient spawner is disabled, the exterior crowd is controlled, and chunk
updates are frozen after the explicit reload check. These ambient homes have no
local security encounter. This is neither an ordinary human playtest nor proof
of normal ambient horde balance. Batched enemies can draw over the neighboring
annex roof during the fight; staged entity visibility remains the separately
queued packet. No existing civic/S3 treatment has been changed.

Videos are silent H.264 from the original PNGs, with measured variable frame
intervals, no resizing, repaint, interpolation or speed change. Encoding sidecars
retain the command, every source frame hash and timing, and output hashes.
Original raw frames remain machine-local under `.superpowers/handoff-linux/`;
only useful stills, metadata and videos are published. Every packaged video is
decoded again to check it. Readback/PNG writing and monitoring affect timings;
these observations are not a comparative performance benchmark.
`decode-results.json` records the actual clean decode command. The initial null
muxer check used its default coarse output clock and printed duplicate timestamp
diagnostics; explicit VFR passthrough and a microsecond output time base resolved
that verification issue without changing the captured images or encoded videos.

## Verification and provenance

[Review summary](review-summary.json) contains the native result counts and
measured memory range. Each run has `run-results.json` with the exact engine
command, real exit, diagnostics, memory/CPU samples, isolated profile paths and
source commit. [Native source hashes](native-source-hashes.json) cover the same
current scripts/resources and world image/import inputs for every native run.
Native captures began before the implementation commit and continued after it;
the matching content hashes, not an assumed clean HEAD, authenticate the pixels.
The [artifact manifest](artifacts.json) hashes the packaged files.

[Checks](checks/summary.json) retain independent Linux import, footway, service,
natural survey, planned-building, kit, procedural, roof and gameplay parse runs.
Camera RED evidence is retained separately from its GREEN result. Full commands,
stdout/stderr/engine logs and deduplicated per-run source records are included;
initial checks used earlier monitor revisions, so their actual source records
are preserved rather than retroactively relabeled. The seven-category Windows
strict-warning snapshot was not rerun; parsing 549 gameplay scripts does not
claim to inventory the editor warning panel or all tools scripts.

The Linux monitor's focused tests cover isolation, diagnostics, exit propagation,
cgroup v1/v2 headroom, fixed shared lock, foreign-Godot refusal, fresh-evidence
protection, RSS limits, timeout/signal cleanup and exact source provenance.
[Python results](python-tests.log) preserve the fresh root verification.
All 19 monitor tests and all 8 encoder tests pass, including a real FFmpeg
timestamp/duration check; no optional test was skipped in root's final run.

The host is Linux Mint 22.2, X11, Intel UHD 620 / Mesa 25.2.8, with Godot
`4.7.2.stable.official.ed1daf0bf`. This preserved existing checkout was explicitly
imported; it was not a fresh clone. The user closed the editor before engine
runs. Default guards: 6,144 MiB owned-group RSS maximum and 4,096 MiB host/cgroup
available-memory minimum. The Windows guard and OS settings were untouched.
FFmpeg 7.0.2 was extracted locally from an imageio-ffmpeg wheel; [host record](host.json)
contains its hash. No system package was installed.

## Reproduce from the Linux branch

Set `SA_GODOT` to your installed Godot 4.7.x binary. Use a new run-root/output
for each invocation; the monitor deliberately refuses to overwrite results.

```bash
python3 tools/capture/run_city_linux.py --godot "$SA_GODOT" \
  --run-root .superpowers/handoff-linux/my-import --timeout-seconds 300 -- \
  --headless --import

python3 tools/capture/run_city_linux.py --godot "$SA_GODOT" \
  --run-root .superpowers/handoff-linux/my-bed --timeout-seconds 300 -- \
  --rendering-driver opengl3 --audio-driver Dummy \
  res://tools/dev/CityBlockPlayablePreview.tscn -- \
  --review=normal --world-seed=16102026 --segment=2 \
  --target-building-id=944996572 --target-chunk=0,3 \
  --out=.superpowers/handoff-linux/my-bed-images
```

Append `--still-only` for a whole-building exterior instead of traversal/combat.
Use `--review=small` for 960×540 or `--review=reduced` for the accessibility run.
For the second home substitute seed 17, ID 2128236757 and chunk `-3,5` together.
Run `CityServiceNaturalTest.tscn -- --out=<fresh-json>` through the monitor to
re-resolve sample identities after future generation changes.

## Requested lead decision

Review both whole-home sizes and the three moving artifacts; record a specific
keep/rework verdict in ART_STATUS for garden scale/contact, uneven street and
neighbor relationships, and actor readability. No new asset request is needed
from this first fit. After that L1 visual gate, Linux can take L2 ground care/S7,
then L3 domestic purpose and masonry. Ordinary human play and visual approval
remain outstanding. S4A and new district families remain outside this packet.
