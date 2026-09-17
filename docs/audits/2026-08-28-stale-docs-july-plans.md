# Stale-docs audit — the July 2026 plans and specs vs. the code

**Date:** 2026-08-28 · **Tree:** `enemy-world-work` @ `a8a535a` · **Kind:** read-only (nothing modified).
**Scope:** the 12 plans under `docs/superpowers/plans/2026-07-*` and the 8 specs under `docs/superpowers/specs/2026-07-*`. The August plans and the changelogs are covered in the companion stale-docs report.

## Global context (applies to every file)

- **Provenance.** 11 of the 12 plans and all 8 specs were added in one squash commit `af1fc46 "big change"` (2026-07-30) together with their implementing code, so `git log --follow` gives no RED→GREEN history; verification is by grep against HEAD. Exception: `2026-07-30-dev-segment-prefab-baseline.md` was added in `31ca4e0` (2026-08-18).
- **Checkboxes.** 10 of 12 plans still show `- [ ]` on every step, yet every task is in code. Only `dev-segment-prefab-baseline` and `tiled-procedural-world-rendering` are ticked. **Unticked boxes must not be read as open work.**
- **References.** No index links any of these docs (`README.md`, `CLAUDE.md` do not exist). Two August plans mention "audit-closure"/"save-integrity" as test-suite names only. `docs/PERFORMANCE_PATCH_CHANGELOG.md` and `docs/EQUIPMENT_FOUNDATION_CHANGELOG.md` are the changelogs these plans asked for, and they repeat some of the same stale claims.
- **Environment lines** (LOW, 100%): plans quote a `C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-...` path and "The workspace has no Git repository" — the repo has existed since `d77f1f3` (2026-07-21).

Actions below: **UPDATE DOC** = add a "superseded/implemented — see X" banner or fix the specific line; **REVIEW** = a code decision is needed; **KEEP** = historical constraint, harmless.

---

## 1. `plans/2026-07-28-audit-closure.md` (+ spec) — DONE, two stale specifics

Verified in code: `runtime_enabled`, `scripted_value_weight`, `compute_item_value`, run counters, `BagInventory.debug_bag = false`, `resonance_per_sec = 0.00342`, `DistrictPlan` fallback fields and the min 5-chunk primary→exit rule, `export_presets.cfg` + `tools/package_release.ps1`, `AuditClosureTest` (16 tests).

- **MED / 95%** — `plan:79`, `spec:51`: rings configured with `duplicate_feed_value = 0.10`. Code: `ring_crusher.tres:30` and `ring_regeneration.tres:29` are `0.0`; the field (`data/items/ItemData.gd:17`) is read by **no** `.gd`; `ItemInstance.feed_roll` routes through `merge_from`; `AuditClosureTest.gd:217-228` asserts normal progression. Superseded by the equipment-foundation spec line 44. → UPDATE DOC; consider deleting the dead export. Risk: a contributor sets it on a new item and it silently does nothing.
- **LOW / 95%** — `plan:52` names `EnemyDrops.compute_drop_rarity(...)`; code is `finalize_rarity(rolled_base, elite_bonus, threat_bonus)` (`EnemyDrops.gd:128`); rarity range roll moved to `ItemGenerator`. → UPDATE DOC.
- **LOW / 95%** — `plan:138` `DistrictPlan._validation_score` → public `static func validation_score` (`:40`). → UPDATE DOC.
- **LOW / 90%** — `plan:180` "preset with version 0.0.0.25.5": `export_presets.cfg:33-34` carry `"0.0.0.25"` (4-part Windows version) while `project.godot` is `0.0.0.25.5` and the package script reads the project value. → KEEP (note).
- **LOW / 100%** — "DevSetCollisionTools remains unchanged": it was later gutted to a UI-less action service (`autoload/DevSetCollisionTools.gd:3-9`). Historical.

## 2. `plans/2026-07-28-enemy-lifecycle-performance.md` (+ spec) — DONE, two headline claims contradict

