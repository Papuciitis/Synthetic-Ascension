# Sustained Combat Pressure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce sustained mixed-horde physics cost by releasing ordinary offscreen smart-enemy collision earlier under measured pressure, while proving that protected and nearby threats retain their existing collision contracts.

**Architecture:** Keep `EnemySimulationScheduler` as the single pressure-state authority and replace distance multipliers with explicit normal, pressure, and emergency release/reacquire pairs. Add a narrowly gated severe-pressure fast path, surface flow snapshot/worker/publish timings without changing navigation, and validate the hypothesis first with deterministic contracts and then with a reproducible 120-actor benchmark against a saved baseline.

**Tech Stack:** Godot 4.7.1, GDScript, CharacterBody2D physics, WorkerThreadPool, headless SceneTree tests, runtime benchmark reports.

**Spec:** `docs/superpowers/specs/2026-08-25-sustained-combat-pressure-design.md`

## Global Constraints

- Normal smart release/reacquire distances are 2,600/2,300 px.
- Pressure smart release/reacquire distances are 1,600/1,400 px.
- Emergency smart release/reacquire distances are 1,450/1,250 px.
- A physics step of at least 40 ms may promote directly to emergency only after 0.15 seconds of continued severe readings.
- Recovery remains slower than engagement and steps down one pressure level at a time.
- Bosses, minibosses, elites, objectives, tutorial actors, summons, active interior actors, boss adds, and snipers retain their existing protection rules.
- Actors inside the full spatial band remain in full simulation.
- Data-side projectile targeting remains generation-safe.
- Management pause and first-encounter pause continue to stop simulation.
- The threaded flow-field algorithm is not changed.
- The existing 550-actor benchmark gate must not regress.
- The focused 120-actor benchmark must achieve physics p95 at most 20 ms, frame p95 at most 33 ms, no more than 64 ordinary physics-enabled actors plus protected actors, and at least 20% physics-p95 improvement from its pre-change baseline.
- Scene-transition/materialization hitches and encounter population changes are out of scope.
- Preserve unrelated user changes and keep `.superpowers/` and previous performance captures out of feature commits.

---

## File Structure

- `autoload/EnemySimulationScheduler.gd`: owns explicit distance bands, pressure transitions, severe fast-path timing, and scheduler telemetry.
- `core/actors/enemy/enemy.gd`: asks the scheduler for the active smart-physics boundary and preserves all protection/contact rules.
- `core/systems/world/FlowFieldNav.gd`: records snapshot, worker, and publish durations around the unchanged threaded build.
- `autoload/PerformanceFlightRecorder.gd`: copies flow timing fields into slow snapshots and incident output.
- `tools/tests/EnemySimulationSchedulerTest.gd`: deterministic distance, protection, hysteresis, and pressure-transition contracts.
- `tools/tests/FlowFieldThreadedBuildTest.gd`: deterministic split telemetry contract around a real worker build.
- `tools/tests/PerformanceFlightRecorderTest.gd`: incident snapshot contract for new flow timing fields.
- `tools/tests/EnemyPressureBenchmark.gd` and `.tscn`: reproducible 120-actor mixed horde, baseline comparison, and acceptance gate.
- `tools/tests/EnemyHordeBenchmark.gd`: retains and reports the existing staged 120/250/400/550 regression gate.

### Task 1: Record the 120-Actor Mixed-Horde Baseline

**Files:**
- Create: `tools/tests/EnemyPressureBenchmark.gd`
- Create: `tools/tests/EnemyPressureBenchmark.tscn`
- Create at runtime: `performance_results/2026-08-25/enemy-pressure-baseline.json`

**Interfaces:**
- Consumes: real `enemy.tscn`, `EnemySpec_Grunt`, `EnemySpec_Runner`, `EnemySpec_Orbiter`, `EnemySpec_Spitter`, `EnemySpec_Charger`, `EnemySpec_Bomber`, `EnemySpec_Leech`, and `EnemySpec_Sniper` resources; scheduler debug counters; `BENCHMARK_REPORT_PATH` environment variable.
- Produces: baseline JSON fields `source_sha`, `actor_count`, `protected_count`, `frame_p95_ms`, `physics_p95_ms`, `physics_enabled`, `ordinary_physics_enabled`, and `pressure_level`.

- [ ] **Step 1: Create the deterministic benchmark scene and driver**

