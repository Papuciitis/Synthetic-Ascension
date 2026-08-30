# Audit — test scripts: stale targets, display-only probes, exit-code hygiene (2026-08-28)

Read-only catalogue on branch `enemy-world-work`; nothing was modified. Every
`tools/tests/*.gd` was checked for: production symbols it references (do they
still exist), `has_method`/`in` guards that would silently skip an assertion,
whether it prints a summary and exits 1 on failure, whether it needs a display,
what other test duplicates it, and temp/one-off wording in its header.

Production tree searched: `autoload/ core/ data/ scenes/ ui/ effects/ spells/
scripts/ assets/ project.godot`. Autoloads confirmed in `project.godot`:
Global, SaveManager, SettingsManager, RunEvents, ThreatDirector, InvRouter,
EnemyIndex, EnemyWorld, EnemyCombat, EnemyStatus (=EnemyStatusService.gd),
EnemySimulationScheduler, HitFeel, DebugEnemySpawnFilter,
PerformanceFlightRecorder, PoolManager, AudioManager, SfxManager,
ProjectileManager, BattleText, FollowerFeedbackUI, DevSetCollisionTools.

No test is registered in any runner: `tools/perf/run_benchmarks.ps1` lists
three benchmarks only; `export_presets.cfg` excludes `tools/tests/*`. Tests run
ad hoc as `godot --headless --path . res://tools/tests/X.tscn` or `godot -s`.

Verdict legend: **KEEP** (live, unique), **REVIEW** (live but structurally
wrong for an automated suite — display-only, no assertions, grab-bag, silent
skips), **REMOVE** (targets dead or fully superseded).

## Summary (108 tests, four groups)

- **Tests targeting a nonexistent system: 0.** Every production symbol, path,
  node, signal and constant referenced by the 108 audited scripts resolves at
  HEAD (`62bbfd3`). The only "dead" references are EnemySimulationBenchmark's
  two `.set()` writes to properties that no longer exist (silent no-ops).
- **REMOVE (3):** EnemySimulationBenchmark, FlowFieldAllocationBenchmark,
  ChunkScaleBenchmark — assertion-free or superseded; none is in
  `tools/perf/run_benchmarks.ps1`.
- **REVIEW — display-only or never-failing "probes" (10):** DevConsoleShotProbe
  (hangs headless to its 110 s watchdog), ObjectiveShotProbe, ManifestationHoverProbe,
  ManifestationPlaytestProbe, Level1DeterminismProbe, RenderChainProbe,
  RoamVisibilityProbe, Segment1StoryProbe, UiConsistencyVisualProbe,
  EnemyProxyRendererVisualTest (self-skips with exit 0) — plus the
  assertion-free ProjectileRenderBenchmark, StyleDpsBenchmark and
  PerformanceFlightRecorderBenchmark. A green headless sweep says nothing
  about any of these.
- **REVIEW — grab-bags / brittle pins (5):** AuditClosureTest,
  PerformanceLifecycleTest (overlay block duplicated verbatim),
  StyleParityTest and FirstEncounterPresentationTest (source-text greps),
  RunSheetArchiveTest (four vacuous negative assertions).
- **Silent `has_method` / `!= null` skips (9 sites):** InterfaceThemeConsistencyTest
  L90/98, DevForceSpawnTest L117, ManifestationSystemTest L811, EnemyPoolTest
  L126-128, RunSheetArchiveTest L102, Segment1ProgressionTest L79,
  SpawnFilterTest L74/96, StyleParityTest L98 — all targets present today.
- **Side effects on the developer machine:** AutosaveDebounceTest leaves
  `user://saves/slot_97.tres` behind; DevForceSpawnTest, the probes and the
  benchmarks call `start_new_attempt` on the live profile.
- **Coverage hole noticed in passing:** ScriptParseAuditTest does not scan
  `res://assets` (79 VFX scripts), `res://spells`, `res://scripts`.
