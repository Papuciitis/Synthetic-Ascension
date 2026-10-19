# S3 Guard-loggia Implementation Plan

**Execution status, later 19 October 2026:** completed against released base `a798043d`, through `6d1a0cd7` including review evidence. This is the historical executed plan, not a pending lane request. Current ownership and next scope are in the [production register](06-production-ownership-and-status.md) and [next packet](07-s3-refinement-and-next-family-packet.md).

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task in this chat after explicit lane release. Native execution is the selected method; do not spawn implementation agents or create another worktree.

**Goal:** Introduce one recognisable guard-office/guard-loggia architectural family on S3's existing civic parcels while preserving every physical, interaction and seeded-generation contract.

**Architecture:** Forward the already selected family through instance context, then select a family-specific facade/roof form provider under the existing kit and roof owners. A pure geometry plan drives deep arch bays and a supported compact watch mass. Ordinary houses and other themes retain the handed-off base; no checkpoint topology changes occur.

**Tech Stack:** Godot 4.7.1, GDScript, existing Polygon2D/material/roof-occlusion systems, modular original PNG assets and native PowerShell capture tooling.

**Spec:** [Selected bounded scope](03-phased-delivery.md), [generation contracts](02-generation-contracts.md), [asset brief](05-s3-asset-brief.md).

## Global Constraints

- Keep the current north-up top-down game, natural uneven streets, temperate daylight, quiet combat ground and convincing attached shadows.
- Preserve the current civic selection rule and physical workshop/shop/passage/house template.
- Existing interactions, enemy populations, rewards and gate state remain the comparison baseline.
- Gate piers, an overhead service gantry, a dogleg inspection route and a new booth footprint belong to the next separately fitted checkpoint phase.
- All four entrance directions retain their exact real openings and receive fitted entry treatment; passage buildings keep both real exits.
- Irregular/narrow parcels keep fitted family forms and omit unsupported optional watch modules; never bridge a notch with a bounding-box facade.
- Forward the family selected from the original attempt seed; never reroll from the manager's mixed/retry seed.
- Authored S1, Hub, DonJon geometry/presenters and legacy roofless exploration structures are outside this implementation.
- Original activation guard: no production/asset/engine/Git work before lane release. That dependency was satisfied at `a798043d`; it is not a new confirmation requirement. Current scope/engine coordination follows the production register.

## Review Focus

1. A non-south or even-width irregular entrance must stay visibly and physically open, including a passage's second exit — Task 2.
2. A narrow/L parcel without watch support must retain recognisable guard architecture without drawing a mass over its notch — Task 2.
3. A player behind the raised watch body must remain visible at every relevant pixel, including neighbouring roofs near the actor shader's **32-triangle** limit — Task 3.
4. Continue/reload or a different stream order must retain the selected theme, identical physical/loot IDs and the same family forms — Tasks 1 and 4.
5. A closed inspection arch must not look like a usable doorway, and optional props must not carry the family's identity — Tasks 3 and 4.

## Source baseline and activation

The coordinating designer reports the completed 18-plate handoff committed as `ef4f4376`, after the pushed WIP checkpoint `d0f99e0614959bceb86514b0347f3e96f496fbea`. The concept [completion README](../../art/concepts/2026-10-19-segment-directions/README.md) and selected [plate 03](../../art/concepts/2026-10-19-segment-directions/03-s3-checkpoint-lanes.png) have been read/viewed. Plate SHA256 is `3CC022A165A5D2611D1DEEACDFCECA35F509CF42F16EE82F3CD5640B4822F71B`, matching its final manifest.

[Planning source snapshot](s3-planning-source-snapshot.json) preserves twelve pre-release file hashes from earlier on 19 October. Its activation/reconciliation requirement was fulfilled before implementation against `a798043d`. It is historical, **not the released baseline or current hashes**; use the audit's verified source manifest for the completed candidate. Preserve other owners' files and never reset the checkout to match old planning hashes.

Historical planning seams: kit/roof calls originally had seven/four arguments and the wrapper lacked a segment switch. Implemented seams now append optional eighth/fifth visual-profile arguments; the wrapper accepts segment, common-base, detail-hide and natural-target options. Both real parcel paths retain existing volume/roof configuration. Do not reimplement these completed interfaces.

The commands below were planned before release and executed after explicit lane transfer. Final results, deviations and review status are recorded in the audit; they are not inferred from these checked boxes. Resolve the supplied Windows engine path once as `$s3Engine`; verify it is a file. Use the project's existing isolated profile/no-save capture discipline, and never run while a human playtest or another engine job is active.

## Task 1 — Family routing without generation changes

