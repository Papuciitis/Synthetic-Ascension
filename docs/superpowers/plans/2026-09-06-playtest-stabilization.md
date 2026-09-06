# Playtest Stabilization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve the four playtest blockers in the Run Sheet, elite readability, hit feel, sustained-combat diagnostics, and Exit Rite encounter composition without beginning Phase 3 systems.

**Architecture:** Keep each correction at its existing ownership boundary: the Run Sheet owns wrapping and the persistent elite-modifier reference, HitFeel owns temporal and camera feedback, the flight recorder/benchmarks own performance evidence, and ExitRite plus EncounterDirector own climax pressure. Tests exercise player-visible behavior rather than source constants, and existing production defaults remain unchanged unless a controlled comparison demonstrates the cause.

**Tech Stack:** Godot 4.7.1, GDScript, scene-based headless tests, existing performance flight-recorder JSON/CSV artifacts.

**Spec:** `docs/2026-08-28-playtest-protocol.md` and the user-approved 2026-09-06 playtest-stabilization recommendations in this task.

## Global Constraints

- Do not implement Phase 3 objectives or the proposed Follower progression layer.
- Preserve the user's existing `project.godot` change and untracked performance captures.
- Use `C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe` for automated checks.
- Keep the Exit Rite viable for melee, ranged, and magic rather than turning it into a ranged-only bullet hell.
- Keep elite modifier rules cross-archetype and recoverable after their transient introduction.

---

### Task 1: Bounded Run Sheet layout and persistent elite-modifier reference

**Files:**
- Modify: `ui/widgets/RunSheetHUD.gd`
- Modify if the layout contract requires it: `ui/widgets/RunSheetHUD.tscn`
- Modify: `tools/tests/RunSheetArchiveTest.gd`
- Modify or create a focused visual-layout probe under: `tools/tests/`

**Interfaces:**
- Consumes: `EliteModifiers.ALL`, `EliteModifiers.label(id)`, `EliteModifiers.teach_line(id)`, `EliteModifiers.tint(id)`, and the profile-persistent teaching/discovery state.
- Produces: wrapped Manifestation noun/resource rows that never enlarge the fixed Run Sheet and a persistent `ELITE MODIFIERS` reference on Observations for encountered modifier ids.

- [ ] Write a failing test that instantiates the Run Sheet at its production width, supplies enough noun/resource text to reproduce the screenshot, settles layout, and proves every Manifestations descendant remains inside the body viewport horizontally.
- [ ] Run `RunSheetArchiveTest.tscn` and the focused layout probe; verify the new assertion fails for horizontal overflow.
- [ ] Replace the non-wrapping horizontal noun/resource presentation with a bounded wrapping layout that preserves per-noun colours and does not create horizontal scrolling.
- [ ] Re-run the focused tests and verify the Manifestations bounds pass.
- [ ] Write a failing test that marks elite modifiers as encountered, rebuilds Observations, and asserts their labels and counters remain readable without relying on the spawn popup.
- [ ] Add a single cross-archetype `ELITE MODIFIERS` reference section, displaying only encountered modifiers with their existing colour vocabulary and counter text.
- [ ] Run `RunSheetArchiveTest.tscn`, `EliteModifierTest.tscn`, the layout probe, and `ScriptParseAuditTest.tscn`.

### Task 2: Isolate temporal hit-stop from camera punch

**Files:**
- Modify: `tools/tests/HitFeelTest.gd`
- Modify only if evidence identifies a behavioral defect: `autoload/HitFeel.gd`
- Record findings: `docs/diagnostics/2026-09-06-hit-feel-comparison.md`

**Interfaces:**
- Consumes: `HitFeel.hit_stop_enabled`, `HitFeel.camera_punch_enabled`, `request_stop()`, `punch_direction()`, `get_debug_counters()`.
- Produces: a repeatable four-arm comparison (`both`, `hit-stop only`, `camera punch only`, `neither`) and a documented ruling about which mechanism can present as lag.

- [ ] Extend the test harness with four controlled configurations driven by the same hit/kill sequence and record time-scale changes separately from camera offsets.
- [ ] Run `HitFeelTest.tscn` and verify the comparison catches accidental coupling between the two mechanisms.
- [ ] Analyze the four arms: temporal slowdown must appear only with hit-stop and positional displacement only with camera punch.
- [ ] If the repeated-kill arm demonstrates an excessive temporal duty cycle, first add a failing behavioral assertion limiting ordinary-kill slowdown while preserving crit, elite, and melee impact.
- [ ] Implement only the minimal confirmed HitFeel correction, then re-run `HitFeelTest.tscn`.
- [ ] Write the measured comparison and resulting decision to the diagnostics note.

