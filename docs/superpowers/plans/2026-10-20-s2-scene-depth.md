# S2 frontage and footprint depth implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Root owns every engine run and Git operation; the scene worker owns edits only in the isolated scene worktree.

**Goal:** Correct the real L-house cast and remove the sharp rectangular frontage apron while preserving gameplay and current lighting for an interpretable scene comparison.

**Architecture:** Build the constant-height shadow sweep from the actual footprint and clip it against actual occupied outlines. Fit the S2 presentation footway to its entry-bearing edge and evaluate an external verge transition against the whole semantic surface, independently of geometry subtraction pieces. Retain the existing world sun, material palette, camera, physical floor stamps and ground-care data.

**Tech stack:** Godot4.7 GDScript, Geometry2D, CanvasItem shader, native Compatibility renderer for pixel evidence.

**Spec:** Main-workspace scratch audit `.superpowers/handoff-linux-visibility-20261020/scene-visual-audit.md` and `docs/audits/2026-10-20-concept-fidelity-and-chat-audit.md`; the user specifically identified the square apron, incorrect L shadows and flat scene depth. Root accepted the bounded design and assigned this isolated implementation.

## Global constraints

- Product edits only in `/tmp/synthetic-ascension-linux-scene-20261020`, based on31a1f6ce. No Git or Godot command by the scene worker.
- Wait for root’s valid RED before production edits; parser/import failures do not count as RED.
- Scene ownership: `CityBlockKit.gd` ground-shadow/clip functions, `CityStreetFrontage.gd`, and a dedicated footway edge material/helper if required. Coordinate common Kit edits with L3’s different functions.
- Do not edit WorldArt, wet/cared-ground assets or ground-care logic (root’s L2), or atmosphere/profile/Game binding (other agent).
- Preserve physical cells, existing door openings, route/reward/encounter state, original floor stamps, care bytes, RNG schedule, save behavior and visibility shaders.
- Preserve S3 accepted architecture/shadow families. The new scene policy is S2 only. Keep world sun direction, nominal126/170cast height, shadow color/z and cutaway behavior fixed for the first comparison.
- No new raster assets, new district or camera/projection change. Keep prior native visibility evidence immutable.

## Review focus

- A real inward L corner must permit a valid neighboring-wing cast while an empty northwest parcel corner must not act as a caster (Task1 literal probes).
- Subtracting a neighboring parcel’s bounds must not erase shadow on that neighbor’s actual concave exterior (Task1 neighbor fixture).
- A north-facing doorway on the inner L edge must receive its approach there, instead of a phantom strip on the box’s top edge (Task2 actual composer fixture).
- Splitting/clipping footways must not make independent alpha seams or double-dark overlap; test joins and a clear approach core in Task2.
- A bounded external edge transition must be rendered by the production overlay and retain an opaque approach core; uniforms/API existence alone are insufficient (Task2 native RGBA probe).

## Task1: Exact ordinary S2 footprint casts

**Files:** Modify `scenes/world/buildings/CityBlockKit.gd` `_add_ground_shadow()` and the sun-shadow branch of `trim_paving()`; add a focused geometry helper only if it keeps these operations easier to review. Tests: `tools/tests/CityFootprintShadowTest.gd/.tscn`, shared test fixture `CitySceneDepthFixture.gd`.

**Consumes:** Exact `RoofOverlay.footprint_outline_px`, existing `WorldDepthStyle.offset_for_height(height:float)->Vector2`, existing kit/parcel context. **Produces:** Same `city_sun_shadow` Polygon2D presentation/metadata, with disjoint exact sweep pieces and correct known-neighbor cuts; existing callers keep their `trim_paving(footprints:Array[Rect2i],cell_px:int)` interface.