The scene contains a minimal `Node2D` arena, a stationary player in group `player`, and the benchmark driver. Instantiate exactly 120 enemies in six rings from 900 px through 3,200 px. Cycle ordinary specs in this order: Runner, Orbiter, Spitter, Charger, Bomber, Leech. Every twentieth actor is a sniper and is counted as protected. Disable drops and first-encounter presentation, allow scheduler assignment, warm up for 4 seconds, then collect 20 seconds of frame and physics samples.

Write the report with:

```gdscript
var report := {
	"source_sha": OS.get_environment("BENCHMARK_SOURCE_SHA"),
	"actor_count": 120,
	"protected_count": protected_count,
	"frame_p95_ms": _percentile(frame_samples, 0.95),
	"physics_p95_ms": _percentile(physics_samples, 0.95),
	"physics_enabled": int(counters.get("physics_enabled", 0)),
	"ordinary_physics_enabled": int(counters.get("physics_enabled", 0)) - protected_count,
	"pressure_level": int(counters.get("pressure_level", 0)),
}
```

The driver exits non-zero if it creates any actor count other than 120, loses the player reference, produces fewer than 600 samples, or cannot write `BENCHMARK_REPORT_PATH`.

- [ ] **Step 2: Parse the new harness before measuring**

```powershell
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/ScriptParseAuditTest.tscn
```

Expected: exit 0 with both new benchmark files included in the parse audit.

- [ ] **Step 3: Record the untouched scheduler baseline**

Run before changing `EnemySimulationScheduler.gd` or `enemy.gd`:

```powershell
$env:BENCHMARK_SOURCE_SHA = (git rev-parse HEAD).Trim()
$env:BENCHMARK_REPORT_PATH = (Resolve-Path '.\performance_results\2026-08-25').Path + '\enemy-pressure-baseline.json'
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/EnemyPressureBenchmark.tscn
```

Expected: exit 0 and a JSON report containing all eight fields. Copy the printed p95 values into the implementation checkpoint notes; do not edit the report after the run.

- [ ] **Step 4: Commit the benchmark harness without generated results**

```powershell
git add -- tools/tests/EnemyPressureBenchmark.gd tools/tests/EnemyPressureBenchmark.tscn
git commit -m "test: add mixed horde pressure benchmark"
```

Keep `performance_results/2026-08-25/enemy-pressure-baseline.json` as an uncommitted verification artifact.

### Task 2: Explicit Pressure-Aware Smart Physics Boundaries

**Files:**
- Modify: `tools/tests/EnemySimulationSchedulerTest.gd`
- Modify: `autoload/EnemySimulationScheduler.gd`
- Modify: `core/actors/enemy/enemy.gd`

**Interfaces:**
- Consumes: `EnemyActor.max_scheduler_tier(player_distance: float) -> int`, `EnemyActor._lod_tier`, `EnemySimulationScheduler._pressure_level`, and all existing `_is_protected` rules.
- Produces: `smart_physics_boundary(is_far: bool) -> float` and exported values `normal_smart_release_distance`, `normal_smart_reacquire_distance`, `pressure_smart_release_distance`, `pressure_smart_reacquire_distance`, `emergency_smart_release_distance`, and `emergency_smart_reacquire_distance`.

- [ ] **Step 1: Replace multiplier expectations with failing boundary assertions**

Extend `_test_smart_enemy_releases_far_physics()` so one ordinary ranged enemy is checked at both sides of every explicit threshold:

