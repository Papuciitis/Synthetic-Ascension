# Audit — dead GDScript, orphan scenes, resources and assets (2026-08-28)

Branch `enemy-world-work`, read-only catalogue (nothing was modified or deleted).
Part A of the cleanup series; the consolidated ranking lives in
`2026-08-28-cleanup-audit.md`.

**Scope:** 1,006 tracked candidate files (`.gd .tscn .tres .png .jpg .svg .wav
.ogg .mp3 .ttf .gdshader`) under `autoload/ core/ scenes/ ui/ effects/ assets/
data/ tools/ spells/ scripts/`.

**Method:** reference graph built from `res://` path strings and `uid://` ids in
every `.tscn/.tres/.gd`, `project.godot`, `export_presets.cfg`,
`tools/perf/run_benchmarks.ps1`; `.uid`/`.import` sidecars to resolve uids;
`class_name` word usage; constant-concatenated paths in `global.gd`
(`UI_DIR + "/screens/..."` etc.); directory-scan roots (`data/items/defs`,
`data/sets`, `data/augments`, `data/major_choices`, `data/weapons`,
`data/races`, `data/styles`, `spells/data`) and the `sfx_manifest.txt` loader.
Then transitive reachability from real roots (main scene
`ui/screens/MainMenu.tscn`, 20 autoloads, dir-scanned data, benchmark runner).

**Result:** 633 REF, 78 DIRSCAN, 25 ROOT, 5 REF-but-unreachable, 172 "orphan"
(of which 109 are `tools/tests` entry points and 18 are manifest-loaded SFX =
false positives), 93 test-only (all are test scripts referenced by their own
test scene).

---

## REMOVE (usage proven absent) — total 27,680,736 bytes (~26.4 MiB) incl. `.import`/`.uid` sidecars

### A. Dead scripts / scenes (code)

- **HIGH · 98%** · `scenes/boot.tscn` (228 B) + `scripts/boot.gd` (+`.uid`, 280 B)
  Evidence: `boot.gd` is the empty Godot template (`_ready(): pass`, `_process(): pass`). Only referrer of `boot.gd` is `boot.tscn`; nothing references `boot.tscn` (`git grep -F boot.tscn` → only itself; main scene is `uid://c446qid4khmif` = `ui/screens/MainMenu.tscn`; `PATH_*` constants in `global.gd` never name it). Last touch `d77f1f3 2026-07-21` (initial import). No doc mentions. Risk: none; `scripts/` becomes empty (project.godot folder-color entry `res://scripts/` would then dangle — cosmetic).
- **HIGH · 98%** · `scenes/_dev/sprite_2d.tscn` (348 B) + `assets/textures/new_gradient_texture_2d.tres` (361 B)
  Evidence: editor scratch scene (a lone `Sprite2D` with a `GradientTexture2D`). `.tres` referenced only by `sprite_2d.tscn` (uid `oiepy5hd8cg4`); `sprite_2d.tscn` referenced by nothing (`git grep -F sprite_2d` → self only). `d77f1f3 2026-07-21`. Risk: none. Note: `export_filter="all_resources"` ships it in the build today.
- **HIGH · 97%** · `ui/components/InventorySlot.tscn` (263 B)
  Evidence: a 1-node scene whose script is `InventorySlotView.gd`; the live component is `InventorySlotView.tscn`, which `InventoryBar.tscn` instantiates (`ext_resource path="res://ui/components/InventorySlotView.tscn"`). `git grep -E 'InventorySlot\.tscn|InventorySlot"'` → only its own node name; `PROJECT_STRUCTURE.md:44` documents `InventorySlotView.tscn` as the runtime slot. `d77f1f3`. Risk: none.
- **HIGH · 95%** · `ui/components/SelectionCard.tscn` (1,950 B) + `ui/components/selection_card.gd` (+`.uid`, 4,039 B)
  Evidence: `selection_card.gd` header says "Used by RaceCard.tscn and PlaystyleCard.tscn", but both scenes attach their own scripts (`RaceCard.gd`, `PlaystyleCard.gd`, `extends Button`, no reference to `selection_card.gd`). `base.gd:190/197` mentions it only in comments ("no dependency on selection_card.gd"). `SelectionCard.tscn` referenced by nothing; `selection_card.gd` referenced only by `SelectionCard.tscn` (unreachable from any root). `d77f1f3`. Risk: none.