**Files:** Modify `core/systems/world/proc/SegmentThemeData.gd`, `core/systems/world/ChunkManager.gd`, `core/systems/world/proc/ChunkGenImpl.gd`, `core/systems/world/proc/chunkgen/ChunkGenDistrict.gd`, `core/systems/world/proc/SiteParcelsImpl.gd`, `scenes/world/buildings/CityBlockKit.gd`. Create `scenes/world/buildings/DistrictVisualProfiles.gd` and `tools/tests/DistrictFamilyVisualTest.gd` / `.tscn`.

**Interfaces:**
- `DistrictVisualProfiles.resolve(family: StringName) -> Dictionary` returns a fresh dictionary with `family_id`, `profile_id`, `roof_form_set_id`, `facade_form_set_id`. `checkpoint_lanes` selects `checkpoint_guard_loggia`; all other/unknown IDs select `common_base`. No random calls.
- Add manager/generator `district_family: StringName = &""`; theme application and generator synchronisation copy it. Both street/fill dictionaries forward `district_family`.
- Add instance-local `district_common_base_preview: bool = false` on manager/generator, forward it into both parcel dictionaries, and select an empty/common profile when true. It changes only presentation selection; the selected family, theme and plan stay intact. This supports paired native evidence without a second mutable global preview switch.
- Append `visual_profile: Dictionary = {}` to `CityBlockKit.configure`; the parcel path resolves a fresh profile and adds `visual_seed = building_id`. The kit only selects the guard family when its existing `civic` flag is true; otherwise effective profile is `common_base`.
- Keep `preview_original_materials` unchanged. Do not use it to compare S3 family against the common base: it removes the entire base kit. The focused tests instead supply empty/base versus guard profiles on the same styled fixture.

- [x] Write failing `DistrictFamilyVisualTest` cases: all 14 source IDs route deterministically; only civic `checkpoint_lanes` selects guard; family survives theme application/sync after manager seed is changed; applying a second theme clears the previous family; missing identity uses base. Two coexisting managers with different preview flags must retain independent selection. Assert physical snapshots and caller-owned RNG states are equal with base/guard routing; later generated parcel signatures cover internal RNG outcomes without exposing new runtime RNG diagnostics.
- [x] Run the new scene with `& $s3Engine --headless --path . res://tools/tests/DistrictFamilyVisualTest.tscn --quit-after 3000`. Expect failure at absent family/profile interface, not an unrelated parser failure.
- [x] Implement the interfaces and forward both actual parcel paths, keeping every template/civic/RNG/loot decision in place. Emit effective `district_visual_profile` metadata on the kit; use a fresh profile dictionary per building to avoid shared seed mutation.
- [x] Run the new scene plus `CitySegmentCoverageTest.tscn` and `CityGenerationMaterialTest.tscn`. Expected: zero failures; existing all-theme snapshots/paving policy remain equal. Until Task 3, profile routing may render the handed-off base.
- [x] Review the scoped diff and commit only this task's files under the released sole Git lane; do not push.

## Task 2 — Pure fitted guard-office geometry

**Files:** Create `scenes/world/buildings/CheckpointOfficeForms.gd`, `tools/tests/CheckpointOfficeFormsTest.gd` / `.tscn`.

**Interfaces:**
- `CheckpointOfficeForms.plan(footprint_px: PackedVector2Array, roof_support_px: PackedVector2Array, doors: Array, cell_px: int, visual_seed: int) -> Dictionary` is pure: inputs are copied, no nodes/resources/RNG are mutated.
- Inputs are in the owning chunk's pixel coordinates; doors are the existing normalised chunk-cell records. `roof_support_px` is the actual supporting roof polygon converted into the same coordinate space before extra watch extrusion. Rendering converts plan points through the owning roof's transform exactly once.
- Output keys: `arch_bays` (kind `closed_inspection` with supported span/rect), `entry_recesses` (original door record and physical opening rect), `roof_planes` (polygon, lift and form kind), `watch_support` (polygon or empty), `has_watch: bool`, `fallback_reason: StringName`. Every emitted form records its actual support. An empty/degenerate footprint returns an empty plan and `invalid_footprint`.
- Initial design constants at 64 px/cell: rectangular facade height **192 px**, minimum closed bay **128 px**, target bay **160 px**, masonry pier **24 px**, recess depth **24 px**; compact watch support **128×128 px**, support margin **16 px**, extra watch lift **96 px**. Scale by `cell_px / 64.0`. Irregular reduced-family facade keeps the base's **112 px** height. These are initial bounded prototype proportions; any visually motivated revision must update tests and the audit together.
- Fit doors first. Use exposed south-facing edge runs for visible arch bays, subtract complete real doorway spans, then fit whole closed bays with remaining wall piers. Cardinal recesses follow each original direction, never rotate a south-facing painted facade. Watch candidates are northwest, northeast, southwest, southeast in that fixed order; `posmod(visual_seed, 4)` selects the starting candidate, then try each once. Omit the watch if its entire support plus margin does not fit.

