# Linux scene depth — 20 October 2026

This packet records the actual L-house shadow correction, entry-shaped soft
footway, and fitted S2 roof planes with correctly turned original tile textures.
It addresses specific pavement, footprint-cast and flat-mass problems identified
in the [concept audit](../../../audits/2026-10-20-concept-fidelity-and-chat-audit.md).
It does not accept the whole street, every building family or a frame budget.
The selected house is seed16102026, segment2, chunk(0,3), ID944996572.

<!-- RECORDED_RUN_SUMMARY_START -->

The following counts are read from retained assertion footers and monitor results:

| Final focused check | Passed / failed |
| --- | --- |
| CityIrregularRoofTextureRenderTest | 17 / 0 |
| CityIrregularRoofPlaneRenderTest | 21 / 0 |
| CityNonGuardFootprintShadowTest | 24 / 0 |
| CityFootprintShadowTest | 13 / 0 |
| CheckpointOfficeRefinementTest | 174 / 0 |

Both frozen native pairs completed with actual exit0, no monitor diagnostics, zero fixture failures and zero saves:

| Capture | Elapsed seconds | PNG size |
| --- | --- | --- |
| [roof-depth-pair-small](roof-pair-small/connected-roof-planes.png) | 26.952 | 960×540 |
| [roof-depth-pair-normal](roof-pair-normal/connected-roof-planes.png) | 27.599 | 1280×720 |

<!-- RECORDED_RUN_SUMMARY_END -->

| Native plate | What it shows |
| --- | --- |
| [Pre-roof baseline, small](baseline-small/ground-before.png) | Already-corrected exact S2 shadows and softened footway; original single L-roof lighting. This is not a visual baseline for the old square apron or bad cast. |
| [Rejected lighting-only small](rejected-lighting-only-small/ground-before.png), [normal](rejected-lighting-only-normal/ground-before.png) | Connected main/front light planes and shallow fascia, before the tile mapping turned with the main ridge. The texture fault prevented accepting this interim result. |
| [Frozen small legacy](roof-pair-small/legacy-whole-roof.png), [connected](roof-pair-small/connected-roof-planes.png) | One actual scene, paused after reload/quiet HUD; hide only the fitted composition and restore the duplicate host draw alpha for the control, then exactly restore the connected roof. |
| [Frozen normal legacy](roof-pair-normal/legacy-whole-roof.png), [connected](roof-pair-normal/connected-roof-planes.png) | The same two draw states in a second native1280×720 run. |
| [Ordinary final small supplement](supplemental-final-small/ground-before.png) | Unpaused actual Game with the turned original clay texture and integrated selected ground/domestic improvements. |
| [Paving/cast before](paving-before/ground-before.png), [after](paving-after/ground-before.png) | Same native seam camera(0,7136); source and sampled-grid qualifications below apply. |

All ten named PNGs are copied without alteration, with eight complete
`capture-info.json` records. The home camera is position(544,6936), rotation0,
zoom(1,1), internal viewport1920×1080; native output windows are960×540 and
1280×720. [Comparison records](comparisons.json) check actual camera/footprint
equality and list changed scoped launch inputs. The frozen pairs change only
composition visibility and host mesh draw alpha, with RGB/material/geometry,
chimney, physical signature and shared cover preserved. Each control uses the
current host's original whole-mesh shader; it does not recreate every historical
runtime source. The connected state restores the original host/group exactly.

The earlier/interim and ordinary final plates are not one-variable comparisons:
ground/domestic sources advanced. The isolated production-mesh/native calibration
test establishes tile direction; the same-state actual roof pairs show the
bounded full roof change without that ground/purpose confound. The source clay
barrels/slate courses turn90degrees on north–south planes and retain the original
density; the east–west arm keeps its original mapping.

The older paving/cast comparison uses the same world camera(0,7136). The wet
source and baked cache changed between its two runs, so it is not complete source
equality. Its recorded70-cell seam grids are identical, with stainG0, no material5
and identical care hashes. These local controls support inspecting the exposed
footway/shadow boundary, rather than attributing every whole-image difference
to the paving correction.

The fixed actual-Game review disables ambient spawning/encounter beats, uses
player god mode and staged placement, retains normal HUD/optional detail, and
freezes streaming after the explicit reload. The roof pairs additionally pause
the scene tree and set time_scale0 after the real temporary tips clear; both
states retain normal HUD and the separately owned chimney. No occupied fight
is exercised in this packet: zero captured fight frames are expected. It does
not establish human traversal, combat comfort, balance or spontaneous encounters.
No raw fight frames, userdata, shader caches or new videos are bundled.