- **HIGH · 97%** · `ui/controllers/HudInventoryController.gd` (+`.uid`, 6,155 B)
  Evidence: `class_name HudInventoryController` — zero occurrences of the word anywhere in `.gd/.tscn/.tres/.md`; `HUD.tscn` wires 13 controllers (`HudBagController`, `HudTooltipController`, …) and not this one. `d77f1f3`. Risk: none.
- **HIGH · 95%** · `core/actors/enemy/modules/EnemyOrbit.gd` (+`.uid`, 664 B)
  Evidence: `class_name EnemyOrbit`; `git grep -w EnemyOrbit` → only `PATCH_MANIFEST.md:258` (historical file list). Orbit behaviour is implemented inline in `enemy.gd` (`_orbit_move()` L854, `EnemySpec.AI.ORBIT` L354) using the same `spec.orbit_radius/orbit_turn_speed`. Enemy modules are not loaded by path either (`modules/*.gd` refs in scenes: only `EnemyLifecycle.gd`). Last touch `af1fc46 2026-07-30`. Risk: none (an `EnemyOrbiter` *scene* exists and is unrelated).
- **HIGH · 96%** · `core/systems/vision/VisionOverlay.gd` (+`.uid`, 1,608 B), `core/systems/vision/vision_overlay.gdshader` (+`.uid`, 1,037 B), `core/systems/vision/fog_of_war.gdshader` (+`.uid`, 1,064 B)
  Evidence: the only vision scene, `scenes/vision/VisionRig.tscn`, uses `VisionRig.gd`, `FogOfWar.gd`, `vignette.gdshader`. `FogOfWar.gd` contains no `Shader`/`load(` at all; `grep -rn 'gdshader|VisionOverlay' core/systems/vision/*.gd` → nothing besides `VisionOverlay.gd` itself. `git grep` for `VisionOverlay|fog_of_war|vision_overlay` across repo → none. `d77f1f3`. Risk: none.
- **HIGH · 97%** · `core/systems/world/SegmentPlan.gd` (+`.uid`, 4,475 B)
  Evidence: `class_name SegmentPlan` — `git grep -F SegmentPlan` returns only the file itself (no code, scene, doc or test). Its comment says it feeds `ChunkManager` archetypes; that role is now `core/systems/world/proc/DistrictPlan.gd` (used by `ChunkManager`, `tools/ProcPlanSmokeTest.gd`). `d77f1f3`. Risk: none.
- **HIGH · 97%** · `scenes/world/cover/CoverWindow.gd` (+`.uid`, 388 B)
  Evidence: `CoverWindow.tscn` attaches `CoverWall.gd` with `is_window = true`; nothing references `CoverWindow.gd` (`git grep -F CoverWindow.gd` → none; the many `CoverWindow` hits are the `.tscn`, node names and the physics-layer name). `d77f1f3`. Risk: none.
- **HIGH · 95%** · `assets/vfx/world/augments/VFX_SpiritSlashImpact.tscn` (279 B) + `VFX_SpiritSlashImpact.gd` (+`.uid`, 1,593 B)
  Evidence: `SpiritSlashEffect.tscn` uses `VFX_SpiritSlash.tscn`; `class_name VFX_SpiritSlashImpact` never instantiated (`git grep -F SpiritSlashImpact` → only the two files). Augment VFX are never looked up by string (`VFX_*` string search → only `preload`s and class-typed `.new()`). `d77f1f3`. Risk: none.

### B. Loose textures with no referrer

All `d77f1f3 2026-07-21`; each has its `.import` sibling; nothing in code builds `assets/textures|world/decals` paths from strings — see limits.

- **MED · 96%** · `assets/textures/Player_Placeholder.png` (51,145 B) — `player.tscn` uses `Player_Placeholder64x64.png`; basename appears nowhere else. Risk: none.
- **MED · 96%** · `assets/textures/backgrounds/fog_noise_01.png` (148,761 B) — `game.tscn` uses `fog_soft_01.png` + `game_background.png`; `AtmosFireflies.gd`/`FloorFollow.gd` load no textures. Risk: none.
- **MED · 94%** · `assets/textures/covers/game_cover_full.png` (1,789,320 B), `assets/textures/covers/game_cover_half.png` (2,604,676 B), `assets/textures/covers/window_placeholder_placeholder.png` (1,128,257 B) — only `covers/main_menu_backdrop.jpg` is referenced (`MainMenu.tscn`); no `boot_splash` in `project.godot`; no doc mentions. Risk: if `game_cover_*` are store/marketing art, relocate them outside `res://` instead of deleting — either way they should leave the exported tree (4.4 MB in the PCK today).
- **MED · 96%** · `assets/world/decals/decal_cracks_01.png` (1,700,215 B), `assets/world/decals/decal_stain_01.png` (358,978 B) — only `decals/decal_sigil_01.png` (3 scenes) and `decals/floor/*` (`WorldArt.gd`, `Level1Builder.gd`) are referenced; no `"decal_"` string building. Risk: none.