Verified: tooltip helpers, `EnemySniper.is_combat_committed`, `simulation_tier`, `is_retirement_protected`, spawner cull API, `EnemyIndex.retire_enemy`/`simulation_tier_counts`/`get_debug_counters`, interior/encounter metadata, `ChunkManager.loaded_chunk_count`, `PerformanceOverlay.collect_snapshot`, projectile timing, stress/lifecycle tests, bulk-buffer renderer rejected per the changelog.

- **MED / 90%** — `plan:206-207,222`, `spec:75-76`: `EnemyActor.should_run_far_step`, "far tier 10–15 Hz". The method is removed (`PerformanceLifecycleTest.gd:149-158` asserts its absence); cadence is owned by `autoload/EnemySimulationScheduler.gd` (`mid_group_count = 3`, `far_group_count = 7` → ≈ 20 Hz mid / 8.6 Hz far at 60 Hz physics). `PERFORMANCE_PATCH_CHANGELOG.md:73-74` is equally stale. Superseded by `plans/2026-08-18-enemy-simulation-budget.md`. → UPDATE DOC.
- **MED / 90%** — `plan:7,32`, `spec:93` "`EnemyIndex` remains the canonical enemy registry". Since `065bf26` (2026-08-19) the autoload `EnemyWorld` is authoritative; the 08-19 design spec calls `EnemyIndex` "a compatibility facade". → UPDATE DOC.
- **LOW / 100%** — `plan:342` `ProjectileRenderBenchmark.tscn` does not exist; the `.gd` `extends SceneTree` (run with `--script`). → UPDATE DOC.
- **LOW / 90%** — `plan:274` "Developer Mode toggle/key": the overlay opens via backtick and only when `OS.is_debug_build()`. Superseded by the console docs.

## 3. `plans/2026-07-28-equipment-foundation.md` (+ spec) — DONE, merge formula contradicts

Verified: `RarityMath`, `LuckResolver` (`SOFTCAP 0.5`), `ItemDropContext`, `ItemGenerator`, potency `1 + 0.45√r + 0.05r`, `Inventory.get_set_strength` via potency, effect scene lists, `Global.deliver_guaranteed_item`, `MCE_GrantItemRoll`, `InventoryRouter`, ring effect scaling.

- **MED / 95%** — `spec:17-21` merge mass `quality × 2^(incoming − destination)`, `spec:34` "Overflow remains", and `EQUIPMENT_FOUNDATION_CHANGELOG.md` ("Overflow is halved after each rarity gained"). Code since `4bce3f8` (2026-08-23 "merge-math v2"): `RarityMath.gd:9 GAP_HALF_LIFE = 1.5`, exponent `gap / 1.5`, overflow factor `2^(−1/1.5)` ≈ 0.63, auto-swap to higher rarity, continuous potency reads `rarity + meter`. The governing design is `docs/design/RARITY_MERGE_SPEC.md` (v3 GREENLIT). → UPDATE DOC (banner). Risk: reasoning about duplicate value from this spec is off by the half-life and the overflow ratio.
- **LOW / 95%** — `spec:44` "temporary `duplicate_feed_value` … retained only for old custom resources": still exported, written at 0.0 in ≥10 `.tres`, never read. Dead code; it is what makes audit-closure Task 3 misleading. → REVIEW (delete the field + tres lines, or document as dead).

## 4. `plans/2026-07-28-save-integrity.md` (+ spec) — DONE

Verified: temp/backup paths, `CACHE_MODE_IGNORE` loads, `has_save` fallback, `save_slot(...) -> bool`, `delete_slot` over all three paths, `meta_stash` and vendor fields in `SaveData`.

- **LOW / 100%** — `plan:44-64,113,328`: scaffold `extends SceneTree` and `--script` run commands; the actual `SaveIntegrityTest.gd` `extends Node` and runs via its `.tscn` (11 tests). → UPDATE DOC.
- **LOW / 100%** — `save_slot` gained `validated: bool = true` (`SaveManager.gd:66`); the "no new save-schema fields" constraint is historical (doctrine/manifestation fields since). → KEEP.

