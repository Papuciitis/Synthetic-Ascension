# Domestic Interiors Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the two kept actual S2 homes sleeping, cooking and restrained work/storage purpose, stronger domestic masonry, and a finished frontage while preserving their envelope, doors, useful routes and seeded generation.

**Architecture:** A focused CityDomesticInterior adapter plans from actual floor/wall/door context and composes four measured original props under the existing roof. It applies an explicit domestic wall presentation flag to the actual perimeter and partition cells; the renderer selects an independent domestic material. Existing irregular upper fields and entry returns receive a bounded UV/finish correction.

**Tech Stack:** Godot4.7 Compatibility, typed GDScript, existing ChunkBuildData/ChunkBlockRenderer, original RGBA/AtlasTexture props, shader materials.

**Spec:** `docs/art/2026-10-20-medieval-gardens-and-domestic-interiors.md`, `docs/art/reviews/2026-10-20-linux-s2-lead-review/README.md`, latest `HANDOFF.md`, and `docs/audits/2026-10-20-concept-fidelity-and-chat-audit.md` including Subsequent direct human steering. Detailed measured audit: main checkout `.superpowers/handoff-linux-visibility-20261020/l3-audit.md`.

## Global Constraints

- Root owns Git, the single monitored Godot lane and review/commits. This worker writes tests first and waits for observed RED before product edits.
- Work only in `/tmp/synthetic-ascension-linux-domestic-20261020`; base31a1f6ce. Scene worker separately owns CityBlockKit ground-shadow/paving functions. Do not touch them or L2 care/wet materials.
- Actual generated S2 noncivic row_house only; exclude civic/security, shop/workshop/passage/annex, S1/Hub/S3/Donjon. Do not infer household use from noncivic alone.
- Keep repaired physical perimeter/windows/door holes, existing partitions, roofs/volumes/IDs/rewards, terrain and generation/run/global RNG. No new family, image generation, furniture pack or product-camera change.
- Preserve original cot/hearth PNG hashes, alpha and aspect. Cot contact(530,1345), scale60/632; hearth contact(800,805), scale120/1465.
- Explicit new low-furniture blockers may occupy only fitted reserved cells under the existing HALF_COVER contract; list those additions separately from unchanged original wall topology. Do not call this an unchanged complete blocker set or silently add walk-through solid furniture.
- Existing civic/S3 materials and all previously accepted visibility remain unchanged. Root finishes bounded L2 first; L3 is separately reviewable.

## Review Focus

- Real empty irregular hall spans two volumes: one furniture owner per kit/building, no seam partition/duplicate loot rights (Task1 real-kit test).
- Narrow/partitioned rooms and alternate door directions: no-fit safely omits a group and preserves all required connected approaches (Task1 planner/route test).
- Material ownership: mixed domestic and civic cells sharing a texture retain separate materials, including windows/corner fills and under-roof partitions (Task2 renderer test).
- Stream lifetime and negative coordinates: reload reproduces layout and removes exactly its props/blockers; no manual-block leaks (Task1 regeneration, Task4 native).
- New low furniture and alpha residue: original contact/alpha, short contact shadow, low-cover behavior and roof reveal remain coherent with real actors/loot (Task1 measurements, Task4 native).

## File map and interfaces

- Create `scenes/world/buildings/CityDomesticInterior.gd`: pure fitting/eligibility plus focused runtime composition and wall marking.
- Create `scenes/world/buildings/domestic_stone.gdshader`: preserve original rough stone/mortar/lower-face value; alpha and geometry unchanged.
- Modify `core/systems/world/proc/SiteParcelsImpl.gd`: pass actual wall/floor/doors/ownership to the adapter after final civic/kit identity is known, in both rectangle and irregular paths.
- Modify `core/systems/world/chunks/ChunkBlockVisualCatalog.gd`, `ChunkBlockRenderer.gd`: explicit wall-only domestic presentation flag; separate batch/material including corner fills. Any furniture-art suppression flag must avoid existing low texture/rotation bits.
- Modify only furnishing hookup in `CityBlockKit.gd` if needed; avoid its shadow/paving functions.
- Modify domestic `_plaster`/irregular entry/upper field only in `CityBlockFrontages.gd`; preserve facade alpha/foreground descriptors and cardinal opening geometry.
- Tests: `tools/tests/CityDomesticInteriorTest.gd/.tscn`, `DomesticWallMaterialTest.gd/.tscn`; later focused native fixture changes in `CityBlockPlayablePreview.gd` for circulation/full framing and metadata.

`CityDomesticInterior.plan(context: Dictionary) -> Array[Dictionary]` consumes segment, usage, civic, building_id/visual_seed, cell_px, footprint_px, doors, wall_cells, floor_cells, protected_cells and world_origin, plus the actual connected reward owners' small_count_max, local_encounter_enabled, force_large_loot and area-large classification. Furniture requires a known single-item ambient owner; multi-item/security/large or unknown owners safely omit it while domestic wall material remains independently eligible. Context coordinates are kit/chunk local; world_origin must not affect local choices. It returns records with `kind` cot/hearth/table/crate, `source_path`, `anchor_px`, uniform `scale`, `contact_px`, `ground_rect_px`, `visible_rect_px`, and unique `reserved_cells`. It does not mutate context or RNG.

