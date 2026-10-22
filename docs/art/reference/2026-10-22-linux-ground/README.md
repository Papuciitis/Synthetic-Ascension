# District ground continuation — 22 October 2026

Claude's `claude/wp2-ground` is integrated into Linux production at
`f127d9496c08d127a2e355dbd769b85f190d11e2`. The merge retains the production
domestic masonry fix. Cover, streets, plazas, mood and weathering branches remain
separate. This is a ground implementation and verification checkpoint; the
[lead's city review](../../reviews/2026-10-21-linux-phase1-lead-review/README.md)
and [material brief](../../2026-10-21-segment-material-atmosphere-direction/README.md)
still govern the unfinished whole scene.

Open the [before/after image index](EVIDENCE.md), [portable run index](evidence-index.json),
[GPU summary](gpu-summary.json), [source verification](sources/final-source-verification.json)
or [occupied route record](occupied/profile-info.json.gz) for the evidence behind this report.

The change separates indoor floor material from road paving, carries contact
shade across loaded chunk boundaries, places planted beds against house walls,
quiets carriageways, joins industrial yard wear into useful working areas, and
restores S7's damp olive vegetation. Narrow wall-bounded strips still have a
rectangular silhouette, and some industrial yard corners meet paving too
sharply. The final correction softens planted-bed
edges inward using the existing noise sample; it adds no texture fetch or new
eligible planting cells. Terrain, blockers and gameplay RNG remain governed by
their existing owners. Broad pale forecourts, some yard tone boundaries, passage
continuity and repeated formal plaza rings remain for subsequent work.

Implementation history: original candidate `fb6a9e30`; local edge/index fix
`6c2021bd`; paced diagnostic probe `9c160550`; normal production merge `f127d949`.
The probe's route 4–8 indices now clamp to the route array. Optional setup/cooldown
and sampling caps preserve the original defaults. `setup_fps_cap: 0` in its JSON
means no optional setup override, not that the inherited setup helper was uncapped.

## Shader cost

These are **GPU timestamp measurements**, not frame-rate or whole-Game budget
acceptance. Each stationary actual-Game fixture disables the player and spawner, stops
builder/chunk processing for sampling, hides other canvas items, and keeps one
camera/chunk set. It interleaves ground-hidden, final-ground and phase-1 shader
variants on that same final material set. The entire SceneTree is not frozen. The phase-1 comparison is a shader
substitution, not a historical runtime build. No viewport readback, frame capture
or per-frame disk writes occur in the measured interval.

| Native camera | Final GPU ms | Phase-1 GPU ms | Reduction |
| --- | ---: | ---: | ---: |
| S2 start | 5.6135 | 7.3620 | 23.75% |
| S2 route1 | 5.1905 | 7.2660 | 28.56% |
| S7 canal start | 5.3610 | 7.5600 | 29.09% |
| S7 canal route1 | 5.4195 | 7.4605 | 27.36% |

All four final timing runs exit 0 with zero diagnostics. Ground-hidden GPU cost
is 0.011–0.013 ms. Actual client size is **1920×1040**, after the window manager
clamps the requested 1080 height. Renderer: Godot 4.7.2 OpenGL3, Mesa 25.2.8,
Intel UHD620. Each variant has 3 rounds × 120 measured frames after 30 warm-up
frames, a 60 FPS sampling cap, and 2 seconds of 10 FPS cooling between variants.
The roughly 16.67 ms frame periods include that cap and establish no throughput gain.

Each process uses CPU affinity 0, 1. Only the identified owned Godot process is
limited to 25% runnable duty during initial setup, ending before the first variant marker. The engine is never externally paused
within each timed sample interval. Start gate 65°C, runtime stop 90°C or 3 consecutive
one-second samples at 85°C; final peak temperatures are 76/73/73/75°C. Existing
memory, foreign-engine and owned-cleanup protections remain enabled. No fan,
governor, power or machine settings were changed.

Final ground shader SHA256:
`a5f877acb6cf6f5f5dfbb803ef7d2fae9169d71907cb91675519c230f6b0cfb9`.
Phase-1 shader SHA256:
`4382a6428902b64a190f4081d3480a3c1b1466369b80969533aaeec3339ccfd2`.
Mesa's separate compilation run identifies the ground program by its policy,
yard-placement, cared-lawn and material-array uniforms: GLSL61,
`src_hash0x36dc6ae8`, SIMD16 **1111 instructions / 0 spills**, SIMD8
960/0. Ground SIMD32 allocation still fails. Two other programs' SIMD16
allocation failures remain in the raw log; they are not ground failures.
The [identified ground-program summary](runs/compiler/ground22-simd/simd-summary.json)
records the compiler evidence; the run index links the complete driver output.

## Native views and checks

All nine focused merged-source suites completed with exit 0 and zero diagnostics:
policy 298/0, splat 63/0, household care 141/0, natural care 8 chunks/0 failures,
material cache 38/0, generation material 0 failures, native pavement 14/0, native
dry receiver 6/0, and parse audit 564/0. That is 1124 counted assertions plus the
natural/generation checks. The native pavement edge has 16/15 partial-alpha
pixels and a fully opaque approach core. The parse audit has no exit-leak
diagnostics in this run. Test durations are functional observations under
25% external runnable duty and two-core affinity, not performance comparisons.

All four final native surveys complete with exit 0 and zero diagnostics at the
merged source: S2/service_courtyards 16102026, S6/industrial_cutthrough 16102028,
S7/underpass_veins 16102026 and S7/canal_services 16102028. The packet selects
route 1 gameplay/overview from each, plus S2 kit1 and S7A kit2. Original phase-1
route 1 gameplay/overview pairs provide the eight BEFORE views.

The occupied native check also completes with exit 0, zero diagnostics,
zero failures and zero save writes: 1880 rendered process samples, 50/50 planned
cells, 4143.90 px walked, 3 live chunk activations, 178 weapon fires, 82 hits and
81 enemy deaths. It runs at 960×540 with a 60 FPS cap, scripted actual movement,
held attack, god mode and inherited enemy batching/proxy rollout enabled. Actual
ambient spawning, director/AI and streaming remain active; enemies are not
staged for the route. All 1880 samples are occupied, with 2–29 enemies. Setup duty limiting ends at the Game-ready marker, before
settling/warm-up/route sampling. The exact cell hash matches the earlier
occupied-route fixture. This is a functional moving/streaming check with no
readback, not a matched whole-Game performance comparison, entry/collection
proof or visual combat acceptance. Original phase-1 BEFORE views remain clearly
labelled; the pre-feather `fb6a9e30` AFTER iteration is preserved locally rather
than shown as the final merged surface. Surveys disable the player and spawner, stop procedural-builder processing,
and stream each staged camera point. They do not freeze the entire SceneTree.
They use the same 1280×720 framing, theme selection and generated camera points.
They do not establish combat readability or ordinary human-play acceptance.

## Source binding and unsuccessful attempts

The four safe timing runs have identical 2683-input launch maps. Their 116 inputs
overlapping the 148-input scoped ground snapshot match exactly. The remaining 32
scoped entries are generated texture/import bytes independently hashed before
and after the compiler interval and after the timing queue. The final merge has
two scoped differences from measured candidate bytes: retained production
`CityDomesticInterior.gd`, and comments in the probe clarifying capped timing.
The ground shader, renderer, policy, generators and material bytes match.
All 14 final merged-source runs have identical **2696-input** launch maps.
Every recorded byte matches the final files, and each tracked input matches
its HEAD Git blob. The 148-entry scoped snapshot and 192-file repaired import
closure remain unchanged across the final run queue. Launch-only import
sidecars and the local runner are preserved separately as text evidence; these
are not claimed as tracked production content.

Original capture maps contain 13 inputs per context; they are not complete Game
dependency maps. The packet retains those original records and separately labels
retrospective texture/import additions. Original seeds come from `survey.json`,
including S7 canal 16102028. Early candidate checks, the edge gate and compiler
run lack full launch maps; their explicit scoped snapshots and shader-reported
hashes are retained without inventing missing provenance. The final merged runs retain
the runner's full source maps as well as scoped import-byte snapshots.

Four earlier GPU attempts were thermally stopped and supply no complete usable
final timing result: `ground22-gpu-s2`, `ground22-gpu-s2-start`,
`ground22-gpu-s2-start-paced`, `ground22-gpu-s2-start-cool`. Their exact commands,
thermal records and diagnostics remain classified separately. Protocol changes
are disclosed; only the four `*-safe` cases support the table above.

The first merged policy attempt printed 298/0 assertions but had missing imported
textures and resulting script/RID diagnostics. A runtime thermal stop occurred
at exit; this is a failed attempt. The local cache was repaired with 48 matching
runtime textures/96 generated files from the tested worktree: source and import
sidecar SHA256, source MD5 and copied bytes were verified before reuse. Existing
cache files were not overwritten; passive docs imports were excluded. The
repair manifest and 192-file closure addendum accompany the actual pre/post
snapshots. Generated cache files themselves are not committed.

The loaded-neighbor AO contract is verified for activation/rebuild and load
order. Unloading a neighbor does not currently repaint a retained edge until
the next activation; no visible Game failure was demonstrated in this work.
Do not infer unload-invariant AO or combine this packet's occupied route with
the still-open street/entry/collection/cover acceptance requirements.

Large raw records are losslessly packed as deterministic gzip files. The
[compression map](compression-map.json) binds their original paths, byte counts
and SHA256 values to the packed copies; no raw record contents or PNGs were
changed. Use `gzip -dc path/to/record.json.gz` to inspect a packed record.
The [file manifest](manifest.json) inventories the delivered payload.