## 5. `plans/2026-07-29-navigation-diagnostics-spawn-filter.md` (+ spec) — DONE, overlay layout contradicts

Verified: `DebugEnemySpawnFilter` API and consumers, `FlowFieldNav` counters/reasons/neighbour buffers, `ChunkManager.request_nav_revision`/`commit_pending_nav_revision`/`get_nav_debug_counters`, overlay "Only"/per-type caps.

- **MED / 90%** — `plan:204-231` Task 6, `spec:39-57`: a movable compact/detail panel defaulting to the lower-left. Code: a centred tabbed console (`PerformanceOverlay.gd:158-164`), tabs Overview/Enemies/Performance/Tests, header has only `Close`; no Compact/Details toggle. `PERFORMANCE_PATCH_CHANGELOG.md:79-83` is stale the same way. Superseded by the unified-developer-console plan. → UPDATE DOC.
- **LOW / 100%** — `plan:209` "Modify `DevSetCollisionTools.gd` (Performance button)": it owns no UI now. → UPDATE DOC.
- **LOW / 100%** — `SpawnFilterTest.tscn` never existed (`.gd` extends SceneTree); `FlowFieldBenchmark.gd` → actual `FlowFieldAllocationBenchmark.gd`. → UPDATE DOC.
- **LOW / 85%** — `spec:36-37` / changelog `:113-114` "builds superseded by player movement … stop": movement no longer supersedes; revision supersession is debounced (`nav_revision_debounce = 0.20`) and builds run on `WorkerThreadPool` since `25e0a5b`; revisions batch until the queue drains, not once per frame. → REVIEW.

## 6. `plans/2026-07-29-performance-flight-recorder.md` (+ spec) — DONE, location and UX contradict

Verified: recorder API (`set_enabled`, `configure`, `ingest_sample`, `mark_incident`, `record_event`, `record_counter_event`, `collect_runtime_sample`, status/incident getters), defaults 10/5/2 s, `EVENT_BUCKET_USEC = 250_000`, trigger expression identical to `plan:68-69`, `PerformanceIncidentWriter.write_incident`, tests, hooks across enemy/projectile/world/encounter systems.

- **MED / 100%** — `spec:126-128`, `plan:135`, `PERFORMANCE_PATCH_CHANGELOG.md:42-43`: reports "beneath `user://performance_captures/`". Code `PerformanceFlightRecorder.gd:27-33`: `res://performance_results` when `OS.has_feature("editor")`, else `user://performance_captures` (since `f135519`, 2026-08-22). → UPDATE DOC. Risk: a developer hunts in `%APPDATA%` for reports that are in the repo.
- **MED / 95%** — `spec:14-29`, `plan:211-212`: a "Performance Lab" checkbox/section starts the recorder. No such string survives; `Global.debug_performance_lab` is set only by the Dev Segment route; the recorder is auto-armed on every dev launch (`MainMenu.gd:168-169,209,264`, per `plans/2026-08-18-developer-recorder-auto-arm.md`); controls live in the console's Performance tab. → UPDATE DOC.
- **LOW / 100%** — `PerformanceFlightRecorderIntegrationTest.gd/.tscn` never created; the unit test covers the runtime-sample fixture. → UPDATE DOC.
- **LOW / 100%** — `plan:63` "numeric states" (they are strings); `plan:153` `call_deferred` writer → off-thread `PerformanceIncidentWriteQueue` (`73ce370`), `flush_reports`. Spec's "asynchronous" wording still holds.
- **LOW / 85%** — `spec:134-135` "a small session index lists all incidents": no session index exists. → REVIEW.

## 7. `plans/2026-07-29-performance-root-cause-fixes.md` (+ spec) — CONTRADICTS