`CityDomesticInterior.mark_walls(data: ChunkBuildData, wall_cells: Dictionary, context: Dictionary) -> void` marks eligible actual WALL/WINDOW cells only, preserving all old bits/kinds/masks. A wall-only bit value8 is available. Runtime composition creates one child named CityDomesticInterior under its kit, `domestic_layout` metadata and exactly one Sprite2D per record with `domestic_kind` metadata; originals remain cached resources. Group effective Z is PROP_Z, outside RoofPoly's modulate chain.

`CityDomesticInterior.compose(kit: Node2D, manager: ChunkManager, data: ChunkBuildData, context: Dictionary) -> Node2D` owns that composition and records the fitted low-cover cells while the chunk is being built. It uses the pure plan; no duplicate group on repeated invocation. The chunk/kit owns its lifetime.

### Task1: Measured purposeful groups on real floor

- [ ] Root imports baseline, runs `res://tools/tests/CityDomesticInteriorTest.tscn`; expect meaningful missing-adapter assertion, exit1, no parser failures.
- [ ] Implement plan eligibility, actual free-cell/wall/door fit, four sparse groups and bounded deterministic candidate scoring. Use no shared/generation RNG. Preserve a clear center and all real exits; partial no-fit is preferable to obstruction.
- [ ] Compose original anchored art below roof/frontage, with short low contact shadows. Preserve one owner across irregular volumes. Use the existing streamed HALF_COVER recording/physics/projectile path for reserved cells; suppress default random prop art there without changing unrelated cover.
- [ ] Root runs the test GREEN. Tests prove both actual homes, measurements/alpha/contact, eligibility negatives, one-cell no-fit, route connectivity, context/RNG purity and regeneration/lifetime.
- [ ] Root reviews source and commits this bounded deliverable when checks pass.

### Task2: Actual domestic envelope and partition masonry

- [ ] Root runs `res://tools/tests/DomesticWallMaterialTest.tscn` RED before material/renderer edits.
- [ ] Mark exact actual wall dictionaries after final civic/usage is known. Keep UNDER_ROOF=1, CITY_STONE=2 and BUILDING_ENVELOPE=4. Do not mark only partitions or all noncivic cells.
- [ ] Add a separate domestic shader/material/batch key. Carry it through windows and `_add_corner_fills`; retain original source UVs, masks, Z, source alpha and baked lower-face shading. Leave city_stone shader/S3 material untouched.
- [ ] Root runs focused material/renderer/kit/procedural checks GREEN, adjusting physical comparisons only to ignore the new explicit presentation bit and enumerate intentional new furniture cells.
- [ ] Root commits after review.

### Task3: Domestic upper-field UV and entry finish

- [ ] Add focused tests that pin the retained physical doorway and isotropic upper-source texel density, facade alpha/registration and alternate north doorway control; root observes RED.
- [ ] Replace the 82.536×260.64 source crop stretched across304×64 /240×64 polygons (15× /11.84× anisotropy) with isotropic regional sampling. Keep existing112px shutter bays and176px mass; trial sparse divisions at real bay joins, not extra ornament everywhere.
- [ ] Refine irregular south header/reveal/flush contact around its unchanged128px opening. No new door leaf/collider/step; retain V1 registration for opaque planes. Check fruit north entrance/closed south wall and preserve S3 ownership.
- [ ] Root checks GREEN and inspects first native exterior/interior pair before packaging further.

### Task4: Same generated homes, physical circulation and native review

- [ ] Root captures same S2 fixtures: seed16102026/chunk(0,3)/ID944996572 and seed17/chunk(-3,5)/ID2128236757 at960×540 and1280×720. Keep old before evidence.
- [ ] Reach props through production input; verify clear center, all room/door approaches, actual collision/projectiles, ordinary/elite/pickup readability, roof entry/cutaway/exit restoration and exact reload. Keep natural foliage/HUD and neighboring street context. Clear real temporary tips before stills.
- [ ] Suggested bed targets: inside(608,7136), sleeping(352,7072), cooking(736,6880), work(736,7072), outside(608,7392). Fruit: inside(-5536,11296), center(-5536,11488), sleeping(-5792,11552), cooking(-5408,11360), work(-5408,11488), outside(-5536,11104). Validate candidates against actual current blockers; never carve or teleport to force them.
- [ ] Complete whole-cutaway stills with explicit global framing after walking, zoom1; keep moving player camera separately. Report actual IDs, exact layout/added-cell signatures, source hashes, zero saves, native limitations and art concerns. Check the same single loot roll/rights; existing walkability may redirect only its legal position.
- [ ] Root obtains independent review, commits checked work, and returns a bounded keep/rework packet; tests do not close full-street aesthetic acceptance.

Plan self-review: all source brief areas map to a task; API names/types agree; both actual homes and mixed civic/partition materials are test targets. Runtime edits stay behind root's baseline/RED gate. Existing autonomous execution authorization supplies the execution method; this plan does not request renewed user approval.