### Task 3: Profile sustained combat and recorder overhead

**Files:**
- Modify only if a diagnostic blind spot is confirmed: `autoload/PerformanceFlightRecorder.gd`
- Modify only if needed to make the comparison repeatable: `tools/tests/PerformanceFlightRecorderBenchmark.gd`
- Modify only if needed for the sustained workload: `tools/tests/EnemyPressureBenchmark.gd`
- Record findings: `docs/diagnostics/2026-09-06-sustained-combat-profile.md`

**Interfaces:**
- Consumes: existing September 6 incident JSON/CSV, `PerformanceFlightRecorder.enabled`, sampling-overhead telemetry, and `EnemyPressureBenchmark` scenario controls.
- Produces: recorder-on/off benchmark evidence, enemy-pressure bins, dominant-thread evidence, and one ranked root-cause hypothesis for subsequent optimization.

- [ ] Run the recorder microbenchmark and record average and tail sampling cost.
- [ ] Run the same deterministic enemy-pressure workload with recorder enabled and disabled; do not compare different seeds or enemy mixes.
- [ ] Parse the existing September 6 captures into unique samples per session so overlapping incident windows are not double-counted.
- [ ] Compare frame time by enemy count, projectiles, active physics objects, simulation tier, flow builds, and recorder overhead.
- [ ] If instrumentation itself exceeds its intended budget, write a failing recorder benchmark assertion before reducing its cost; otherwise leave production recorder code unchanged.
- [ ] Write the evidence, confounds, and ranked next optimization target to the diagnostics note.
- [ ] Run `PerformanceFlightRecorderTest.tscn`, `PerformanceFlightRecorderBenchmark.tscn`, and any modified pressure benchmark.

### Task 4: Deliberate Exit Rite composition and legible lane-opening pulses

**Files:**
- Modify: `core/systems/encounters/EncounterDirector.gd`
- Modify: `core/systems/world/ExitRite.gd`
- Modify if a scoped spawn-composition seam is required: `core/systems/spawner/spawner.gd`
- Modify: `tools/tests/RiteClimaxTest.gd`
- Modify: `tools/tests/ExitRiteTest.gd`
- Modify or create a focused encounter-composition test under: `tools/tests/`

**Interfaces:**
- Consumes: `ThreatDirector.rite_channel_changed`, `EncounterDirector.rite_specialist_beats`, Exit Rite automatic pulses, and the spawner's ambient/special capacity APIs.
- Produces: a bounded nearby melee pressure contract, sustained but capped readable ranged pressure, retained movement threats, and automatic pulses that visibly create a traversable lane without deleting the whole encounter.

- [ ] Write a failing encounter test proving Rite pressure cannot become an unbounded melee carpet near the sigil while preserving some melee/charger pressure.
- [ ] Write a failing encounter test proving the Rite can replenish a bounded specialist response after the initial two-sniper crossfire rather than firing it only once.
- [ ] Add the smallest Rite-scoped composition seam at the spawner/director boundary; do not change ordinary segment spawning.
- [ ] Run the focused encounter test and verify both composition contracts pass.
- [ ] Write a failing Rite pulse test proving each automatic seal pushes/stuns enough nearby enemies to open a lane, while enemies beyond the pulse remain part of the fight.
- [ ] Tune the existing automatic pulse profiles and presentation only as needed to satisfy that lane-opening contract; do not add a new screen-wipe ability.
- [ ] Run `RiteClimaxTest.tscn`, `ExitRiteTest.tscn`, `RitePulseResolverTest.tscn`, the focused composition test, and `ScriptParseAuditTest.tscn`.

### Task 5: Integrated verification

**Files:**
- No production files unless a focused regression is found.

**Interfaces:**
- Consumes: Tasks 1–4.
- Produces: one green verification record and a concise manual playtest checklist.

- [ ] Run every focused suite named above in one clean invocation.
- [ ] Run `PlaytestRegressionTest.tscn` and `ManagementPauseProbe.tscn`.
- [ ] Review `git diff --check`, `git status --short`, and the complete diff without altering unrelated changes.
- [ ] Request a final code review against this plan and resolve any critical or important findings.
- [ ] Report changed behavior, measured evidence, remaining perceptual checks, and exact tests to the user.