- **MED / 100%** — `plan:42`, `spec:45-46`, changelog `:17-18` "at most one queued chunk per frame by default". Code `ChunkManager.gd:11 max_chunk_generations_per_frame: int = 4` plus a 2 ms activation budget (`239f12b`, 2026-08-18). Nearest-first dedup queue is present. → UPDATE DOC.
- **MED / 90%** — `plan:26-30` Task 2, `spec:23-31` "population above 48 shrinks near/mid thresholds … mid-tier at 30 Hz". Removed: `PerformanceRootCauseFixTest.gd:43-48` asserts `compute_population_lod_tier` / `should_run_reduced_step` are gone ("no production callers"); tiers are budget/band based (`EnemySimulationScheduler.gd:13-14,25-28,45-47`), mid ≈ 20 Hz. Changelog `:8-10,23-24` stale too. Superseded by `plans/2026-08-18-enemy-simulation-budget.md`. → UPDATE DOC.
- Verified DONE: Task 1 (flow-field coalescing, `FlowFieldNav.gd:87-88,233-235`) and Task 3 (projectile query-object reuse, `ProjectileSimulationManager.gd:47-48,251`); "chunk generation remains on the main thread" still true.
- **LOW / 100%** — `PerformanceRootCauseFixTest.gd` now also hosts enemy-world contracts (`:114-125`); name drift only.

## 8. `plans/2026-07-29-unified-developer-console.md` (+ spec) — DONE, F8 and alpha contradict

Verified: `Global.debug_dev_mode`, four tabs, footer Close/MainMenu/ExitGame with second-click confirm, menu return saves and unpauses, stress toggle defaults off, Escape closes, `DevSetCollisionTools` builds no panel.

- **MED / 100%** — `plan:5,16,41` "F8 toggles the console" while its own `spec:13` says backtick. Code: `PerformanceOverlay.gd:97 KEY_QUOTELEFT`; `DeveloperConsoleTest.gd:85-94` asserts F8 does **not** open it. Fixed by the 07-30 keybinding plan; this plan was never amended. → UPDATE DOC.
- **MED / 95%** — `spec:26` "72% opaque dark background": `PerformanceOverlay.tscn:6 bg_color … 0.5` — alpha 0.5, never 0.72 in git history; the `0.72` at `gd:162` is a viewport-height fraction. → UPDATE DOC (or set alpha to 0.72 if the spec is the intent). Risk: someone "restores" 0.72 thinking it regressed.
- **LOW / 100%** — Console additionally requires `OS.is_debug_build()` (`gd:95`); the Tests tab was rebuilt into five sub-tabs (`e4e7987`). → KEEP.

## 9. `plans/2026-07-30-dev-segment-prefab-baseline.md` — DONE (accurate)

Verified: `Global.debug_dev_segment`, menu button, `DevSegment.tscn` and piece roles, `game.gd` strips streaming systems and skips the entry sequence, `DevSegmentTest`, `ChunkManager.paint_tiled_rect/paint_tiled_texture`.

- **LOW / 100%** — Dated 2026-07-30 but committed in `31ca4e0` on 2026-08-18. → UPDATE DOC (date) or KEEP.
- **LOW / 100%** — Undocumented side-effect: the route sets `debug_performance_lab = true` and force-enables the flight recorder (`game.gd:192-193`). → KEEP (note).

## 10. `plans/2026-07-30-developer-console-keybinding.md` — DONE

All four steps unticked but done (`KEY_QUOTELEFT`, Escape, no F8/F9, menu hint, `DeveloperConsoleTest.gd:85-94`). Referenced by nothing. → UPDATE DOC (tick) or REMOVE (fully absorbed, 34 lines).

## 11. `plans/2026-07-30-resizable-translucent-console.md` — DONE, alpha contradicts

Verified: `resize_edges_at`, `resized_rect`, `MIN_CONSOLE_SIZE = (720, 480)`, tests. **MED / 95%** — `plan:13,49` "background alpha 0.72": actual 0.5 (see §8). → UPDATE DOC or code.

## 12. `plans/2026-07-30-tiled-procedural-world-rendering.md` — CONTRADICTS