### C. Archived ground-texture folders

Documented as "preserved", but unreferenced; all `af1fc46 2026-07-30`; each PNG has an `.import` sibling; all are shipped by `export_filter="all_resources"`.

- **HIGH · 97% · REMOVE + UPDATE DOC** · `assets/world/ground/_legacy_023_noisy/` (14,783,805 B): `ground_cobble_01.png`, `ground_dirt_01.png`, `ground_dirt_path_01.png`, `ground_grass_01.png`, `ground_mud_wet_01.png`, `ground_stone_tiles_01.png`
- **HIGH · 97% · REMOVE + UPDATE DOC** · `assets/world/ground/_legacy_failed_gray_0241/` (3,668,099 B): `ground_city_base_01.png`, `ground_cobble_01.png`, `ground_dirt_01.png`, `ground_dirt_path_01.png`, `ground_grass_01.png`, `ground_mud_wet_01.png`, `ground_stone_tiles_01.png`
- **HIGH · 97% · REMOVE + UPDATE DOC** · `assets/world/ground/_legacy_dense_foliage_0242/` (1,422,748 B): `ground_grass_01.png`
  Evidence (all three): every ground texture load is a literal path into `assets/world/ground/<file>` (`WorldArt.gd:23-32`, `Level1Builder.gd:46-48`); `git grep -E '_legacy_|_source_cethiel'` in `.gd/.tscn/.tres` → nothing. Docs that mention them: `GROUND_TEXTURE_PATCH.md:21-22,29`, `DEVELOPMENT_LOG.md:334`, `PATCH_MANIFEST.md:508`. Git history already preserves them. Risk: low — purely archival; update `GROUND_TEXTURE_PATCH.md` "Preserved material" section when removing.

---

## REVIEW (unused or questionable, but intent/ownership unclear)

- **MED · 97% unused** · `assets/world/ground/_source_cethiel_cc0_selected/` (15,780,712 B; 16 PNG + `README.md`): `ground_{city_base,cobble,dirt,dirt_path,grass,mud_wet,stone_tiles}_01_source[.png|_nrm.png]`, `ground_grass_patchy_025_source[.png|_nrm.png]`
  Evidence: same searches as above — no code/scene reference. `README.md` states the normal maps are "preserved for future material/shader work" and records CC0 provenance. Action: keep the README/provenance, but move the PNGs out of `res://` (or add a `.gdignore`) — currently 15.8 MB is imported and exported for nothing. Risk of deleting outright: loses the future-work source set (still in git history).