- **Doc drift:** `EnemyHordeBenchmark` is shown run `--headless` in
  `docs/superpowers/plans/2026-08-25-sustained-combat-pressure.md:404`, where
  its gate silently skips; `docs/PERFORMANCE_PATCH_CHANGELOG.md:142` still
  says PerformanceLifecycleTest cannot complete headless.

---

## Group A — Accessibility … EnemyAreaCombat (27 tests)

| Test | Verdict | Conf | Evidence / notes |
|---|---|---|---|
| AccessibilitySettingsTest (`-s`) | KEEP | 95% | pure statics `AccessibilityPresentation.gd:5,13,17`; all live |
| AscensionDoctrineGameplayTest | KEEP | 90% | 9 doctrine `.tres`, 12 rule keys all consumed (global.gd / ThreatDirector.gd / ExitRite.gd / RunSheetHUD.gd); `has_method` guards L68/L99/L204 each preceded by a `_check` → loud. Complementary to ExitRiteTest (produces the `rite_*` keys it consumes) |
| AscensionDoctrinePresentationTest | KEEP | 85% | only test of `MajorChoice.tscn` focus→confirm flow; L64 exactly-once invariant duplicates AscensionDoctrineTest L99 (UI vs `Global.apply_major_choice`) |
| AscensionDoctrineTest | KEEP | 90% | stage schedule / role ordering / authored count (9) unique here |
| AuditClosureTest | **REVIEW** | 80% | 16 unrelated live invariants (rarity/merge math, vendor arbitrage, drops, save records, proc pacing `resonance_per_sec`=0.00342, tooltip) in one grab-bag named after the closed July audit (`docs/superpowers/plans/2026-07-28-audit-closure.md`). Nothing dead; split per system and rename. `write_save` only fills the SaveData object (global.gd:1556-1709 never calls `SaveManager.save_slot`) → no disk side effect |
| AutosaveDebounceTest | KEEP | 85% | regression guard for the kill-path autosave (header L3-5); **writes a real `slot_97.tres` via `save_current_profile()` and never deletes it** |
| BuildIdentityTest | KEEP | 90% | only test of `BuildIdentity.compose`; shares `_make_data/_cursed` fixtures and wardrobes with BurdenSystemTest (asserts differ). Uses capitalised noun ids `&"Momentum"` that never occur at runtime (naming audit #21) |
| BuildInfoTest | KEEP | 85% | environment-dependent: L32/L34 need `res://.git/HEAD` on a named branch; detached HEAD / exported build → "unknown" → FAIL |
| BurdenSystemTest | KEEP | 90% | core NEG pins; L128 `ItemEffectRunner.new()` (Node2D) never freed |
| ChunkBlockIntegrationTest | KEEP | 85% | batched-vs-legacy parity (L79-85) and unknown-scene fallback unique; L63-72 negatives repeat ChunkTileRendererTest L82-96 and ChunkStreamingPerformanceAudit L84-85 |
| ChunkBlockPhysicsTest | KEEP | 95% | precise geometry pins |
| ChunkBlockRendererTest | KEEP | 95% | only unit test of the MultiMesh batch lifecycle |
| ChunkBuildDataTest | KEEP | 95% | descriptor + catalog pins |
| ChunkScaleBenchmark | **REMOVE** | 70% | no assertions, prints one `BENCH` line, always quit(0); same seed 251337 / config as ChunkStreamingPerformanceAudit which already emits per-chunk timing at radius 2; not in `run_benchmarks.ps1`, cited by no doc. Header: "the shipped audit runs radius 2 (25 chunks), which is too few…" — fold the radius into the audit or register it |
| ChunkStreamReplanThrottleTest | KEEP | 85% | cheap regression guard (`_stream_plans_total`); cited by no doc |
| ChunkStreamingPerformanceAudit | KEEP | 80% | L88-89 absolute thresholds (median < 4 ms, max < 12 ms) are machine-dependent → will flake on slow CI; belongs in the benchmark runner |
| ChunkStreamingSchedulerTest | KEEP | 90% | planner math unique; L61-64 (0.001 ms budget activates ≥1 and <9) timing-sensitive |
| ChunkTileRendererTest (`-s`) | KEEP | 80% | sole coverage of `ChunkTileRenderer` and `Level1Builder._tile_authored_geometry`; L65-98 repeats ChunkBlockIntegrationTest |
| CursedVaultTest | KEEP | 90% | new (untracked) test for the new system; L79 hard-codes default `cost_beats` |
| DevConsoleShotProbe | **REVIEW** | 80% | display-only: `frame_post_draw` never fires headless → hangs until the 110 s watchdog → exit 1. `_verify_pair_shortcut` L109-132 (all 10 pairs light via `grant_pair`) exists nowhere else — extract it into a headless test; keep the probe as a windowed dev tool |
| DevForceSpawnTest | KEEP | 80% | only real-game contract for force-spawn/cap; boots the full game (~12.5 s), writes a profile via `start_new_attempt`; L117 `has_method("detached_handles")` silently skips one assertion (present today, EnemyIndex.gd:396) — make it a hard `_check` |
| DevSegmentTest (`-s`) | KEEP | 90% | end-to-end routing of the developer flag; "main menu loads" shared with DeveloperRecorderStartupTest / MainMenuSettingsIntegrationTest |
| DeveloperConsoleTest (`-s`) | KEEP | 90% | `toggle_overlay` also requires `OS.is_debug_build()` (PerformanceOverlay.gd:95) → L67 fails on a release template |
| DeveloperRecorderStartupTest | KEEP | 90% | small, live, restores state |
| DotSchedulingTest | KEEP | 75% | L33-44 tick arithmetic is identical to EnemyStatusServiceTest L56-61; unique: real `enemy.tscn` actor, no per-enemy node, standalone BurnDot. Trim to those |
| EncounterDirectorTest | KEEP | 90% | seeded (4242); modified in the working tree alongside EncounterDirector.gd |
| EnemyAreaCombatTest | KEEP | 90% | only coverage of MagicImpact/MeleeSlash against data-only handles |

Group A totals: dead targets 0/27; needs display 1 (DevConsoleShotProbe); no summary / never-failing exit 1 (ChunkScaleBenchmark).

---

## Group B — Enemy* suites (27 tests)

| Test | Verdict | Conf | Evidence / notes |
|---|---|---|---|
| EnemyAreaEffectTest | KEEP | 90% | unique aura/set-effect radius coverage on data-only handles |
| EnemyCombatLifecycleTest | KEEP | 90% | only test driving the real pooled EnemyActor through take_damage/apply_hit_ledger/heal/configure_health + pool reuse |
| EnemyCombatQueryTest | KEEP | 90% | only test of segment/sector queries + knockback mirroring |
| EnemyCombatServiceTest | KEEP | 90% | core damage/stun/modifier contract |
| EnemyDeathEventTest | KEEP | 75% | unique bus coverage; 3 context-field assertions duplicate EnemyCombatServiceTest L107-109 |
| EnemyHandleTargetingTest | KEEP | 90% | broadest guard that every player-side effect resolves data-only handles; uses `projectile.tscn` as a generic Area2D fixture |
| EnemyHordeBenchmark | KEEP | 80% | gate only windowed (documented in the runner); `docs/superpowers/plans/2026-08-25-sustained-combat-pressure.md:404` shows it run `--headless`, which silently skips the gate |
| EnemyIndexTest | KEEP | 85% | covers the EnemyIndex compatibility mirror; comment L133-134 names `rebuild_legacy_shadow`, which has **zero callers** (`EnemyWorld.gd:613`) |
| EnemyLegacyCombatCompatibilityTest | KEEP | 90% | legacy Node-owned lifecycle (BossPylon, OpeningActor) fully present |
| EnemyLifecycleStressTest | KEEP | 70% | never checks `EnemyWorld.active_count`; candidate to fold into EnemyIndexTest |
| EnemyPoolTest | KEEP | 90% | L126-128 sprite-tint assertion silently skipped if pool reset ever cleared `spec` |
| EnemyPressureBenchmark | KEEP | 85% | in `run_benchmarks.ps1` with a real gate; legacy-arm A/B tied to one historical change |
| EnemyProxyRendererTest | KEEP | 85% | only headless coverage of batch packing/interpolation/generation safety/shrink |
| EnemyProxyRendererVisualTest | **REVIEW** | 70% | hard display requirement; self-skips headless with exit 0 (invisible to headless runs) |
| EnemyProxyRolloutTest | KEEP | 75% | "rollout" framing stale (flag defaults true) but the flag is still the production gate |
| EnemyProxySimulationTest | KEEP | 90% | only coverage of rate-change interpolation continuity |
| EnemyRepresentationLeaseTest | KEEP | 90% | sole unit coverage of lease round-trip |
| EnemyRepresentationPolicyTest | KEEP | 90% | only test of reason telemetry + burst demotion |
| EnemyRunTransitionSoakTest | KEEP | 80% | unique object-growth / cross-scene renderer-orphan checks; ~50 s |
| EnemySimulationBenchmark | **REMOVE** | 75% | writes dead properties `_far_step_left`/`_far_delta_accum` (0 production hits; silent `.set()` no-ops); no assertions, always quit(0); compares a "population LOD layer" its own comment says is gone; superseded by pressure/horde benchmarks; not in the runner |
| EnemySimulationSchedulerTest | KEEP | 90% | largest current contract suite |
| EnemyStatusServiceTest | KEEP | 90% | only coverage of central status ticking + reentrancy |
| EnemyVisualBatchingTest | KEEP | 90% | unit guard for the invisible-enemy regression |
| EnemyWorldBenchmark | KEEP | 70% | invariant check at 600 records, no timing gate; duplicates EnemyWorldStorageTest's stale-handle/unique-iteration assertions |
| EnemyWorldBindingTest | KEEP | 90% | only direct coverage of adopt/sync/release |
| EnemyWorldSpatialTest | KEEP | 90% | only raw-grid coverage |
| EnemyWorldStorageTest | KEEP | 90% | foundational handle/generation contract |

Group B totals: dead targets 1 (EnemySimulationBenchmark); needs display 2 (EnemyProxyRendererVisualTest hard; EnemyHordeBenchmark gate only); exit 0 regardless of outcome headless 3 (EnemySimulationBenchmark, EnemyHordeBenchmark, EnemyProxyRendererVisualTest).

---

## Group C — ExchangeIdentity … PlayerDashState (27 tests)

| Test | Verdict | Conf | Evidence / notes |
|---|---|---|---|
| ExchangeIdentityTest (`-s`) | KEEP | 90% | all 13 CRITICAL_PATHS in `HubShop.tscn:80-457` live; complementary to InterfaceThemeConsistencyTest |
| ExitRiteTest | KEEP | 90% | 21 ExitRite members, 6 ledger funcs, 5 `rite_*` doctrine keys found; AUTOMATIC_PULSES/BURST_STAGES values match |
| FirstEncounterPresentationTest (`-s`) | KEEP | 80% | live and behavioural, but L45-52 assert on **raw source text** (`"func _target_is_live(target: Variant)" in overlay_source`) — a brittle string pin already covered behaviourally at L189-201; drop the two source-text assertions |
| FlowFieldAllocationBenchmark (`-s`) | **REMOVE** | 85% | benchmarks a local re-implementation of the candidate build, touches nothing in FlowFieldNav; the production buffer shape is pinned by FlowFieldUnitTest L108-111; no pass/fail summary. Plan doc misnames it `FlowFieldBenchmark.gd` (stale-docs-july-plans:56) |
| FlowFieldLoadSheddingTest | KEEP | 85% | live; shares the whole fixture with FlowFieldUnitTest — fold |
| FlowFieldThreadedBuildTest | KEEP | 90% | only worker-thread coverage |
| FlowFieldUnitTest | KEEP | 90% | core deterministic pins |
| FollowerFeedbackPresentationTest (`-s`) | KEEP | 85% | drives its own instance; the live autoload listens to the same signals (no interference observed) |
| HitFeelTest | KEEP | 85% | mutes the live autoload; wall-clock deadline loops L66-121 are mildly load-sensitive |
| HudContextPresentationTest | KEEP | 85% | end-to-end HUD context pin; ~7 s of real timers (slowest headless test in this group); screenshots only with `HUD_CONTEXT_SHOT_DIR` |
| InputBindingServiceTest (`-s`) | KEEP | 90% | documented grandfather clause L127-129 (`interact` collides on Enter / pad A) is an open decision, not dead code |
| InterfaceThemeConsistencyTest (`-s`) | KEEP | 85% | `if save_card != null` L90 / `if hud != null` L98 have **no preceding assertion** → a missing scene silently drops 4 checks |
| Level1DeterminismProbe | **REVIEW** | 75% | prints two `LEVEL1 … hash=` lines and quit(0) unconditionally; never compares runs itself ("run twice and compare", L8). To be a test it must build twice or pin a hash |
| MainMenuSettingsIntegrationTest (`-s`) | KEEP | 85% | live focus/reuse pin |
| ManagementPauseProbe | KEEP | 80% | despite the *Probe name it asserts and fails properly; screenshot guarded on headless; boots the full game |
| ManifestationHoverProbe | **REVIEW** | 70% | needs display (`Input.warp_mouse`, `frame_post_draw`, `save_png` unguarded); quits 0 on the no-player path; `if tools != null` L68 silently skips `grant_pair`. Headless-safe checks (mouse_filter, tooltip_text, `_make_custom_tooltip`) belong in a headless test |
| ManifestationPlaytestProbe | **REVIEW** | 70% | header says "needs a display; use the headless ManifestationSystemTest for CI"; quits 0 on no-player; `_probe_overheal_is_never_damage` and `_probe_styles_are_all_real` (L68-130) are headless-able regression pins that should move; `docs/MANIFESTATION_LAYER_CHANGELOG.md:153` already labels it rendered-only |
| ManifestationSystemTest | KEEP | 90% | load-bearing suite (~70 symbols verified); ThreatDirector belief-decay block L809-842 sits inside `_test_dash_hook` behind a silent `if director != null` — hoist into its own function |
| MinigunStressBenchmark | KEEP | 80% | in `run_benchmarks.ps1`; header (L6-7) still describes the per-hit VFX_SpokesBurst hypothesis, which is resolved (impacts batched via `_impact_renderer`) — refresh comment; render cpu/gpu columns are meaningless headless |
| ObjectiveShotProbe | **REVIEW** | 75% | zero assertions, always quit(0), needs display (unguarded `save_png`); keep only as a documented manual screenshot tool |
| PerformanceFlightRecorderBenchmark | **REVIEW** | 70% | its sole assertion (`debug_history_size() <= debug_history_capacity()`) duplicates PerformanceFlightRecorderTest L122; the 100k-sample timing is printed, not recorded anywhere; remove unless `average_usec` is added to the runner |
| PerformanceFlightRecorderTest | KEEP | 90% | broad recorder contract; calls `clear_world()` on the live EnemyWorld autoload |
| PerformanceIncidentWriteQueueTest | KEEP | 85% | isolates ordering + no-deep-copy handoff |
| PerformanceLifecycleTest | **REVIEW** | 70% | grab-bag of four systems (tooltip, spawner cull, EnemyIndex, overlay); overlay block L177-192 is byte-identical to PerformanceOverlayUnitTest L29-42; `docs/PERFORMANCE_PATCH_CHANGELOG.md:142` still says it "could not complete in a second headless process" (stale). Drop the overlay block, split the rest |
| PerformanceOverlayUnitTest (`-s`) | KEEP | 85% | the focused overlay unit test |
| PlayerAimStateTest (`-s`) | KEEP | 95% | pure-state |
| PlayerDashStateTest (`-s`) | KEEP | 95% | pure-state; pins i-frame ≥ duration |

Group C totals: dead targets 0/27 (the "Level1" concept is live via `Level1Builder`); needs display 3 (ManifestationHoverProbe, ManifestationPlaytestProbe, ObjectiveShotProbe); no summary / non-failing exit 5 (FlowFieldAllocationBenchmark, Level1DeterminismProbe, MinigunStressBenchmark, ObjectiveShotProbe, PerformanceFlightRecorderBenchmark) + 2 that quit 0 when the player is missing (the two Manifestation probes).

---

## Group D — PlaytestRegression … UiConsistencyVisualProbe (27 tests)

Method for this group: every script read in full; sibling `.tscn` checked; all
47 `res://` paths verified on disk; ~330 symbols/paths/strings grepped against
a flat index of the 632 production `.gd/.tscn/.tres/.cfg/project.godot` files,
then signatures confirmed at the definition sites.

| Test | Verdict | Conf | Evidence / notes |
|---|---|---|---|
| PlaytestRegressionTest | KEEP | 90% | pins the four 2026-08-23 playtest fixes; L68-87 asserts the *old* bug path of a private renderer method ("bug reproduced") — droppable |
| PrimaryObjectiveTest | KEEP | 95% | catalog + objective contract, all live |
| ProjectileHandleCombatTest | KEEP | 90% | reaches 12 private `ProjectileSimulationManager` members via `.call/.get` — brittle to refactors, all present |
| ProjectileRenderBenchmark (`-s`) | **REVIEW** | 75% | pure MultiMesh API micro-benchmark (`set_instance_*` vs `.buffer`); exercises zero project code; `quit()` with no code → always 0. Its conclusion is already pinned by ProjectileSlotReuseTest |
| ProjectileSlotReuseTest | KEEP | 85% | regression for the "removing a projectile shrank 21 packed arrays" bug; L107-125 (pixel diff) silently skipped headless |
| RenderChainProbe | **REVIEW** | 70% | 3 real assertions buried in `PROBE …` diagnostics for a fixed z-order/batching bug; bootstrap identical to RoamVisibilityProbe; boots the full game (~7 s); L41-42 crash rather than fail if the group/autoload is missing |
| RitePulseResolverTest | KEEP | 95% | static `apply` 8-arg contract, fakes mirror EnemyCombatService/player |
| RiteSafeguardIntegrationTest | KEEP | 85% | builder→rite replay layer; complements ExitRiteTest L47-51 |
| RiteSafeguardPresentationTest | KEEP | 85% | asserts literal copy "Invoke safeguard" (brittle to text edits) |
| RoamVisibilityProbe | **REVIEW** | 70% | needs display (header says so; `save_png` unguarded); no pass/fail — `_finish(0)` unconditionally; verifies an already-fixed culling bug; verbatim dismiss helpers shared with Segment1StoryProbe. REMOVE unless `roam_shots` are still eyeballed |
| RunSheetArchiveTest | KEEP | 80% | valid but brittle (asserts `.tres` copy text and literal labels); **L204-207 are vacuous negatives** — "SET IDENTITY"/"SET PROGRESSION" occur in 0 production files, "TERMS"/"BEST WITH" only in RunSheetHUD.gd; L102 `has_node` guard silently skips 2 assertions (node present) |
| SaveIntegrityTest | KEEP | 90% | writes real files to slot 97 (cleans up); pins the v0→v1 major-choice migration |
| ScriptParseAuditTest | KEEP | 95% | loads every `.gd` under `core/ ui/ autoload/ scenes/ effects/ data/`; **does not scan `res://assets` (79 VFX `.gd`), `res://spells`, `res://scripts`** — a parse error there goes unnoticed |
| SecondaryObjectiveTest | KEEP | 90% | 60 DistrictPlan generations × up to 6 retries — slow but valid; pins "two identical alley caches" fix |
| Segment1ProgressionTest (`-s`) | KEEP | 85% | 10 private Level1Builder members via `.call/.get`; hard-coded wall cells (`Vector2i(-2,31)` …) are layout-brittle; L79 `if spawner != null` silently skips 2 spawn-filter assertions; bootstrap identical to Segment1TileIntegrationTest |
| Segment1StoryProbe | **REVIEW** | 70% | needs display; its one real check (`FAIL: Segment 1 authored no exploration caches`, L114) cannot fail the run — `_finish(0)` unconditionally. Move that assertion into Segment1ProgressionTest; keep as a manual screenshot tool |
| Segment1TileIntegrationTest (`-s`) | KEEP | 75% | valid; second full game boot for one assertion — fold into Segment1ProgressionTest |
| SegmentProcStartupTest | KEEP | 85% | "handcrafted Segment 1 never starts procedural streaming" tests a bare `ChunkManager.new()`, not Segment 1 — name overstates |
| SettingsPersistenceTest (`-s`) | KEEP | 90% | pins the pre-split migration (both keys come back ON) |
| SettingsRuntimeTest (`-s`) | KEEP | 90% | restores `content_scale_factor`/`max_fps` after |
| SettingsScreenTest (`-s`) | KEEP | 90% | tabs are code-built (`"%sTab"`), all resolve |
| SpawnFilterTest (`-s`) | KEEP | 85% | relies on `EnemySpawnTable` script default `max_alive_total = 180` (the `.tres` does not override); L74/L96 `!= null` guards silently skip 4 assertions (autoloads present) |
| SpawnerRegulationTest | KEEP | 90% | spawn-storm budget + elite cap |
| StyleDpsBenchmark | **REVIEW** | 65% | balance-measurement tool with zero assertions (`STYLE …` rows, quit 0); full game run, 9 measurements; six silent `has_method` fallbacks. Relocate to `tools/perf` or remove from the test set |
| StyleParityTest | KEEP | 80% | half the checks (L40-92) are **source greps** (`FileAccess.get_file_as_string`) that a comment would satisfy; L98 silently skips 6 assertions if `anchor_rite` loses its logic. Convert to behavioural checks |
| ThreatDirectorPressureTest | KEEP | 90% | new on this branch; second ThreatDirector instance, but the `RunEvents.power_threshold_crossed` emit at L84 also reaches the live autoload |
| UiConsistencyVisualProbe | **REVIEW** | 70% | needs display; zero assertions, quit(0) unconditionally; two capture helpers (`_capture_blocking_record`, `_capture_first_encounter`, L127-172) are defined and never called; fixture classes verbatim from RunSheetArchiveTest. REMOVE if nobody reviews `ui_consistency_shots`, else trim |

Group D totals: dead targets 0/27; needs display 3 full (RoamVisibilityProbe, Segment1StoryProbe, UiConsistencyVisualProbe) + 1 partial (ProjectileSlotReuseTest L107-125); no summary / never-failing exit 5 (ProjectileRenderBenchmark, StyleDpsBenchmark, RoamVisibilityProbe, UiConsistencyVisualProbe quit 0 always; Segment1StoryProbe prints FAIL but quits 0).

---

## Status 2026-08-30 — the three REMOVEs executed; every REVIEW and every silent-skip site verified still open

Read-only re-check against HEAD `b2b1604`; nothing was executed. Since the
audit, only six audited scripts changed at all (`git diff --name-status
62bbfd3..HEAD -- tools/tests/`): three deleted, three touched in step with
production fixes. Every other table row is byte-identical, so the line
numbers above still hold.

**Executed**

- The three REMOVE rows — EnemySimulationBenchmark, FlowFieldAllocationBenchmark,
  ChunkScaleBenchmark — deleted with their `.tscn`s in `af4e23e` (cleanup
  win #8). `tools/perf/run_benchmarks.ps1` still lists exactly
  horde/minigun/pressure. With EnemySimulationBenchmark gone, the tree's only
  dead-property `.set()` writes are gone too; "tests targeting a nonexistent
  system: 0" still holds at HEAD.
- EnemyIndexTest's stale-comment note is overtaken: `7bfc6cb` removed
  `rebuild_legacy_shadow` outright (zero callers re-confirmed in that commit)
  and, deleting `nearest_enemy`/`first_in_radius` in the same change, trimmed
  EnemyIndexTest's assertions on them — the comment naming
  `rebuild_legacy_shadow` went with them; `grep -rn rebuild_legacy_shadow`
  finds nothing at HEAD. The test stayed in sync; no new dead target appeared.

**Verified still open**

- All 10 display-only/never-failing probes plus ProjectileRenderBenchmark,
  StyleDpsBenchmark and PerformanceFlightRecorderBenchmark: unchanged since
  the audit. The `c363d13` sweep (85 suites on `2dca035`, 0 failures)
  demonstrates the vacuous-pass behaviour in practice: DevConsoleShotProbe,
  ManifestationHoverProbe, ObjectiveShotProbe and UiConsistencyVisualProbe
  exited non-zero headless on their own watchdogs — red for lack of a
  display, not for any caught regression — and the rest went green having
  verified nothing.
- All 9 silent `has_method` / `!= null` skip sites: re-verified at HEAD, every
  guarded target still present (e.g. `detached_handles` still
  EnemyIndex.gd:396 for DevForceSpawnTest L117). One line shift: the
  ManifestationSystemTest director guard is now L812 — `bc13160` added a
  dangling-id test to the file (+18 lines).
- Grab-bags / brittle pins: AuditClosureTest and PerformanceLifecycleTest
  untouched; the source-text greps stand (both `_target_is_live(target:
  Variant)` definitions live for FirstEncounterPresentationTest; RunSheetArchiveTest
  L204-207 negatives still match zero production files).
- AutosaveDebounceTest still writes `slot_97.tres` via
  `save_current_profile()` (L28/L70) and never deletes it. New wrinkle: slot
  97 is now shared by three suites — SaveIntegrityTest and the new
  SaveSelectUnreadableSlotTest (`9453f95`) both `delete_slot(97)` on entry
  and/or exit — so the leftover survives a full sweep only when
  AutosaveDebounceTest runs after them; the ordering coupling on one slot is
  itself worth fixing when the leftover is.
- Doc drift, both lines re-read: the sustained-combat-pressure plan's Step 4
  block (~L403) still runs EnemyHordeBenchmark `--headless`;
  `docs/PERFORMANCE_PATCH_CHANGELOG.md:142` still says PerformanceLifecycleTest
  could not complete headless (the file was not among the records `2244764`
  moved to `docs/history/`).
- ScriptParseAuditTest scan roots unchanged (`core ui autoload scenes effects
  data`); MinigunStressBenchmark's header still states the resolved
  per-hit VFX_SpokesBurst hypothesis; BuildIdentityTest (touched by `13c7d0f`
  for the Luck fixture) still uses the capitalised `&"Momentum"`/`&"Shard"`
  ids at L53-54.

**Corrections to this audit**

- ObjectiveShotProbe "always quit(0)" is imprecise: it has a 150 s watchdog
  `quit(1)` (L18) and a no-player `quit(1)` (L85); `quit(0)` is the
  successful-screenshot path only. The substance is unchanged — zero
  assertions, so neither exit code reflects a verified behaviour.
- The ScriptParseAuditTest hole's magnitude is stale: `res://assets` holds 46
  `.gd` at HEAD (0428e8d/e7d4de0 deleted VFX scripts), not 79. The hole
  itself is open — 51 scripts across `assets/ spells/ scripts/` are unscanned.
- FlowFieldAllocationBenchmark's plan-doc-misname side note is moot with the
  benchmark deleted (`af4e23e` leaves dated docs as history).

Not covered by this audit: three suites added since — SaveSelectUnreadableSlotTest
(`9453f95`), PooledProjectileRecycleTest (`e549847`), GameOverFallbackTest
(`3619ddd`). 105 of the audited 108 remain; the suite is back at the same size.