- **HIGH / 95%** — Goal `:5` "Replace repeated procedural-world visual scene nodes with `TileMapLayer` rendering" and `PERFORMANCE_PATCH_CHANGELOG.md:172-186` ("original sprite path remains available through `tiled_world_rendering = false`", "roughly 39,000 tile cells"). Code: `ChunkManager.gd:61 @export var tiled_world_rendering: bool = false` — **tiling is off by default** (flipped in `48c7d07`, 2026-08-18 "keep procedural ground out of tile maps"); ground is one region `Sprite2D` per chunk; decals/landmarks tile only when the flag is on; blockers batch via MultiMesh per the 08-17 rearchitecture; the changelog's own 08-17 section reverses the July follow-up. Authored Segment-1 tiles still use the renderer. Superseded by `plans/2026-08-17-chunk-streaming-rearchitecture.md`. → UPDATE DOC (banner) — do not remove: it is the only record of the tile-renderer rationale. Risk: assuming procedural visuals are tiled and debugging the wrong path.
- **MED / 100%** — `plan:29` interface `begin_chunk(chunk)`, `paint_ground`, `paint_block`, `paint_deco`, `visual_node_count`: none exist. Actual `ChunkTileRenderer.gd`: `configure_host`, `begin_chunk(chunk, cell_size)`, `paint_texture`, `paint_sprite`, `paint_transformed_texture`, `paint_repeating_rect`, `get_chunk_stats`, `erase_cell`, `clear_chunk`, `enabled`. → UPDATE DOC.
- **LOW / 100%** — `ChunkTileRendererTest.gd` exists (SceneTree); `plan:53` "retain the already-batched chunk ground" happens to match current code but not the changelog's follow-up.

---

## One-line verdicts

| File | Verdict |
|---|---|
| `2026-07-28-audit-closure` (+spec) | DONE — `duplicate_feed_value` 0.10 and helper names stale |
| `2026-07-28-enemy-lifecycle-performance` (+spec) | DONE — far-tier Hz and "EnemyIndex canonical" **contradict** |
| `2026-07-28-equipment-foundation` (+spec) | DONE — merge-mass formula **contradicts** merge-math v2 (`docs/design/RARITY_MERGE_SPEC.md` governs) |
| `2026-07-28-save-integrity` (+spec) | DONE |
| `2026-07-29-navigation-diagnostics-spawn-filter` (+spec) | DONE — Task 6 overlay layout **contradicts** |
| `2026-07-29-performance-flight-recorder` (+spec) | DONE — report dir and Performance-Lab UX **contradict** |
| `2026-07-29-performance-root-cause-fixes` (+spec) | **CONTRADICTS** (Task 2 removed, Task 4 default 4 not 1) |
| `2026-07-29-unified-developer-console` (+spec) | DONE — F8 and 72% alpha **contradict** |
| `2026-07-30-dev-segment-prefab-baseline` | DONE (date wrong: committed 2026-08-18) |
| `2026-07-30-developer-console-keybinding` | DONE |
| `2026-07-30-resizable-translucent-console` | DONE — alpha 0.72 **contradicts** (0.5) |
| `2026-07-30-tiled-procedural-world-rendering` | **CONTRADICTS** (tiling off by default, API names never existed) |

None of the 12 is current; all describe work that landed in `af1fc46` (or `31ca4e0`), several later partially reversed.

## Three most misleading specifics

1. **`tiled_world_rendering` is `false` by default** (`core/systems/world/ChunkManager.gd:61`, since `48c7d07`) — the tiled-rendering plan and `PERFORMANCE_PATCH_CHANGELOG.md:172-186` present procedural tiling as the shipped path; the plan's painter API never existed.
2. **Root-cause fixes:** "one chunk per frame by default" is 4 (`ChunkManager.gd:11`), and the "population > 48 / 30 Hz mid-tier" layer was deleted — `PerformanceRootCauseFixTest.gd:43-48` asserts its absence; the changelog repeats both stale numbers.
3. **Flight recorder:** editor/`--path` runs write to `res://performance_results`, not `user://performance_captures/`, and the "Performance Lab" checkbox no longer exists — the recorder is auto-armed on every dev launch.