- [x] Write a production-kit test using the recorded real house944996572 outline. Literal expectations before and after trimming: (150,650)clear, (340,680)covered once, (150,900)covered once. Assert no overlapping pieces on a dense grid and preserve65% roof-open residual ground cast.
- [x] Add a second concave occupied neighbor: (150,850)outside its actual footprint remains shadowed, while (150,950)inside it clears.
- [ ] Root runs `res://tools/tests/CityFootprintShadowTest.tscn` headless from the isolated project. Expected current failures: phantom northwest cast, missing notch cast, lost neighbor-notch shadow; no parser/import failure.
- [ ] Implement exact outline sweep and actual-interior cuts, restricted to S2. Union P, P+offset and swept edge quads; avoid convexifying all points. Handle multiple polygon contours deliberately, keep emitted filled pieces disjoint, and use actual kit outlines for known cuts. Preserve rectangle fallback for occupants without an outline.
- [ ] Extend the test with rectangle equivalence and a rotated/recessed footprint, then root runs focused GREEN. Reuse existing independent foliage-UV/cutaway checks and guard render fixtures.
- [ ] Root reviews and commits the bounded change when all required checks pass; worker performs no Git operation.

## Task2: Entry-shaped footways with natural external edges

**Files:** Modify `scenes/world/buildings/CityStreetFrontage.gd`; create `scenes/world/buildings/city_footway.gdshader` if needed. Leave shared `city_paving.gdshader` unchanged because interiors and other accepted surfaces use it. Tests: `CityFootwayGeometryTest.gd/.tscn`, `CityFootwayEdgeRenderTest.gd/.tscn`.

**Consumes:** Real kit bounds, real roof footprint, normalized cardinal doors, lane arms and chunk extent. **Produces:** Same `ConnectedStreetFrontages`/`ParcelFootway` production geometry, now fitted to the actual entry edge, plus a bounded external transition. Existing `compose(...)` caller API remains; `plan(...)` can gain an optional exact outline while preserving its existing rectangle fallback for current users.

- [x] Write actual composer geometry tests: recorded bed south door core at(544,1120); no rear slab at(544,528). With a valid north door on the same L’s inner edge, require landing at(288,736) and no phantom box-top landing at(640,528). Assert no actual-interior intersection or source-footprint mutation.
- [x] Write a native GPU RGBA test that renders the actual production footway alone in a transparent SubViewport. At chunk-local y1150 require an opaque door approach core, fully clear far margin, and6..48partial-alpha pixels on each external lateral edge. The existing1.5px edge should fail this behavior.
- [ ] Root runs headless `res://tools/tests/CityFootwayGeometryTest.tscn` and native `res://tools/tests/CityFootwayEdgeRenderTest.tscn`. Expected current RED: wrong inner-L landing/phantom box-top slab; near-single-pixel native alpha edges. A blank/broken viewport or wrong fixture is not valid RED.
- [ ] Fit a continuous modest frontage strip to the actual door-bearing exposed edge, plus a door-width-aware connector to a nearby real lane. Keep cardinal direction policy symmetric; use real outline cuts so the L’s empty ground remains available. No physical floor, care or RNG edits.
- [ ] Evaluate edge alpha using a world-anchored deterministic external boundary and initially12–24pxtransition; preserve an opaque approach/connector core. Use the unsplit semantic shape, not each subtraction fragment, so internal joins and building-contact edges do not feather into cracks. Reuse existing paving source and palette. Avoid a uniform sandy halo or broad green fog.
- [ ] Add cardinal, adjacent/split-surface seam and stream-reload signature checks; root verifies headless/native GREEN and appropriate existing tests.
- [ ] Root reviews and commits only the bounded scene changes; no worker Git operation.

## Task3: Real occupied comparison and integration

**Files:** Root capture harness/evidence, no new gameplay behavior. **Consumes:** Tasks1–2, unchanged baseline atmosphere and visibility. **Produces:** Honest native same-location comparison and a source/resource/test ledger.