- **LOW · 100% unused-by-game** · `tools/BatchIconCutter.tscn` (166 B) + `tools/batch_icon_cutter.gd` (+`.uid`, 2,509 B) — `@tool` one-shot generator that wrote `assets/textures/items/{lattice,gravemarch}/*.png`. Referenced by nothing; not mentioned in any doc. Action: keep as a dev tool but it is **not** in the export exclude list (`tools/tests/*,tools/perf/*` only) so it ships. Either move under `tools/tests/`/`tools/perf/` or extend `exclude_filter`.
- **LOW · 100% unused-by-game** · `tools/ProcPlanSmokeTest.gd` (+`.uid`, 2,673 B) — headless smoke test run via `--script`; documented in `DEVELOPMENT_LOG.md:411`, `CHANGE_MANIFEST_0.25.2.md:7`, audit-closure plan/spec. Uses existing `DistrictPlan.validation_score`, `SegmentThemePicker`. Not in any recorded sweep. Same export-leak as above. Action: move to `tools/tests/` or exclude.
- **LOW · n/a** · `data/weapons/StarterMagic.tres` — dir-scanned into `weapon_db["magic"]`, but it is a bare `[gd_resource type="Resource"]` with no script and no properties (siblings are `script_class="WeaponData"`). Nothing looks it up by name. Action: confirm whether "magic" weapon is meant to be data-driven; otherwise it's an empty placeholder.
- **LOW** · Test entry points that are **not in the recorded 82-test sweep** and not in `run_benchmarks.ps1`. All are legitimately unreferenced (`--headless … X.tscn` / `--script X.gd`); every `res://` path they load exists and the spot-checked methods exist (`ChunkManager.process_chunk_generation_queue/get_chunk_render_stats/erase_repeated_visual`, `ChunkTileRenderer.begin_chunk/…`, `Segment1SpawnProfile.Stage`, `PlayerDashState`). They just may have rotted. Action: run once; delete or add to the sweep. (The per-test verdicts are in `2026-08-28-stale-tests.md`.)
  - `tools/tests/AccessibilitySettingsTest.gd` (2d22323 08-18; doc: settings-controls plan)
  - `tools/tests/ChunkTileRendererTest.gd` (48c7d07 08-18; docs: tiled-world plan, chunk-streaming plan)
  - `tools/tests/DevSegmentTest.gd` (31ca4e0 08-18; docs: dev-segment plan)
  - `tools/tests/DeveloperConsoleTest.gd` (af1fc46 07-30; docs: console plans)
  - `tools/tests/ExchangeIdentityTest.gd` (8ecaaec 08-26; doc: ledger plan)
  - `tools/tests/FirstEncounterPresentationTest.gd` (cc3c66a 08-26; docs: occult-UI, combat-pressure plans)
  - `tools/tests/FlowFieldAllocationBenchmark.gd` (b0d5f1b 08-18; docs: PERFORMANCE_PATCH_CHANGELOG)
  - `tools/tests/FollowerFeedbackPresentationTest.gd` (7daffe3 08-26; doc: ledger plan)
  - `tools/tests/InputBindingServiceTest.gd` (9b09984 08-24; docs cite it — see UPDATE DOC)
  - `tools/tests/InterfaceThemeConsistencyTest.gd` (c74ee34 08-26; docs: ledger/occult/doctrine plans)
  - `tools/tests/MainMenuSettingsIntegrationTest.gd` (b2f44b6 08-18; doc: occult-UI plan)
  - `tools/tests/ManifestationPlaytestProbe.gd/.tscn` (6975fb9 08-24; no doc cites the path)
  - `tools/tests/PerformanceOverlayUnitTest.gd` (ccf98ad 08-22; doc: flight-recorder plan)
  - `tools/tests/PlayerAimStateTest.gd` (393d69d 08-18; doc: settings plan)
  - `tools/tests/PlayerDashStateTest.gd` (9b09984 08-24; **no doc mention at all**)
  - `tools/tests/ProjectileRenderBenchmark.gd` (af1fc46 07-30; doc cites a `.tscn` — see UPDATE DOC)
  - `tools/tests/RoamVisibilityProbe.gd/.tscn` (737a035 08-23; doc: OPTIMIZATION_HANDOFF)
  - `tools/tests/Segment1ProgressionTest.gd` (e47b76f 08-23; docs: OPTIMIZATION_HANDOFF, exit-rite plan)
  - `tools/tests/Segment1StoryProbe.gd/.tscn` (d86fc61 08-24; docs: OPTIMIZATION_HANDOFF, SEGMENT1_STORY_PASS)
  - `tools/tests/Segment1TileIntegrationTest.gd` (af1fc46 07-30; docs: chunk-streaming, settings plans)
  - `tools/tests/SettingsPersistenceTest.gd` (d053a5b 08-24; docs: save-integrity, settings plans)
  - `tools/tests/SettingsRuntimeTest.gd` (f7428fc 08-18; doc: settings plan)
  - `tools/tests/SettingsScreenTest.gd` (eff7686 08-18; doc: settings plan)
  - `tools/tests/SpawnFilterTest.gd` (af1fc46 07-30; doc cites a `.tscn` — see UPDATE DOC)
  - `tools/tests/TutorialTypewriterTest.gd` (2d22323 08-18; doc: occult-UI plan)
  - `tools/tests/WorldTileIntegrationTest.gd` (31ca4e0 08-18; docs: chunk-streaming plan/spec)
  - (`CursedVaultTest`, `EnemyHordeBenchmark`, `MinigunStressBenchmark` are also outside that sweep file but are run by later sweep logs / `run_benchmarks.ps1` — KEEP.)

---

## UPDATE DOC

