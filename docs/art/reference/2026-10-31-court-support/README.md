# District-fill court support and bed inner corners

Claude, 31 October 2026. Branch `claude/c31-yard-shapes` from production
`d7cfb52f`, at `5988157e`. Plan: `docs/superpowers/plans/2026-10-31-court-support.md`.

| Commit | Change |
| --- | --- |
| `49ded0b9` | Tools: the district role map probe, plus an `at=x:y` cost probe point. |
| `bc8820f8` | Flush district-fill courts; S9 court setts follow their use. |
| `69642044` | Tools: per-family court release sheet. |
| `d1da2aa3` | Bed inner-corner fillet. |
| `5988157e` | Stale S2 coverage assertion corrected. |

## Why

The [maps](maps/) are headless renders of the real S9 (plan 1445060584) and
S7 (plan 1208827904) district plans, coloured by ground role. The white marks
show the first pass's released cells.

District fill is the most common chunk (40 of 91 in S9, 55 of 103 in S7). Each
one stamped a centred 9–13 cell court of kerbed court setts, and that court is
the broad grey rectangle in the accepted S9 and S7 views.

What changed:

- Every fill court is now flush, with no kerb or gutter ring.
- In Outer Wall (S9A), court setts follow the meandering walking lines from
  passages and doorways into the working middle. Unused cells draw as the
  grassy cobble yard.
- Other families keep their setts until reviewed on `sheets/`.
- Beds only gained an inner-corner fillet.

Semantic ground, care bytes, doors, navigation and generator RNG are
unchanged.

## Native originals (GroundPavingPreview harness, guarded)

| View | Before (production `d7cfb52f`) | After (final) | Controls |
| --- | --- | --- | --- |
| S9 normal 1280×720 | `native/before-s9` | `native/after-s9` | 0 failures, 0 save writes; plan, camera, material counts and care-mask hash equal |
| S7 normal 1280×720 | `native/before-s7` | `native/after-s7` | same; only the kerb ring changes |

Every before/after difference lies in court or bed pixels.

`native/rejected-first-pass` holds the first pass: release in every family,
round wobbled beds, plus a 960×540 pair whose small-window before is
`native/before-s9-small`. It is kept as the reviewed record, not accepted.

## Checks

| Check | Result |
| --- | --- |
| GroundCourtSupportTest | 72/0 |
| GroundCourtSupportRenderTest | RED 8/4 on the old shader (`render/court-red`); GREEN 12/0 (`render/court-final`) |
| CityGroundCareRenderTest | RED 53/1 without the fillet (`render/care-red`); GREEN 54/0 (`render/care-final`) |
| DistrictGroundPolicy | 298/0 |
| WorldGroundSplat | 63/0 |
| CityGenerationMaterial | 0 failures |
| CitySegmentCoverage | 166/0 (stale S2 assertion corrected; 164/1 on production) |
| ThemeAtmosphereReceivers | 43/0 |
| ThemeAtmosphereDryReceiver | 6/0 |
| First-pass owners (no shader, planner or policy-key dependence) | CityGroundCare 150/0, CityGroundCareNatural 0 failures, PlazaPresentation 28124/0, CityDoorApproachGround 64/0, DistrictFamilyVisual 143/0, SiteWallContinuity 21547/0 (a first attempt hit a 96 C stop) |
| PlazaBedUnderlayTest | 35/4 on production and branch alike: a pinned S6 fixture has drifted. Open, unrelated. |

GPU cost (`cost/`, GroundShaderCostProbe at the reviewed S9 view, 1920×1080,
ground pass only, UHD 620, GPU timestamps):

- **Final:** 4.57 ms against 4.26 ms for production, **+0.31 ms**.
- **First pass:** +0.33 to +0.36 ms at three points.

A breakdown run was stopped deliberately (`runs/c31-cost2-s9`). Loader parity
between the two variants was not separately controlled.

## Reviews

`reviews/independent-first-pass.md`: **REWORK**.

- S9 was accepted with notes.
- S7's release to coarse flags drew a diagonal "wipe", and was rejected.
- The fixture read as a keyhole, and was rejected.
- The round beds pulled off their walls, and were rejected.

`reviews/independent-final.md`: **ACCEPT WITH NOTES**. Two problems remain:

- S9's release edge still runs straight along cell lines in places and cuts
  through stones.
- The darker edge course is too faint to see.

The next step is snapping release edges to whole setts, or drawing a visible
contact course, before enabling release for more families.

## Runs

`runs/<label>/` holds every guarded run of this lane, including the failed
ones:

- `c31map` was stopped after a probe parse error.
- `c31map2` (S7) and `c31reg-SiteWallContinuityTest` hit 96 C stops.
- `c31t1` failed on wrong test assumptions, later corrected.
- `c31red*` and `c31v2red*` are the intended REDs.
- `c31-cost2-s9` was stopped deliberately.

Each run has its guard thermal record, wrapper log and engine logs.
Superseded first-pass and development runs omit the full-provenance
`run-results.json.gz`; current-evidence runs include it. `process/` holds the
chain summaries; `sources/shaders/` holds every shader variant a run used.

## Limits

These are static, duty-controlled captures (20 FPS, 60 Hz physics). They
establish no combat, motion or whole-game performance result. Guard records
are a capture protocol, not a hardware-safety claim.