Runner-up: audit-closure's `duplicate_feed_value = 0.10` for rings — exported, set to 0.0 everywhere, read by nothing.

---

## Status 2026-08-30 — nothing executed against these docs beyond two citation fixes; all five headline contradictions re-verified

Since `a8a535a`, exactly one commit touched the 20 docs in scope: `2f40501`
(cleanup-audit win #10) — in-place citation fixes, no banners, no ticked
boxes. Everything else was re-verified open by grep at HEAD `b2b1604`.

**Fixed / overtaken (named precisely)**

- §2 `plan:342` `ProjectileRenderBenchmark.tscn` — fixed by `2f40501`: the
  plan now cites the `.gd` as a `SceneTree` script run with `-s`
  (`ProjectileRenderBenchmark.gd` itself survives at HEAD).
- §5 third row, `SpawnFilterTest.tscn` half — fixed by `2f40501` (all three
  citations in the navigation plan). The `FlowFieldBenchmark.gd` half is
  untouched (`plan:147` still names it), **and the audit's stated actual,
  `FlowFieldAllocationBenchmark.gd`, was deleted in `af4e23e`** (2026-08-29,
  assertion-free benchmark) — neither name exists at HEAD, so the remaining
  doc fix is "created as `FlowFieldAllocationBenchmark.gd`, removed
  2026-08-29", not a rename. The row was correct when written; it went
  stale a day later.

**The five headline contradictions all still stand** (each re-read at HEAD):

1. `ChunkManager.gd:61` `tiled_world_rendering: bool = false` — §12 HIGH.
2. `ChunkManager.gd:11` `max_chunk_generations_per_frame: int = 4` — §7.
3. `EnemySimulationScheduler.gd:16-17` `mid_group_count = 3` /
   `far_group_count = 7` (≈ 20 / 8.6 Hz) — §2/§7. `7bfc6cb` removed three
   pressure helpers lower in that file; the cited export block is
   byte-identical to the audited tree.
4. `PerformanceFlightRecorder.gd:28-33` `res://performance_results` under
   the editor feature, `user://performance_captures` otherwise — §6.
5. `PerformanceOverlay.tscn:6` background alpha 0.5 (the `0.72` at `gd:162`
   is still the viewport-height fraction) — §8/§11.

**Everything else re-verified open, grouped.** `duplicate_feed_value` is
still the dead export (`ItemData.gd:17`, written `0.0` in every def
including the eight curse `.tres`, read by no `.gd`; `7bfc6cb`'s ten
zero-caller removals were functions only and did not include it) — §1/§3.
`finalize_rarity` (`EnemyDrops.gd:128`), public `validation_score`,
`GAP_HALF_LIFE = 1.5`, backtick-only console (`PerformanceOverlay.gd:97`;
`DeveloperConsoleTest.gd:85-94` still asserts F8 does not open it), the
absent "Performance Lab" string, the `MainMenu.gd` auto-arm and the
`game.gd:193` dev-segment side-effect are all unchanged. No plan gained a
banner or a date fix; the root-cause and keybinding plans still show 19 and
4 unticked steps; both changelogs still sit at
`docs/PERFORMANCE_PATCH_CHANGELOG.md` / `docs/EQUIPMENT_FOUNDATION_CHANGELOG.md`
repeating the stale numbers (`2244764` moved the 0.25.x records to
`docs/history/`, not these two).

**Corrections:** none to the audit as written. One KEEP note deepened: §4's
"no new save-schema fields is historical" is more historical still —
`054f635` added `save_version`/`game_version` to `SaveData`. Of the code
files this audit cites, only `SaveManager.gd`, `game.gd`, `EnemyIndex.gd`
(the `7bfc6cb` removals; `retire_enemy`/`simulation_tier_counts`/
`get_debug_counters` survive) and `EnemySimulationScheduler.gd` changed
since `a8a535a`, and none of the changes overturns a row.

Tally: 35 findings; 1 fixed (`2f40501`), 34 still present at HEAD (one of
them half-fixed with the stale remedy noted above).
