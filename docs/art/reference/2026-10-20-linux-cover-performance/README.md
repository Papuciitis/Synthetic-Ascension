# Linux shared cover performance — 20 October 2026

This is the bounded no-capture-readback timing investigation requested by the
[city continuation review](../../reviews/2026-10-20-linux-city-continuation-review/README.md).
It measures an actual moving, occupied S2 Game with cover and footways. The
earlier controlled art-capture refresh timings are not a matched ordinary-play
regression baseline. Historical art packets remain unchanged.

<!-- RECORDED_COVER_PERFORMANCE_START -->

Actual monitored process results and raw-series nearest-rank statistics:

| Measured route | Frames | Frame p95 ms | Cover p95 ms | Cover max ms | Data upload calls | Enemies p50 / p95 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Original moving baseline | 2217 | 19.759 | 6.378 | 16.643 | 6651 | 11 / 15 |
| Final same-source forced uploads | 1928 | 20.662 | 9.175 | 29.539 | 5784 | 16 / 21 |
| Final same-source exact reuse | 2006 | 20.360 | 8.686 | 15.736 | 222 | 12 / 16 |

The original baseline's upload count is source-derived; final arms use actual instrumented CPU call counters. The two final arms have identical full launch source maps and untracked records, normalized command settings, planned physical route and actual streaming activation count. Other visual/cue sources advanced after the original baseline, so the final pair provides the bounded policy comparison.

Reuse skipped packed snapshots on 1,932 of 2,006 collected frames (96.31%). It built 74 snapshots, requested 848,432 data bytes and bound materials 1,338 times; control requested 22,772,960 bytes and bound materials 33,126 times. Alpha-array upload calls/bytes and new source-image reads were 0/0/0 in control and 0/0/0 in reuse.

| Cover phase | Control mean / p95 ms | Reuse mean / p95 ms |
| --- | ---: | ---: |
| Live geometry/alpha collection | 5.584 / 8.088 | 5.787 / 8.334 |
| Exact semantic comparison | 0.161 / 0.316 | 0.189 / 0.382 |
| Packing/upload calls | 0.432 / 0.793 | 0.017 / 0.000 |
| Material cleanup/binding | 0.159 / 0.257 | 0.040 / 0.070 |

Collection remains the dominant measured cover work. Frame p99 changed 24.320→24.873 ms; the final route quarter's cover p95 changed 9.456→9.611 ms. Enemy p50/p95 changed 16/21→12/16, while projectile p50/p95 changed 3/4→4/5. Removed snapshot/binding calls are direct work evidence; whole-frame differences remain confounded by natural combat and timing variation.

| Focused correctness check | Passed / failed |
| --- | ---: |
| WorldCoverSnapshotReuseTest (native) | 24 / 0 |
| WorldCoverSnapshotReuseTest (headless) | 23 / 0 |
| WorldCoverTest (existing) | 25 / 0 |

Final control/reuse run labels are `cover-stream-final-control-small` and `cover-stream-final-reuse-small`; both exit 0 with zero diagnostics, zero fixture failures and zero saves. Each completes 50/50 cells with 3 actual new chunk activations. Raw profiles, population/projectile distributions, route quarters, density strata and phase timings are retained in [analysis.json](analysis.json).

This is a bounded observed pair. Natural combat differs between runs; it does not establish GPU savings, continuous human-play comfort, a 60 FPS guarantee or a historical feature regression. The failed first-waypoint pilot and invalid parse attempt remain failures in [the process catalogue](process/summary.json).

<!-- RECORDED_COVER_PERFORMANCE_END -->

The fixture uses seed 16102026 and actual segment 2 courtyard streets, starting at
(608,7392) beside household 944996572. Native input follows 50 cardinal walkable
cells to (2208,7392) and back, crossing an actual chunk boundary. Six simulation
seconds warm the real ambient population and pools. The actual ambient spawner,
encounter director, enemy AI/scheduler/retirement, production attacks/projectiles,
chunk streaming and normal HUD stay live. No enemies are staged or frozen.
Opening completion, initial checkpoint placement, player god mode and scripted
input are disclosed fixture controls; no profile is selected or written.

The first window is 960×540 with the normal 1920×1080 logical canvas, uncapped
process frames and VSync disabled. No viewport `get_image`, screenshot, PNG,
video, codec or per-frame file writes occur during sampling. Runtime cover's
shared original-texture alpha cache remains active. In-memory row diagnostics
and half-second streaming/spawner snapshots are included in timing, with their
instrumentation cost recorded. Startup, warm-up and one-time path planning are
excluded; new chunk activation during the actual walk is included.

Per-frame wall intervals and native cover refresh timings use the high-resolution
clock. Nearest-rank p50/p95/p99 and maxima are recomputed from the raw series.
The provider's lifetime `peak_refresh_usec` includes startup and is not the
maximum of the measured route. Engine Performance process/physics/draw monitors
are supporting observations: [official documentation](https://docs.godotengine.org/en/stable/classes/class_performance.html)
notes some monitors can lag by up to one second. There is no GPU timer or
attribution for footway fragment cost, driver upload stalls or GPU bandwidth.

The original source uploaded grid/indices/data three times per generation;
that historical count is source-derived. Instrumented candidate counters record
actual CPU upload calls/requested payload bytes, alpha-array requests, snapshot
builds/reuses and material binds. They do not measure GPU transfer duration.
Exact semantic reuse still collects actual geometry/alpha each frame. Keys cover
world triangles, bounds, ground depth, sprite UV/source region, opacity, layer
and texture identity, excluding newly allocated descriptor WeakRefs. Live fades,
transforms, visibility, streaming, grid changes and new consumers update without
a time throttle. A dev-only metadata control forces the old per-refresh packing,
uploads and rebinding on the same instrumented candidate source.

Final control/reuse arms must share seed, physical route hash, renderer/settings,
actual streaming activation count and exact monitored source maps. The original
pre-cache baseline remains separately retained even if additional cue/visual
sources advanced before the final same-source pair. Natural combat can produce
different population/projectile distributions; inspect density strata and route
quarters in `analysis.json` before attributing wall-frame differences. This is
one scripted early S2 route, not continuous human play, late-wave capacity,
cross-renderer acceptance, a 60 FPS certification or an old/new feature regression.

The first pilot failed 0/50 cells with 0 activations because distance-scaled input
fell below the actual .2 movement deadzone about 16 px from its first target,
outside the 8 px arrival radius. Full-strength native input fixes the fixture;
the 75-second timeout is unchanged. That failed first-waypoint record stays
failed. The first cache RED also failed to parse because `weakref()` inferred
Variant under the project's warning policy; explicit WeakRef typing precedes
the separate clean missing-counter RED. The process catalogue retains actual
exits, stop reasons, diagnostics and assertion footers rather than trusting labels.

Focused cache tests exercise static masonry/sprite reuse, actual uploaded native
fractional alpha, geometry and texture replacement, small/large camera movement,
immediate late material binding, weak cleanup, hidden/empty coverage, unload and
the forced-upload control. That small native component test reads its uploaded
data texture to check correctness; the measured live profiler does no readback.

The packet's exhaustive `evidence-index.json` lists bundled files. Full monitored
commands, exits, resource time series and three logs are retained. Complete launch
source maps/untracked records move losslessly into deduplicated `process/sources`;
only unrelated machine-wide Git status is omitted, with original result JSON
hashes recorded. Raw profiles are copied unchanged. No shader caches, userdata,
raw fight frames or new image/video media are bundled.