```gdscript
live_scheduler.call("set_physics_pressure_override", false)
live_scheduler.call("_update_pressure_state", 2.1)
ranged.call("set_scheduler_tier", 1)
_check(int(ranged.call("max_scheduler_tier", 2599.0)) == 1, "normal smart actor keeps collision below 2600")
_check(int(ranged.call("max_scheduler_tier", 2601.0)) == 2, "normal smart actor releases collision beyond 2600")
ranged.call("set_scheduler_tier", 2)
_check(int(ranged.call("max_scheduler_tier", 2301.0)) == 2, "normal far actor remains released above 2300")
_check(int(ranged.call("max_scheduler_tier", 2299.0)) == 1, "normal far actor reacquires below 2300")

live_scheduler.call("set_physics_pressure_override", true)
live_scheduler.call("_update_pressure_state", 0.6)
ranged.call("set_scheduler_tier", 1)
_check(int(ranged.call("max_scheduler_tier", 1599.0)) == 1, "pressure smart actor keeps collision below 1600")
_check(int(ranged.call("max_scheduler_tier", 1601.0)) == 2, "pressure smart actor releases collision beyond 1600")
ranged.call("set_scheduler_tier", 2)
_check(int(ranged.call("max_scheduler_tier", 1401.0)) == 2, "pressure far actor stays released above 1400")
_check(int(ranged.call("max_scheduler_tier", 1399.0)) == 1, "pressure far actor reacquires below 1400")

live_scheduler.call("set_physics_pressure_override", 25.0)
live_scheduler.call("_update_pressure_state", 0.6)
ranged.call("set_scheduler_tier", 1)
_check(int(ranged.call("max_scheduler_tier", 1449.0)) == 1, "emergency smart actor keeps collision below 1450")
_check(int(ranged.call("max_scheduler_tier", 1451.0)) == 2, "emergency smart actor releases collision beyond 1450")
ranged.call("set_scheduler_tier", 2)
_check(int(ranged.call("max_scheduler_tier", 1251.0)) == 2, "emergency far actor stays released above 1250")
_check(int(ranged.call("max_scheduler_tier", 1249.0)) == 1, "emergency far actor reacquires below 1250")
```

Add assertions that the same distance calls leave an elite and sniper at maximum tier 1, and that an ordinary smart actor inside `full_distance_enter` is assigned full tier by `compute_assignment` regardless of the release boundary.

- [ ] **Step 2: Run the scheduler test and verify explicit values fail**

```powershell
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/EnemySimulationSchedulerTest.tscn
```

Expected: non-zero exit because the current 0.75/0.6 multiplication yields 1950/1560 rather than 1600/1450 and does not express independent reacquire values.

- [ ] **Step 3: Replace scale exports with explicit pairs**

In `EnemySimulationScheduler.gd`, remove `pressure_release_distance_scale`, `emergency_release_distance_scale`, and `physics_release_distance_scale()`. Add:

```gdscript
@export var normal_smart_release_distance: float = 2600.0
@export var normal_smart_reacquire_distance: float = 2300.0
@export var pressure_smart_release_distance: float = 1600.0
@export var pressure_smart_reacquire_distance: float = 1400.0
@export var emergency_smart_release_distance: float = 1450.0
@export var emergency_smart_reacquire_distance: float = 1250.0

func smart_physics_boundary(is_far: bool) -> float:
	if _pressure_level >= 2:
		return emergency_smart_reacquire_distance if is_far else emergency_smart_release_distance
	if _pressure_level >= 1:
		return pressure_smart_reacquire_distance if is_far else pressure_smart_release_distance
	return normal_smart_reacquire_distance if is_far else normal_smart_release_distance
```

Expose the six values and current pair in `get_debug_counters()` so reports can identify the thresholds used during an incident.

- [ ] **Step 4: Route ordinary smart actors through the scheduler authority**

Remove `lod_smart_release_distance` and `lod_smart_reacquire_distance` from `enemy.gd`. In `_can_release_far_physics`, retain the sniper and `_lod_base_eligible()` guards, acquire `/root/EnemySimulationScheduler`, and use:

```gdscript
var boundary := 2600.0
if _lod_tier == 2:
	boundary = 2300.0
if _sim_scheduler != null and _sim_scheduler.has_method("smart_physics_boundary"):
	boundary = float(_sim_scheduler.call("smart_physics_boundary", _lod_tier == 2))
return player_distance >= maxf(boundary, 0.0)
```

Do not alter `_lod_base_eligible`, `is_simulation_protected`, sniper handling, collision-role application, or data-side projectile code.

- [ ] **Step 5: Run scheduler and projectile correctness tests**

```powershell
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/EnemySimulationSchedulerTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/ProjectileHandleCombatTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/EnemyHandleTargetingTest.tscn
```

Expected: all commands exit 0; data-side targeting and generation safety remain intact.

- [ ] **Step 6: Commit the explicit distance contract**

```powershell
git add -- autoload/EnemySimulationScheduler.gd core/actors/enemy/enemy.gd tools/tests/EnemySimulationSchedulerTest.gd
git commit -m "perf: use explicit smart physics pressure bands"
```

### Task 3: Severe-Pressure Emergency Fast Path