- [x] Write failing pure tests for rectangles `Rect2i(2,4,11,9)` and `(15,4,9,9)`, both existing kit fixtures; four cardinal two-cell doors; two-ended passage; even-width normalised north/east records; L/recess outlines from existing fixtures; a narrow shape too small for watch support; and empty/degenerate input.
- [x] Assert repeated output equality; byte-identical input arrays; original opening count/coordinates retained; every closed bay lies on an exposed solid span; no closed bay overlaps a real opening; all watch-support corners/margins lie inside support; irregular notch has no facade/roof bridge. Assert the narrow case has arch/recess family forms but no watch, with an explicit reason.
- [x] Run `CheckpointOfficeFormsTest.tscn`; expect absent planner/failed assertions. Implement the smallest geometry-only provider satisfying the interfaces and constants.
- [x] Rerun that scene with zero failures. Inspect the emitted shape data for all fixtures before connecting rendering; keep test fixtures separate from natural-production claims.
- [x] Review and commit this task's planner/tests under the held lane; no push.

## Task 3 — Architectural forms, original assets and full occlusion

**Files:** Modify `CityBlockKit.gd`, `CityBlockFrontages.gd`, `RoofOverlay.gd`; extend `CheckpointOfficeForms.gd` and its tests. Create the two architectural assets and provenance specified in [asset brief](05-s3-asset-brief.md). Extend `tools/tests/PlayerRoofOcclusionTest.gd` and `DistrictFamilyVisualTest.gd`.

**Interfaces:**
- Append `visual_profile: Dictionary = {}` to `RoofOverlay.apply_city_material`; after its existing material/footprint adjustment, the selected guard branch uses the family planner instead of `CityBlockRoofForms.compose`. Base branch remains unchanged. Store the resulting plan as `district_form_plan` metadata for the kit and tests.
- `CheckpointOfficeForms.compose_roof(roof: RoofOverlay, plan: Dictionary, textures: Dictionary) -> void` attaches one named family composition under the existing `RoofPoly`. Rendered caps/upright returns carry `city_roof_form` and the appropriate lift/full-form occlusion metadata. They inherit real roof fading and existing door-notch clipping.
- `CheckpointOfficeForms.compose_frontage(kit: Node2D, plan: Dictionary, textures: Dictionary) -> void` renders supported deep arch/return geometry and cardinal recesses through the existing kit. Guard branch replaces its corresponding generic facade/roof/pressure-plant treatment; shared shadow/entry/status behaviour stays with existing owners. Maintain exactly one base roof owner and no new physics/IndoorVolume node.
- Both composition methods receive texture keys `arch_open`, `arch_closed` and `slate`; missing optional painted detail falls back to the same geometry/material rather than another building type. The two reviewed arch masters are required for final asset acceptance.
- Small decorations remain separately identifiable as `district_optional_detail`; hiding them must retain all architectural geometry. Existing security/search labels remain visible.

- [x] Write failing integration tests proving a guard civic parcel has one guard roof composition and arch-bay geometry, while base/non-civic/other-theme parcels retain their existing form signatures. Assert no stacked generic civic composition, no duplicate lamp/records board, and no additional physics/volume nodes.
- [x] Extend occlusion tests with points inside the watch cap and its upright south/east faces at roof alpha 1.0/0.4/0.0, actor in front, actor behind, inside entry, irregular recess and unload. Assert covered pixel strength follows alpha and uncovered/front pixels stay unchanged.
- [x] Add a representative neighbouring-roof fixture near the actor. Check all sampled pixels under guard mass remain covered and `_triangles.size() <= 32`. Reduce/simplify redundant rendered/coverage forms if necessary; do not raise shader limits or rewrite the global occlusion algorithm for this pilot. If no safe compact watch form fits the contract, keep the safe fallback and report that specific limitation for review.
- [x] Invoke the imagegen skill and produce the two assets under the released production lane, using the inspected references and the asset brief. Inspect generated originals and alpha/support edges before integration. Save exact prompts, returned paths, hashes, anchors and display scale. No scripted bitmap edits or whole-scene paste.
- [x] Implement rendering and asset selection. Reuse broad slate/material/light/shadow helpers, leaving ground textures/shaders and generic landmarks unchanged. No watch tower “door” or stair destination is added.
- [x] Run `CheckpointOfficeFormsTest`, `DistrictFamilyVisualTest`, `PlayerRoofOcclusionTest`, `CityBlockKitTest`, `CityBlockProceduralTest` and `CityPlannedBuildingTest`. Expected: zero failures, all four entrances/irregular cases preserved. Review native unpopulated captures at both window sizes before moving-combat evidence; revise proportions if family identity is weak.
- [x] Commit scoped source/assets/provenance/tests after review; no push.

