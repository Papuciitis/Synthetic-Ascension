# L2 ground care implementation plan

**Goal:** Make household care visibly local to actual generated S2 homes and
replace S7's rejected broadleaf moss without changing physical generation.
**Spec:** HANDOFF.md, docs/art/2026-10-20-ground-material-direction.md and
 docs/art/reviews/2026-10-20-linux-s2-lead-review/README.md.
**Received integration:** 24d838f77df1b85ca3ec8636ec6a4900a6b19f7d.
**Execution:** Continue the user's authorized next implementation in the existing
Linux production checkout. Root owns Git and the sole Godot execution lane.

## Global constraints

- Keep semantic terrain IDs, RNG, physical routes, rewards, cover and navigation.
- Keep eight coverage slots. Lawn is presentation layer 13, never a terrain ID.
- Preserve original rough grass/meadow/scrub, organic boundaries and some
  untended homes; only actual noncivic row_house parcels in S2 receive care.
- Keep the tested garden source pixels, aspect, anchors and scale; S3 is unchanged.
- Preserve existing before evidence. L3 furnishings/masonry and V1 entity depth
  remain separate, open gates. ART_STATUS and source direction remain Windows-owned.
- Use Godot4.7.2 Compatibility through run_city_linux.py; one engine at a time.

## Interfaces

- WorldArt.GROUND_CARED_LAWN_INDEX = 13; source12 is damp_moss_soil, source13
  is cared_lawn. Existing terrain indices remain 0,1,5,6,10,11,12.
- CityBlockKit.ground_care_spec() -> Dictionary: local actual footprint,
  doors, visual seed and optional measured garden contact; empty for ineligible
  use/civic/untended variant3. No RNG is consumed.
- GroundSplatRenderer.paint_domestic_care(coord: Vector2i, spec: Dictionary)
  writes only light_map.B on eligible existing overgrowth cells after stamps.
  care_at(global_cell) probes it; care_signature(coord) returns exact care bytes
  for deterministic reload evidence. No extra coverage allocation.
- ChunkManager._activate_ground_care(coord, chunk) invokes eligible specs after
  final floor stamps for both batched and immediate generation.
- Shader blends layer13 at320 world px only on S2 overgrowth with local care;
  final coverage/paving and physical ownership remain unchanged.

## Task1 — Local care policy and renderer

Files: new core/systems/world/ground/CityGroundCare.gd;
GroundSplatRenderer.gd, ground_splat.gdshader, ChunkManager.gd, CityBlockKit.gd;
new tools/tests/CityGroundCareTest.gd/.tscn and WorldGroundSplatTest.gd.

- Write behavioral tests first: actual-use/variant eligibility; retained
  footprint/door/garden context; both known home shapes; bounded asymmetric
  field with wild cells beyond it, no care inside footprints/door corridor;
  no coverage/material/brightness/stain changes; paving and indoor stamps
  protected; stable repeated application; base/wrapped reuse and clear reset.
- Observe RED before implementation. Build one soft irregular pocket from the
  planted corner and nearest actual footprint edge, rather than a rectangular
  surround or whole-building ring. Fixed seed/global-coordinate noise only.
- Connect after stamps. Shader reads blue using the unwarped light-map position
  and blends only in the selected overgrowth branch; keep noise/edge hierarchy.
- Run CityGroundCareTest and WorldGroundSplatTest. A natural test then checks
  both actual homes, actual wild/untended controls and unchanged physical data.

The first native bed trial exposed a field almost entirely clipped by its
actual footway. A tests-first correction supplies final vegetation eligibility
to the planner: preserve a usable original pocket, otherwise choose one nearby
vegetated center at the real planted corner and reorient to its footprint edge.
Keep all footprint, access, six-cell locality and owner-chunk exclusions.

## Task2 — Material sources and derived cache

Files: WorldArt.gd, BakeGroundMaterials.gd, WorldTerrainTest.gd,
GroundMaterialCacheTest.gd; rebuilt assets/world/ground/baked resources.

- Write RED assertions for14 registered sources, selected moss/lawn paths,
  original seven terrain mappings and lawn excluded from semantic grass slots.
- Replace layer12, append layer13, use320px lawn repeat without making13 a
  semantic overgrowth material. Do not retint wilderness or change terrain IDs.
- Validate source-checkout bake provenance with guarded types/count/order/hash
  checks before accepting a compatible cache. Exported builds must keep loading
  without requiring raw PNG/import/JSON files; scope source-file hashing to
  editor builds, as existing project paths do.
- Reject gray fallback/missing source/import pixels in the bake tool, and
  require fresh imports before native bake. Rebuild array and provenance together.
- Keep synchronous startup intact; transition preparation yields between full
  provenance hashing and native resource loading/upload so they do not share
  one loading frame. The existing250ms warmup assertion stays unchanged.
- Run WorldTerrainTest, GroundMaterialCacheTest and native
  TransitionResourceWarmupTest (all cached pixels/mipmaps equal fresh preparation).

## Task3 — Natural fixtures, evidence and review

Files: focused L2 natural survey/preview adapters and
new docs/art/reference/2026-10-20-linux-l2-ground/; LINUX_STATUS.

- Extend the existing capture signature with actual care bytes and bound-array
  path/source/cache metadata. Find real wild/untended and natural S7 moss/mud/
  paving context without changing its plan; preserve exact sample identity.
- Capture the same bed/tree homes at960 and1280, a natural uncared comparison,
  natural S7 seed4/canal_services with actor/tell context and a short occupied
  comparison. Reuse L1 footage as before evidence; do not recapture all old runs.
- Check real rendered cache inputs and inspect native images. Correct concrete
  visual failures before packaging; test success alone is not art acceptance.
- Run scoped terrain/splat/cache, natural/service/procedural/street/roof checks;
  ScriptParseAudit last. Independent code/evidence review, explicit staging,
  normal commits and own-branch push; if authentication is still missing, retain
  local commits and give the exact relay command/hash.

## Skill guidance

The user explicitly reminded this implementation to use the installed GDScript,
game-feel, level-design and roguelike-game-designer skills. Apply their relevant
checks here: typed lifecycle-safe code, readable attacks and transient feedback
on the changed surfaces, preserved entry/routes and reproducible generation.
Controlled god-mode footage is visual evidence, with no build/balance inference.

## Review focus

- North-entry tree stays at the southwest planted corner; care follows the
  planting/footprint rather than assuming door-front placement.
- Thin cared patches beside footways must remain visible without green pavement.
- Off-chunk/wrapped care cannot survive chunk replacement or touch another owner.
- Broken/malformed/stale cache metadata fails safely without breaking exports.
- Missing props do not prove neglect; qualify actual usage/variant or wild ground.