- **LOW** · `docs/superpowers/plans/2026-08-26-exit-rite-safeguards.md:390` runs `res://tools/tests/InputBindingServiceTest.tscn` — no such scene; only `InputBindingServiceTest.gd` (`--script`) exists.
- **LOW** · `docs/superpowers/plans/2026-07-29-navigation-diagnostics-spawn-filter.md:32,54` cites `tools/tests/SpawnFilterTest.tscn` — only the `.gd` exists.
- **LOW** · `docs/superpowers/plans/2026-07-28-enemy-lifecycle-performance.md:342` cites `tools/tests/ProjectileRenderBenchmark.tscn` — only the `.gd` exists.
- **LOW** · `GROUND_TEXTURE_PATCH.md:21-22,29` and `DEVELOPMENT_LOG.md:334` — rewrite "Preserved material" when the `_legacy_*` folders go (section C above).
- **LOW** · `project.godot [file_customization]` colours `res://_archive/` — folder does not exist on disk or in git.

---

## KEEP (flagged by the naive graph, but proven used or entry points by design)

- 18 SFX files under `assets/audio/sfx/{ui,player,enemies,boss,world,items}/` (`ui_hover.wav`, `ui_click.wav`, `ui_back.ogg`, `ui_error.wav`, `melee_swing.ogg`, `melee_hit.wav`, `ranged_shot.wav`, `magic_cast.ogg`, `enemy_hurt.wav`, `enemy_death.ogg`, `boss_intro.ogg`, `wardstone_loop.ogg`, `wardstone_complete.ogg`, `exit_channel_loop.ogg`, `exit_unlock.ogg`, `exit_complete.ogg`, `pickup.wav`, `drop.ogg`) — 100% used: loaded by `autoload/SfxManager.gd` via `BASE_DIR + relative` from `assets/audio/sfx/sfx_manifest.txt` (every one of the 18 entries maps to an existing file). Directory/manifest-driven, not orphans.
- 78 directory-scanned `.tres` (`data/items/defs/**` 31×ItemData, `data/sets/**` 4×SetData, `data/augments` 13×AugmentData, `data/major_choices/**` 19×MajorChoiceDef, `data/weapons` 2×WeaponData + `StarterMagic` (see REVIEW), `data/races` 4×RaceData, `data/styles` 3×StyleData, `spells/data` 1×SpellData) — loaded by `Global._scan_*_dir_recursive` / `MajorChoiceDB.load_from_dir`. Not orphans.
- `data/items/defs/item_test.tres` + `assets/textures/item_test.png` — intentional dev item (`runtime_enabled = false`), guarded by `tools/tests/AuditClosureTest.gd:45-52`.
- 111 `tools/tests/*` entry points (88 `.tscn`+`.gd` pairs, 23 `--script`-only `.gd`) — unreferenced by construction; excluded from export. `ScriptParseAuditTest` also `load()`s every `.gd` under `core/ui/autoload/scenes/effects/data`, which is why none of the dead scripts above throw at parse time.
- New scripts without `.uid` sidecars (hygiene only): `core/systems/world/CursedVault.gd`, `tools/tests/CursedVaultTest.gd`, `tools/tests/ThreatDirectorPressureTest.gd` — Godot will generate them on next editor open; commit them then.

---

## Method and limits

The graph resolves literal `res://` strings, `uid://` ids (via `.uid`/`.import`/scene headers), `class_name` word matches (generous: a mention in a comment counts as a use, which biases toward KEEP), two-level `const X := DIR + "/…"` concatenation in `global.gd`, the eight directory-scan roots, and the SFX manifest. It **cannot** see: paths assembled at runtime from data (`"%s.tscn"` in tests, `path_join` on user dirs), `get_node`/`NodePath` lookups (node names, not files), resources referenced only from untracked or `.godot/`-cached state, or assets used by tooling outside the repo. Checks that mitigate this: `git grep` for concatenations near `res://assets|scenes|ui|effects` (only `global.gd` constants, `SaveManager` `user://` slots, and `batch_icon_cutter` outputs), for `"decal_|"covers/|"backgrounds/|"textures/` fragments (none), and `-F` basename search of every REMOVE candidate across all tracked files including `.md/.txt/.json`. Test scripts were checked for existence of every `res://` target and for a sample of called methods, not executed (read-only constraint). Sizes are tracked-file bytes (`du -b`/`stat`), including `.import`/`.uid` siblings; the on-disk `.godot/imported/*.ctex` copies are extra and untracked.