**Files:**
- Modify: `tools/tests/EnemySimulationSchedulerTest.gd`
- Modify: `autoload/EnemySimulationScheduler.gd`

**Interfaces:**
- Consumes: `_update_pressure_state(delta: float)`, numeric `set_physics_pressure_override(value)`, ordinary `pressure_engage_sec`, and stepwise `pressure_release_sec` recovery.
- Produces: exports `emergency_fast_pressure_ms = 40.0`, `emergency_fast_engage_sec = 0.15`, debug counter `fast_emergency_engagements`, and event `simulation/fast_emergency_engaged`.

- [ ] **Step 1: Add failing fast-path and brief-spike tests**

Add a fresh scheduler instance test:

```gdscript
func _test_severe_pressure_fast_path(scheduler_script: Script) -> void:
	var scheduler := scheduler_script.new() as Node
	add_child(scheduler)
	scheduler.call("set_physics_pressure_override", 45.0)
	scheduler.call("_update_pressure_state", 0.10)
	_check(int((scheduler.call("get_debug_counters") as Dictionary).get("pressure_level", -1)) == 0, "brief severe spike does not engage emergency")
	scheduler.call("_update_pressure_state", 0.06)
	var severe := scheduler.call("get_debug_counters") as Dictionary
	_check(int(severe.get("pressure_level", -1)) == 2, "continued 40ms pressure fast-promotes emergency")
	_check(int(severe.get("fast_emergency_engagements", 0)) == 1, "fast engagement is counted")
	scheduler.call("set_physics_pressure_override", 5.0)
	scheduler.call("_update_pressure_state", 2.1)
	_check(int((scheduler.call("get_debug_counters") as Dictionary).get("pressure_level", -1)) == 1, "recovery steps down one level")
	scheduler.call("_update_pressure_state", 2.1)
	_check(int((scheduler.call("get_debug_counters") as Dictionary).get("pressure_level", -1)) == 0, "continued relief completes recovery")
	scheduler.queue_free()
```

Keep the existing `25.0 ms` emergency test to prove ordinary two-stage escalation still works.

- [ ] **Step 2: Run the scheduler test and verify the direct promotion fails**

Run the Task 2 scheduler command. Expected: non-zero exit because severe readings currently climb only one pressure level per ordinary engage interval.

- [ ] **Step 3: Add a separate severe timer and one-shot transition**

Add `_severe_pressure_above_sec := 0.0`, reset it when pressure falls below 40 ms or adaptive budgets are disabled, and evaluate it before the ordinary measured-level branch:

```gdscript
if _measured_physics_ms() >= emergency_fast_pressure_ms and _pressure_level < 2:
	_severe_pressure_above_sec += delta
	if _severe_pressure_above_sec >= emergency_fast_engage_sec:
		_pressure_level = 2
		_pressure_active = true
		_pressure_above_sec = 0.0
		_severe_pressure_above_sec = 0.0
		_debug_counters["fast_emergency_engagements"] = int(_debug_counters.get("fast_emergency_engagements", 0)) + 1
		if PerformanceFlightRecorder != null:
			PerformanceFlightRecorder.record_event(&"simulation", &"fast_emergency_engaged", {"physics_ms": _measured_physics_ms()})
		return
else:
	_severe_pressure_above_sec = 0.0
```

Factor `_measured_physics_ms() -> float` so boolean overrides map to `budget_pressure_ms + 0.01` for `true` and `0.0` for `false`; numeric overrides return their numeric value. `_measured_pressure_level()` consumes that method. This keeps current deterministic tests meaningful.

- [ ] **Step 4: Run scheduler and pause regressions**

```powershell
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/EnemySimulationSchedulerTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/ManagementPauseProbe.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --script res://tools/tests/FirstEncounterPresentationTest.gd
```

Expected: all commands exit 0; both pause owners still stop scheduler processing.

- [ ] **Step 5: Commit the fast path**

```powershell
git add -- autoload/EnemySimulationScheduler.gd tools/tests/EnemySimulationSchedulerTest.gd
git commit -m "perf: fast-promote sustained severe physics pressure"
```

### Task 4: Split Flow-Field Timing Telemetry

**Files:**
- Modify: `tools/tests/FlowFieldThreadedBuildTest.gd`
- Modify: `tools/tests/PerformanceFlightRecorderTest.gd`
- Modify: `core/systems/world/FlowFieldNav.gd`
- Modify: `autoload/PerformanceFlightRecorder.gd`