## Task 4 — Natural production, streaming and review packet

**Files:** Extend `tools/capture/run_city_block_preview.ps1`, `tools/dev/CityBlockPlayablePreview.gd` only as needed for S3 family evidence. Create `docs/audits/2026-10-19-s3-guard-loggia.md` and a new evidence directory `docs/art/reference/2026-10-19-s3-guard-loggia-v1/`. Update district packet status without touching the DonJon companion.

**Interfaces:**
- Add `[int]$Segment = 2`, `[switch]$DistrictCommonBase` and `[switch]$HideDistrictDetails` to the capture wrapper. Forward `--segment=$Segment` and each selected preview switch; preserve isolation, active-engine guard, hidden-process behaviour, output-folder protection and timeout policy. Extend captured hash lists to every changed family source/asset and the settings used.
- Add preview flags `--district-common-base` and `--hide-district-details` for evidence only. Before adding the instantiated Game to the tree, the former sets its manager's `district_common_base_preview = true`, using Task 1's instance-only path; it preserves selected family, terrain and layout and must not use `preview_original_materials`. The latter hides only nodes marked `district_optional_detail` after chunk generation and again after reload.
- Native output records attempt/plan seeds, theme/family/effective profile, actual chunk/role/door direction, outline kind, watch presence/fallback, source/asset hashes and save-write count. Require actual guard-family selection in the targeted S3 reward-building sample.

- [x] Extend the production fixture to enumerate S3 seeds in stable order (starting with known base sample seed **1**, then **211** and **16102026**) and record actual civic street/fill/reward examples. Check actual role presence; if no naturally absent checkpoint appears in the bounded search, label the missing-role synthetic check separately instead of inventing a natural example. Verify all fourteen other family-routing outcomes and the existing S11 fallback remain correct.
- [x] Compare guard/common-base styled snapshots: exact blocker kind/mask/variant, floor stamps/alpha, real doors/footprints, clear/access masks, IndoorVolume bounds/IDs/config, secondary identity/security/reward values, later parcel signatures and directly owned fixture RNG states. Confirm reload and different chunk orders reproduce the same physical state and family plans. Existing base-vs-original fixtures remain separately intact.
- [x] Run the changed-path regression set once: new family/planner suites; existing city kit/procedural/planned/material/coverage suites; reachability; world terrain/ground; roof occlusion; boss clear court; chunk data/rendering/physics; S1/Hub regression where shared paths changed. Every run must exit 0 with zero failures. Record preexisting diagnostic/performance limits without silently changing thresholds.
- [x] Run native S3 normal/small/reduced captures with the released engine. Example after extending the wrapper: `& ./tools/capture/run_city_block_preview.ps1 -Engine $s3Engine -Review small -Segment 3 -WorldSeed 1 -OutputDirectory ./docs/art/reference/2026-10-19-s3-guard-loggia-v1/native-small`. Preserve real perimeter/door travel, triggered security clearance, cutaway entry/exit, unload/reload and controlled outside combat. Existing harness god mode/ambient-spawner limits stay labelled.
- [x] Capture paired base/guard views with all optional details hidden at **1280×720 and 960×540**. Coordinating designer reviews arch depth, supported compact watch silhouette, actual entry/readability and closed-bay interpretation. If architectural distinction fails, revise forms before adding detail.
- [x] Compare content/blocker chunk costs and repeat-travel node/resource counts with the released base. Treat recording timings as diagnostics, not an unrecorded performance benchmark. Reuse texture caches and avoid per-instance image decoding/new world scans.
- [x] Run `ScriptParseAuditTest.tscn` **last**; if strict warning validation is required by the base handoff, use its isolated-copy workflow rather than changing working project warning settings. Hash all captured sources/assets again; regenerate affected evidence when hashes differ.
- [x] Write the audit with actual results, sampled-review limits and unresolved issues. Make the concrete packet available for coordinating designer review through the existing workflow, then commit the scoped final evidence/docs under the sole lane. Push only on a current explicit push instruction; the earlier checkpoint request does not authorise publishing every future prototype.

## Completion state

The plan was executed inline after explicit lane release against `a798043d`. Final evidence and rulings are in the [audit](../../audits/2026-10-19-s3-guard-loggia.md). Measured doorway returns require an 80 px portal reservation; the compact watch adds a 32 px pitched cap above its 96 px upright mass. Both revisions have failing-then-passing regression evidence. Native acceptance uses the project's canonical 64 px cell scale. The pure planner scales its geometry; arbitrary whole-game scales remain unaudited.

Task 4's coordinating aesthetic review remains an external acceptance limit, not a code/test completion claim. This packet makes the concrete prototype available for that review. No new push is authorised.