Out of this dimension but noticed: root-level `RECOVERY_EDITOR_TMP_ARTIFACTS.zip`, three `.patch` files and `performance_results/` (642 tracked files) are excluded from export by filter, but the `tools/*.gd|.tscn` and every asset above are not — `export_filter="all_resources"` packs them.

---

## Status 2026-08-30 — all 17 REMOVE rows executed; REVIEW is still open

Verified against the tree at `b2b1604` (`git cat-file -e` per candidate,
`git show --stat` per commit). The commit-per-win table lives in
`2026-08-28-cleanup-audit.md` § Status 2026-08-29; this section maps that work
back to the rows of this file.

**REMOVE — 17/17 rows executed, nothing missed.**

- A (dead scripts/scenes): `7a432cb` boot pair + `_dev` scratch pair;
  `ae86c60` InventorySlot / SelectionCard pair / HudInventoryController;
  `0428e8d` EnemyOrbit, VisionOverlay + both shaders, SegmentPlan,
  CoverWindow.gd, VFX_SpiritSlashImpact pair. Every `.uid` sidecar went with
  its file; `scripts/` and `scenes/_dev/` no longer exist as directories.
- B (loose textures): `e7d4de0` deleted `Player_Placeholder.png`,
  `fog_noise_01.png`, `decal_cracks_01.png`, `decal_stain_01.png`. **The three
  covers were moved, not deleted**, per the row's risk note:
  `marketing/covers/` under a `.gdignore` (100% renames, bytes unchanged);
  only their `.import` sidecars were deleted. The referenced
  `covers/main_menu_backdrop.jpg` stays put.
- C (archived ground folders): `9a0376c` removed all three `_legacy_*` folders
  and rewrote the `GROUND_TEXTURE_PATCH.md` "Preserved material" section in
  the same commit, as the row required.

**REVIEW — one row overtaken, four still open (re-verified at HEAD).**

- Overtaken: `tools/tests/FlowFieldAllocationBenchmark.gd` was deleted by
  `af4e23e` as one of the three assertion-free benchmarks — not run-or-adopted.
- Open: `_source_cethiel_cc0_selected/` is unchanged (33 tracked files, no
  `.gdignore` — still imported and exported); `tools/BatchIconCutter.tscn` +
  `batch_icon_cutter.gd` and `tools/ProcPlanSmokeTest.gd` still sit directly
  in `tools/`, which the export `exclude_filter` still does not cover
  (`export_presets.cfg` last changed in `4931865`, pre-audit) — all three
  still ship; `data/weapons/StarterMagic.tres` is still a bare script-less
  `[gd_resource type="Resource"]`.
- The other 25 unswept test entry points all still exist and are all still
  outside the sweep: the post-cleanup sweep grew to 85 suites only by the
  three new regression tests (cleanup audit § Status). Per-test verdicts
  remain with `2026-08-28-stale-tests.md`.

**UPDATE DOC — four of five rows fixed, one half-open.**

- `2f40501` fixed all three phantom `.tscn` citations (exit-rite:390 now runs
  `-s …InputBindingServiceTest.gd`; the spawn-filter and enemy-lifecycle plans
  now cite the `.gd`) and dropped **both** dangling folder colours —
  `res://_archive/` from this section plus `res://scripts/`, which row A.1
  predicted would dangle once `boot.gd` went.
- `GROUND_TEXTURE_PATCH.md` was rewritten in `9a0376c`, but
  `DEVELOPMENT_LOG.md:334` still says the previous grass is preserved under
  `_legacy_dense_foliage_0242/` — folder deleted; **that half of the row is
  still open** (arguably fine as a dated log entry; rewrite or annotate).

**KEEP-section hygiene, done in passing:** the three missing `.uid` sidecars
are now committed (`CursedVault.gd.uid` in `7bfc6cb`, the two test sidecars in
`af4e23e`). The out-of-scope root artifacts (`RECOVERY_EDITOR_TMP_ARTIFACTS.zip`,
the three `.patch` files, the STATIC_VALIDATION json) were retired by
`2244764`, and `13bebb4` untracked the flight-recorder captures.

**Stale citations in this audit** (moved, not wrong): `GROUND_TEXTURE_PATCH.md`
and `PATCH_MANIFEST.md` now live under `docs/history/` (`2244764`); read the
evidence lines above accordingly. No factual claim in this audit turned out
wrong during execution — the cleanup audit's corrections (C1.1, C7) concern
rows that were never in this file.