**Interfaces:**
- Consumes: unchanged `build_nav_walkability_snapshot()`, `_run_threaded_build()`, `_publish_completed_build()`, and `FlowFieldNav.get_debug_counters()`.
- Produces: flow debug keys `last_snapshot_usec`, `last_worker_usec`, and `last_publish_usec`; flight-recorder sample keys `flow_snapshot_usec`, `flow_worker_usec`, and `flow_publish_usec`.

- [ ] **Step 1: Add failing split-timing assertions**

After the threaded build completes, add:

```gdscript
var timing := flow.get_debug_counters() as Dictionary
_check(timing.has("last_snapshot_usec") and int(timing["last_snapshot_usec"]) >= 0, "flow reports main-thread snapshot cost")
_check(timing.has("last_worker_usec") and int(timing["last_worker_usec"]) > 0, "flow reports worker build cost")
_check(timing.has("last_publish_usec") and int(timing["last_publish_usec"]) >= 0, "flow reports main-thread publish cost")
```

In `PerformanceFlightRecorderTest`, add a mock flow node in group `flow_field_nav` returning those keys, call `_collect_slow_snapshot`, and assert the three `flow_*_usec` copies equal the mock values.

- [ ] **Step 2: Run both telemetry tests and verify missing keys fail**

```powershell
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/FlowFieldThreadedBuildTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/PerformanceFlightRecorderTest.tscn
```

Expected: both commands fail only on the new split timing keys.

- [ ] **Step 3: Measure the three existing phases without changing navigation**

In `_start_rebuild`, time only `build_nav_walkability_snapshot()`. Keep `_thread_build_us` as worker time and copy it to `_debug_last_worker_usec` after joining. In `_poll_threaded_build` and sliced completion, time only `_publish_completed_build()`. Add the three keys to `get_debug_counters()` and to the existing `navigation/flow_completed` event payload:

```gdscript
{
	"snapshot_usec": _debug_last_snapshot_usec,
	"worker_usec": _debug_last_worker_usec,
	"publish_usec": _debug_last_publish_usec,
}
```

Do not change build radius, rebuild cadence, snapshot content, worker code, BFS order, or publish swapping.

- [ ] **Step 4: Copy split timings into recorder snapshots**

Initialize the three flat output keys to zero in `_collect_slow_snapshot()`. When flow counters exist, copy:

```gdscript
output["flow_snapshot_usec"] = int(flow_data.get("last_snapshot_usec", 0))
output["flow_worker_usec"] = int(flow_data.get("last_worker_usec", 0))
output["flow_publish_usec"] = int(flow_data.get("last_publish_usec", 0))
```

- [ ] **Step 5: Run flow equivalence and recorder tests**

Run both commands from Step 2. Expected: exit 0; threaded and sliced fields remain identical.

- [ ] **Step 6: Commit telemetry separately from the scheduler behavior**

```powershell
git add -- core/systems/world/FlowFieldNav.gd autoload/PerformanceFlightRecorder.gd tools/tests/FlowFieldThreadedBuildTest.gd tools/tests/PerformanceFlightRecorderTest.gd
git commit -m "perf: split flow field phase telemetry"
```

### Task 5: Apply the Focused Mixed-Horde Acceptance Gate

**Files:**
- Modify: `tools/tests/EnemyPressureBenchmark.gd`
- Modify: `tools/tests/EnemyHordeBenchmark.gd`
- Create at candidate run: `performance_results/2026-08-25/enemy-pressure-candidate.json`

**Interfaces:**
- Consumes: the Task 1 harness and immutable baseline report, candidate scheduler debug counters, and `BENCHMARK_BASELINE_PATH` environment variable.
- Produces: JSON fields `actor_count`, `protected_count`, `frame_p95_ms`, `physics_p95_ms`, `physics_enabled`, `ordinary_physics_enabled`, `pressure_level`, and `improvement_fraction`, plus a non-zero exit on a failed acceptance gate.

- [ ] **Step 1: Add the candidate acceptance gate and verify it rejects a copied baseline**

When `BENCHMARK_BASELINE_PATH` is set, load the baseline, compute:

```gdscript
var improvement := (baseline_physics_p95 - candidate_physics_p95) / maxf(baseline_physics_p95, 0.001)
var passes := (
	candidate_physics_p95 <= 20.0
	and candidate_frame_p95 <= 33.0
	and ordinary_physics_enabled <= 64
	and improvement >= 0.20
)
```

Set `improvement_fraction` in the candidate JSON and quit with code 1 when `passes` is false. First point `BENCHMARK_BASELINE_PATH` and `BENCHMARK_REPORT_PATH` to copies containing identical p95 values; expected result is non-zero exit because improvement is 0%.

- [ ] **Step 2: Run the candidate benchmark with the real baseline**

```powershell
$env:BENCHMARK_BASELINE_PATH = (Resolve-Path '.\performance_results\2026-08-25\enemy-pressure-baseline.json').Path
$env:BENCHMARK_REPORT_PATH = (Resolve-Path '.\performance_results\2026-08-25').Path + '\enemy-pressure-candidate.json'
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/EnemyPressureBenchmark.tscn
```

Expected: exit 0 only when physics p95 is at most 20 ms, frame p95 is at most 33 ms, ordinary physics-enabled count is at most 64, and physics p95 improved by at least 20%. If improvement is below 20%, revert Task 1's distance behavior while retaining the tests and telemetry, mark the hypothesis rejected in the report, and do not claim the performance fix succeeded.

- [ ] **Step 3: Retain the staged 550-actor gate**

Add an explicit final summary and non-zero exit to `EnemyHordeBenchmark.gd` when the existing stage-550 `frame p95 > 33.0`. Do not change `STAGES = [120, 250, 400, 550]`, the 20 second hold, spawn cap behavior, or population targets.

- [ ] **Step 4: Run the staged benchmark**

```powershell
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/EnemyHordeBenchmark.tscn
```

Expected: exit 0, stage 550 frame p95 at most 33 ms, and no population stage omitted.

- [ ] **Step 5: Commit benchmark gates but not generated reports**

```powershell
git add -- tools/tests/EnemyPressureBenchmark.gd tools/tests/EnemyHordeBenchmark.gd
git commit -m "test: gate sustained mixed horde pressure"
```

Keep `performance_results/2026-08-25/*.json` as verification artifacts outside the source commit unless the repository's existing benchmark policy explicitly tracks result files.

### Task 6: Full Correctness and Performance Verification

**Files:**
- Modify feature files only when a failing test or benchmark identifies a concrete defect.
- Preserve: `performance_results/2026-08-25/enemy-pressure-baseline.json`
- Preserve: `performance_results/2026-08-25/enemy-pressure-candidate.json`

**Interfaces:**
- Consumes: completed Tasks 1-5.
- Produces: a verified candidate or an explicit rejected-hypothesis result.

- [ ] **Step 1: Run parse and deterministic correctness suites**

```powershell
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/ScriptParseAuditTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/EnemySimulationSchedulerTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/FlowFieldThreadedBuildTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/PerformanceFlightRecorderTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/ProjectileHandleCombatTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/EnemyHandleTargetingTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/ManagementPauseProbe.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --script res://tools/tests/FirstEncounterPresentationTest.gd
```

Expected: every command exits 0.

- [ ] **Step 2: Re-run both performance gates from a quiet desktop state**

Run `EnemyPressureBenchmark.tscn` with the baseline environment variables, then run `EnemyHordeBenchmark.tscn`. Keep the raw console output and both JSON reports. Repeat the focused benchmark once; both candidate runs must pass so a single favorable sample cannot ship the change.

- [ ] **Step 3: Compare telemetry against the original incident signature**

Confirm the candidate shows materially fewer than 90 ordinary collision bodies around 98-102 live enemies, no protected actor in far tier, no repeated tier reversals at 1,250/1,400/1,450/1,600 px boundaries, and separate non-negative flow snapshot/worker/publish values. Do not treat scene-construction frames as evidence for or against this fix.

- [ ] **Step 4: Review the implementation against the spec**

Confirm every protected category still enters `_is_protected`, smart release applies only beyond the full spatial band, emergency recovery is stepwise, navigation logic is byte-for-byte unchanged apart from timing probes, and no spawn rate or population value changed.

- [ ] **Step 5: Commit only corrections demonstrated during verification**

Stage exact files with `git add -- <paths>` and use commit message:

```powershell
git commit -m "fix: close sustained pressure verification gaps"
```

Skip this commit when verification required no code corrections.