- [ ] Root runs the actual selected S2 bed house944996572 at normal and960×540, tips cleared, natural details/HUD retained. Static camera/actor controls make the geometry/edge comparison interpretable.
- [ ] Root repeats the occupied fight with real production attacks/projectiles/visibility and Reduced Motion/Combat Flashes Off. Preserve original and new source hashes separately; moving frames are not pixel-identical controls.
- [ ] Judge actual geometry/contact and actor readability. Reject phantom northwest caster, missing notch shadow, doubled shadow intersections, soft halos, joined-surface cracks or loss of the opaque entry/route core.
- [ ] Root runs focused regressions: CityBlockKit, CityBlockProcedural, CityStreetFrontage, WorldFootprint, CityGroundCare, accepted guard rendering and relevant visibility suites. Any expected rectangle-only assertion update must cite the exact new occupied-outline contract.
- [ ] Record polygon/material counts, build time and native resource/frame observations. Coordinate one combined view with the other atmosphere owner only after independently inspecting this fixed-lighting comparison. No performance/whole-city-fidelity claim from this work alone.

## Task4: Connected irregular S2 roof planes and shallow support

**Authorization:** The user explicitly called the whole game flat even with shadows. Root accepted the read-only follow-up proposal after initial scene GREEN, authorized a focused RED first, and will observe RED before any roof production edit. Current shadow/paving files remain frozen during the regression queue.

**Files:** Test first: `tools/tests/CityIrregularRoofPlaneRenderTest.gd/.tscn`. After root RED, extend `scenes/world/buildings/CityBlockRoofForms.gd` with a fitted irregular composition path and wire it only in the ordinary S2 irregular branch of `RoofOverlay.apply_city_material`. No new source art or S3 form changes.

**Consumes:** The actual visible `RoofPoly.polygon`, existing clay/slate texture/material, door notches, parent alpha/cutaway, and actual original footprint. **Produces:** Disjoint connected roof lighting planes whose union equals the original visible silhouette, with shallow fascia/eave support contained in the existing occupied visual envelope. On the real bed L, the main east wing has a north–south ridge and the shorter west/front arm an east–west ridge. Keep physical architecture, host cover outline and opaque/cutaway states unchanged.

- [x] Add a native production-fixture RED: use actual bed L, assert the hand-derived original visible polygon (inset10, facade erosion148), inspect actual textured roof polygons for gaps/overlaps/outside coverage, and sample white test input to isolate the shader's roof-plane lighting. Require east brighter than west at equal Y on the main wing; require an independent north/south slope pair on the short arm. The current single bounding-box horizontal gable should fail both native comparisons and supply no connected child planes.
- [x] Keep positive control assertions for actual opaque samples, unchanged physical silhouette, shared WorldCover strength, the real alpha callback, cutaway disappearance/restoration, and the existing S3 irregular presentation. These controls must pass in RED; parser/blank viewport/resource leaks do not establish the missing roof-plane behavior.
- [x] Root ran native Compatibility `res://tools/tests/CityIrregularRoofPlaneRenderTest.tscn`: valid RED14/4, actual exit1, no other diagnostics. Missing connected planes/618gaps; main west/east1.000/1.000; short-arm north/south.722/.722; S3 and existing opacity/coverage/cutaway controls passed.
- [x] Implement fitted existing-asset S2 irregular roof planes only after the gate. Use actual polygon partitions, not a bounding-box compound that fills the notch. Keep planes disjoint and the original visible union exact. Give each meaningful wing its own gable axis and bounds; reuse existing roof shader, material and restrained eave/fascia colors. Make east-facing support consistent with the accepted northeast light. Avoid a new thick outline or a second shaded rectangle.
- [x] Preserve actual door gaps and parent-owned fade/coverage. Native roof GREEN21/0 includes exact mask union, half-alpha and actual shared-cover/cutaway controls. Shallow support stays inside the original covered visible silhouette; S3 and ordinary rectangular composition remain unchanged.
- [ ] Root verifies focused native GREEN, original scene/visibility/guard regressions and actual small/normal matched bed A/B. Judge architectural mass and actor context; native white probes establish light direction, not artistic acceptance.

### Task4a: Existing roof-tile direction follows the turned ridge

Root and independent worker both found the same actual native visual fault: the main ridge turns north–south while its unturned clay barrels still run north–south. This prevents accepting the fitted lighting as a convincing roof. Keep the existing S2 masks/plane values and correct only per-plane source mapping after a fresh RED.