The exact cast uses the occupied footprint rather than its bounding rectangle,
retaining concave-ground shadows and trimming against actual known neighbors.
The final independent finite-ray fixtures cover actual S4/S7 L parcels with
south/east doors; accepted guard custom shadows keep their original path. The
soft footway follows the real entry edge and feathers only its external semantic
boundary. The native edge check changed from1partial-alpha pixel on each side
to12/11, while retaining an opaque approach core.

The S2 fitted roof uses disjoint planes and a shallow rim inside the original
visible silhouette. Its source clay/slate resources and texel density remain
the same; roof alpha, shared cover union and physical doors/footprint retain
their original owners. Native tests check independent wing light directions,
no mask gaps/overlap/outside coverage, half-alpha compositing, live cutaway/cover,
and S3 controls. Existing kit1300/0, procedural5430/0, dungeon roof99/0 and
shared cover25/0 checks are retained with their earlier exact source snapshots;
the final focused guard check is174/0. The five `scene-final-*` focused source
snapshots precede the4c4a6cb2 ground/domestic-purpose integration. The final
actual roof pairs use that integrated state plus this roof/shadow slice. Labels
containing `final` do not mean one universal source snapshot, and the focused
records are not relabeled as final integrated-main regressions. Final main
regressions follow all integrations and will be recorded separately.

The [process summary](process/summary.json) separates clean feature RED,
clean checks, rejected visual intermediates and failed attempts. In particular:

- `scene-edge-red` assigned the nonexistent `SubViewport.own_world_2d` property
  and was interrupted; it supplies no valid feature result.
- `scene-edge-red-valid` has the intended5/2 feature failures and1px edges,
  but also2ObjectDB/1resource shutdown leaks. Its historical label does not
  make it clean RED; the final verbose native7/0 run is clean.
- `scene-green-CityFootwayGeometryTest` printed10/0 and exited0 but reported
  an Array-to-Array[float] runtime error. It is a failed implementation attempt,
  resolved by explicit typed array branches before the clean rerun.
- `scene-roof-texture-red` reproduced the intended15/2 but leaked menu MP3
  stream/playback objects. Early audio stop/server-frame fixture cleanup led
  to the separate clean `scene-roof-texture-valid-red`15/2 before the UV fix.
- Cold/warm editor import failures are preserved as setup failures. The later
  actual runtime baseline1300/0 uses the prepared cache/class setup and does
  not prove a fresh-clone import.

Clean REDs retain bed shadow8/5, inner-L footway8/2, connected roof14/4,
UV direction15/2 and later non-guard cast16/8. Source/render changes followed
those failures; the actual textured review prompted the additional UV test and
rework rather than accepting the first lighting-only result.

`evidence-index.json` is the authoritative list of bundled files. Full monitored
commands, exits, stop reasons, diagnostics, resource time series and all three
logs are retained. Original local command/output paths are provenance and do
not imply scratch files are bundled. Original `source_hashes`/`source_untracked`
records move losslessly into content-deduplicated `process/sources`; only the
machine-wide Git status is omitted, with the original result JSON hash retained.
[Scoped inputs](process/scoped-inputs.json) distinguish code/test/tool hashes
at each launch. A null entry means that path was not recorded then. The
[code commit binding](code-commit-bindings.json) compares actual Git blob bytes
at`346518eee60c8003c2cbe005af31076d6bf6d5b3`with the launch records: both frozen
roof pairs match all35scoped committed code/test/tool inputs. The later domestic
plaster shader is absent from that commit and unrecorded in those captures;
its current bytes are not substituted into this binding. The ordinary final
small supplement matches33inputs but predates the two roof-pair tool files.
The five focused tests each match28inputs, leave6unrecorded and differ in the
WorldArt source; they retain their earlier snapshot qualification. Every other
run has its own missing/different paths listed. These are scoped code bindings,
not complete asset/reproducibility proof or later integrated-main test results.

Resource samples and shared-cover refresh statistics are observations from
separate scripted runs, with first-use preparation and other integrated source
changes. They are not a matched performance benchmark or a neutrality claim.
Native evidence here is one actual S2 home and two output sizes; procedural
geometry checks broaden the footprint cases without proving every district's
art or replacing actual later-segment visual review.
