# Procedural dungeon architecture — implementation and review record

The human approved trying the Donjon exterior/interior concepts after the
accepted wall-continuity repair. This pass changes dungeon architecture and
layout deliberately; it does not claim that the old maze topology is unchanged.
The existing ordinary-house carver/perimeter repairs are retained. The human
subsequently authorized applicable commits across chats. This owner will commit
the finished dungeon scope after verification in the serialized Git lane; no new
push has been requested for this batch.

## Implemented contract

- SiteOverlay keeps its seeded anchor, dimensions, real outer doorway and canonical
  site reward ID. DungeonLayout produces a complete envelope, roofed north/south
  chambers and a connected west hall/cell/service sequence around an outdoor court.
- Compact district Donjons use an enclosed central hall and side chambers, fitted
  to an axis-aligned rectangle excluding protected road/access cells before carving.
  Roofed indoor volumes follow the actual enclosure and retain original region IDs;
  the separate dungeon reward spawner still owns its unchanged reward rules.
- If no safe 8-cell fit exists, original carver/RNG/reward bookkeeping is retained
  as an outdoor ruin/cache. It receives no false indoor tags over protected lanes.
  This is an explicit limit, not a finished enclosed-dungeon claim for every region.
- Complete-plan wall masks/intact-art flags remain authoritative before streaming
  clips each slice. Roof/frontage pixels clip to their owner chunk in shared site
  coordinates. Three wing roofs, a clay service cap and raised entrance caps use
  actual plan metadata. The court is outdoors; covered wings share one site reward
  identity and the original total-site area classification.
- DungeonRoof extends RoofOverlay and checks complete-site wing occupancy, including
  initial occupancy after streaming reload. Raised roof returns and continuation
  polygons use the existing actor-occlusion interface. Presentation adds no hidden
  collision. The court planting's base is recorded as real cover within the normal
  site budget; ambient weeds are excluded from paved compound floors.

## Source art and review

The two approved-to-try paintings and native-camera paintover are references only.
No complete painting is used at runtime. Original gate arch, grille and masonry
bay sources and their anchors/hashes/prompts are recorded in
`assets/world/city_block/DONJON_ASSET_HANDOFF.md` and `donjon_assets_manifest.json`.
Source scale is uniform, wall modules crop at run/chunk ends, and the camera-facing
arch is used only at a matching real opening. East/west entrances use geometry.

Versioned actual Game evidence is under
`docs/art/reference/2026-10-19-dungeon-architecture-v1/`. Early v1 and v2 were
explicitly rejected by art review for bland roof bands, smooth masonry and weak
gatehouse/interior identity. V3 uses natural masonry art, raised gatehouse returns,
an unhidden gallery arch and a west-hall view. The hall screenshot is a staged
actual-geometry pose, not a physical traversal claim. The reviewer owns
`docs/art/reviews/2026-10-19-donjon-architecture-designer-review.md`.

## Verification so far

- Layout missing-feature RED: 0 passed / 1 failed. Initial connected-layout GREEN:
  32,312 passed. Later checks cover eight sizes (including 8/9 cells), all four
  entrances, exact envelope, connected usable floor, deterministic metadata,
  protected-space fit, compact enclosed halls and the west-room sequence.
  Latest layout run: 33,001 passed / 0 failed, clean exit and diagnostics.
- Genuine S3 production RED: 266 passed / 2 failed. Enclosure GREEN: 492 passed.
  Initial-occupancy/restoration test: 498 passed after correcting an uncapped-frame
  timing assumption. Expanded production checks: 761 passed, including protected
  access, exact actual walls/flags, paving exclusion, reload cutaway and sampled
  actor behind/front roof coverage. Final production check: 762 passed after the
  compact indoor floor correction.
- Early v3 actual 2×1: 12 normal/small PNGs, physical doorway entry/exit, roof
  cutaway/restoration and sampled live seam ray; exit 0, no failures, diagnostics
  or save writes. This is isolated scripted input/god mode, not human play approval.
- Initial original-chance S3 selection audit: 38 eligible chunks across four
  actual seeds, only one selected chunk/two regions. Both enclose successfully;
  current reward IDs equal checkpoint legacy IDs. This is too narrow to claim
  broad family coverage; the completed expanded comparison is recorded below.

## Final verification and accepted scope

The coordinating designer accepted the bounded first implementation after personally
inspecting the final north/west/east facility, hall/reload, compact quiet-floor and
normal/small fight samples. Long roof bands, sparse courts and further interior
dressing remain visual refinement rather than a claim of complete concept parity.