- [x] Add `CityIrregularRoofTextureRenderTest.gd/.tscn`: inspect actual production mesh UV axes, original clay ownership, isotropic and unchanged relative texel density; render source-Y calibration bands through those actual UVs with lighting neutralized. Require source-Y variation across world X on the NS main wing and along Y on the EW arm. S3 retains original source-Y mapping.
- [x] Root observed clean native `scene-roof-texture-valid-red`15/2, exit1: main mesh UV-axis and native horizontal texture-variation failures only, no leaks/other diagnostics. The earlier run's MP3 shutdown leak is a fixture failure, excluded from valid RED; early AudioManager.stop_all(true) and server-frame cleanup follow the existing warmup fixture pattern.
- [x] Turn the NS wing's mesh UV basis90degrees while retaining original texture/scale, the EW attached arm mapping, masks/fade/coverage and all S3/rectangular forms. No source art or shared roof shader edits.
- [ ] Root runs both native roof tests and actual clay/slate normal/small A/B, including the full location. The white-lighting test alone cannot establish tile direction.

## Task5: Exact non-guard casts in later segments

The user meant nonrectangular house shadows generally. Root clarified that the S2-only exact-shadow gate leaves the same demonstrated fault in ordinary S4/S7 L houses. Extend only the exact geometric caster/neighbor clipping to all non-guard kits, preserving `_is_guard()`'s accepted S3 ground-shadow path and custom watch helper. This is shared correctness, not a new district/family/material rollout; S2-only footway and roof-plane policy stay S2-only.

- [x] Add headless `CityNonGuardFootprintShadowTest.gd/.tscn`. Generate actual procedural L parcels through SiteParcelsImpl for S4 and S7 real family selection, both south and east doors. Compare dense actual cast polygons against an independent finite light-ray intersection reference using their real occupied outlines. The reference does not call the production sweep/subtraction helper. Require no phantom bounding-box casts or lost concave-ground casts after actual trimming.
- [x] Root observed clean S4/S7 RED16/8, exit1: each real south/east-door L fixture had50false positives and40/41false negatives. No extra diagnostics.
- [x] Replace the exact-caster/clipping segment predicate in CityBlockKit with the explicit non-guard ownership predicate. Keep guard legacy branch untouched; do not change sun height/direction/color, RNG, physical cells or later-segment ground/roof styling.
- [ ] Root runs later-segment GREEN, existing S2 exact shadows, WorldFootprint and accepted guard regressions, then inspects a real later-segment exterior if needed. No universal custom-family shadow claim.

## Recorded execution outcome — 20 October

Implementation is retained as9eab80dc (connected paving/actual S2 casts) and
346518ee (connected roof planes, turned tile UVs and non-guard cast scope).
The [scene packet](../../art/reference/2026-10-20-linux-scene-depth/README.md)
retains exact REDs, rejected native iterations and two actual-Game matched
legacy/connected roof pairs, each11checks/0failures/0saves at960×540 or1280×720.
Focused final native roof planes21/0 and texture axes17/0 pass; S2 caster13/0,
S4/S7 ray-reference caster24/0 and accepted guard refinement174/0 pass.

Combined main-tree verification found an obsolete rectangular-interior
assertion in the procedural survey. Seed2026's reported shadow occupies its
empty northwest L notch; independent intersections with all three actual
occupied outlines are empty. The corrected strict receiver check preserves
every shadow×receiver comparison, adds transformed deliberate-interior
positive controls and explicitly runs the intended S2 branch. It passes6318/0
across20layouts and is committed separately as02ee8d3a. Failed/diagnostic
records are preserved in the [integration packet](../../art/reference/2026-10-20-linux-integration/README.md), not relabeled as passes.

The combined actual Game visibility run with furnishings/frontage/atmosphere
passes11plates/0failures/0saves. Later final main footprint11/0, care125/0 and
parse557/0 checks are clean. Ordinary/reduced occupied clips belong to the
separate ground/domestic/atmosphere packets; they are not fixed-pixel roof
ablation or matched performance evidence. Review of the whole generated street,
all later district structures, general chunk-seam continuation and ordinary
human play remain open. LINUX_STATUS and dated packets supersede historical
unchecked execution boxes above; they distinguish every exact source snapshot.