- All eleven final headless runs exit cleanly with no diagnostics: layout 33,001;
  raised-roof contract 96; actual compact production 762; legacy room carver 161;
  city kit 1,298; city procedural 5,430; 20 planned chunks / 60 styled buildings;
  site continuity 21,547; existing player roof occlusion 11; 3,840-chunk reachability
  (2,538 doors, 1,728 rewards); and all 546 gameplay scripts parse.
- Raised returns initially reproduced 24 failures (84 passed), including east/west
  door overpaint and missed lower-face silhouette. Every return/gable now subtracts
  the same real door holes as roof planes. Explicit opt-in form coverage handles
  upright returns after the real wing front-edge check; existing house behavior is
  unchanged. All three sizes and four cardinal directions pass isolated-form tests.
- `final-facilities-v2`: 38 normal/small PNGs. Actual 2×2 west, 2×1 north and 1×2 east
  sites retain complete authoritative wall cells/masks/intact flags; four live seam
  rays hit, real doorway entry/roofed-wing movement/exit/roof restoration pass. The
  portrait overview fits the whole site at explicit inspection zoom; gameplay
  details use zoom 1. Staged hall poses are labelled separately from traversal.
- `final-runtime`: 18 PNGs plus 32 actual moving fight frames. The player physically
  walks 79 cells through the court and three west-wing rooms. Actual streamed
  unload/rebuild while indoors preserves blockers, floors, volumes and recorded roof
  planes; nine reloaded roof pieces stay cut away. Exit restores the exterior.
  Existing facilities have no local security encounter; none was invented. Two
  controlled 20-enemy fights at normal/small sizes produce 39 fires, 37 hits and
  17 deaths using production movement, attacks, projectiles and enemies.
- `final-district`: 10 PNGs. The actual S3/2026 (-3,-3) case has a continuous indoor
  floor, genuine enclosed hall/cells, physical doorway entry/exit and successful
  unload/rebuild while inside. Independent dungeon-spawner reward ownership remains.
- All three final manifests have zero failures/save writes, all 66 declared stills
  exist, and all 25 product-source/asset hashes per manifest match current files
  (75 checks). The two final runner packets exit 0 with no timeout, diagnostics or
  during-capture source drift. The runtime run used the earlier isolated runner;
  later capture-only path-following/result-display fixes do not change product code.
- The expanded natural-selection comparison checks 156 eligible chunks over 16
  actual seeds. Six selected chunks across five seeds contain seven regions, all
  seven enclose successfully; original selection counts and reward-ID arrays match
  checkpoint legacy generation. No-fit cases were not selected in that sample;
  their safe outdoor-cache behavior has unit/static review rather than integrated
  natural-case proof. Exact seed list and corrected method are in the v2 audit.

`final-facilities` is retained as failed diagnostic evidence: its long portrait
court route exceeded a short straight-movement bound and subsequent waypoints
failed. The corrected v2 tool uses conservative actual blocker-grid paths and real
per-cell movement. No product change was needed. Earlier art-rejected, superseded
and failed sets are not counted as final verification.

The native tool is reproducible from committed paths:
`tools/capture/run_dungeon_preview.ps1` and `tools/dev/DungeonArchitecturePreview.tscn`.
Use an empty output directory and facilities/runtime/district mode. It refuses a
parallel game run, isolates profile directories, preserves evidence and records
source hashes. These are scripted god-mode fixtures with controlled exterior
crowds, not continuous human play or performance benchmarks. See the versioned
`checks.json`, raw test results and image hash index for exact evidence.

## Separate preexisting macro-plan boundary limit

`core/systems/world/proc/ChunkGenImpl.gd:266` gates site decoration on the current
chunk being default and connector-free. `SiteManager.gd:19` forwards decoration,
and `SiteOverlayImpl.gd:62` scans overlapping anchors without rejecting an entire
multi-chunk site when another slice belongs to a planned archetype/connector.
Consequently mixed planned/default footprint completeness is not certified here;
the concern is partial site omission where the planned chunk skips decoration,
not permission to paint dungeon geometry over a protected road. This predates
the dungeon family. The three native candidates explicitly have all-default
slices. No new macro-edge coordinate campaign or anchor/reward distribution
rewrite is included in this first architecture prototype; the coordinating
designer directed that separate whole-city follow-up to remain explicit.
