# Performance Flight Recorder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a developer-only flight recorder that preserves a bounded timeline around performance spikes, correlates subsystem events, and exports JSON/CSV incident reports.

**Architecture:** A `PerformanceFlightRecorder` autoload owns frame sampling, the rolling history, spike detection, incident state, event aggregation, summaries, and persistence. Existing systems submit small event markers through a no-op-safe API. The existing Performance Overlay exposes controls and status without owning recorder logic.

**Tech Stack:** Godot 4.7.1, typed GDScript, JSON, CSV, existing autoload and headless test conventions.

## Global Constraints

- Watching history is 10 seconds and post-trigger aftermath is 5 seconds.
- Watching overhead target is below 0.20 ms per frame on the development machine.
- Buffers are bounded and event floods are aggregated.
- Reports identify correlation, not causal certainty.
- Recorder failures never block gameplay or scene changes.
- The recorder is disabled in ordinary player runs.
- No per-enemy or per-projectile stopwatch runs continuously.
- This folder is not a Git repository; commit steps are replaced by workspace checkpoints.

---

### Task 1: Recorder State Machine and Spike Detection

**Files:**
- Create: `autoload/PerformanceFlightRecorder.gd`
- Create: `tools/tests/PerformanceFlightRecorderTest.gd`
- Create: `tools/tests/PerformanceFlightRecorderTest.tscn`
- Modify: `project.godot`

**Interfaces:**
- Produces: `set_enabled(bool)`, `configure(Dictionary)`, `ingest_sample(Dictionary)`, `mark_incident(StringName)`, `get_status_snapshot() -> Dictionary`
- Produces signal: `incident_finalized(summary: Dictionary, report_path: String)`

- [ ] **Step 1: Write failing state-machine tests**

Test synthetic 60 Hz samples for rolling eviction, absolute trigger, relative
trigger, five-second aftermath, cooldown grouping, manual marking, and disabled
no-op behavior:

```gdscript
recorder.set_enabled(true)
for i in range(720):
    recorder.ingest_sample({"t_usec": i * 16667, "frame_ms": 16.667})
recorder.ingest_sample({"t_usec": 12_000_000, "frame_ms": 42.0})
assert(recorder.get_status_snapshot()["state"] == "aftermath")
assert(recorder.debug_history_size() <= recorder.debug_history_capacity())
```

- [ ] **Step 2: Run the test and verify it fails because the recorder does not exist**

Run:

```powershell
Godot_v4.7.1-stable_win64_console.exe --headless --path . res://tools/tests/PerformanceFlightRecorderTest.tscn
```

Expected: missing recorder script/class or missing API failure.

- [ ] **Step 3: Implement the bounded recorder core**

Use numeric states `DISABLED`, `WATCHING`, `AFTERMATH`, `COOLDOWN`. Store
samples in bounded arrays, calculate an exponential moving baseline, and trigger
when:

```gdscript
var absolute_spike := frame_ms >= absolute_threshold_ms
var relative_spike := baseline_ms > 0.0 and frame_ms >= baseline_ms * relative_multiplier
```

Keep trigger samples, ten seconds of pre-history, five seconds of aftermath,
and a two-second cooldown. Expose debug capacities for deterministic tests.

- [ ] **Step 4: Register the autoload and verify state tests pass**

Add:

```ini
PerformanceFlightRecorder="*res://autoload/PerformanceFlightRecorder.gd"
```

Run the focused test and expect zero failures.

### Task 2: Event Aggregation and Incident Summaries

**Files:**
- Modify: `autoload/PerformanceFlightRecorder.gd`
- Modify: `tools/tests/PerformanceFlightRecorderTest.gd`

**Interfaces:**
- Produces: `record_event(category: StringName, name: StringName, details := {})`
- Produces: `record_counter_event(category: StringName, name: StringName, amount: int = 1, details := {})`
- Produces: `get_latest_incident() -> Dictionary`

- [ ] **Step 1: Write failing aggregation and analysis tests**

Verify repeated spawn events share a bucket, important state events remain
ordered, worst frame and percentiles are calculated, and overlapping events are
listed without causal wording:

```gdscript
recorder.record_counter_event(&"spawn", &"grunt", 40)
recorder.record_counter_event(&"spawn", &"grunt", 20)
assert(recorder.debug_event_total(&"spawn", &"grunt") == 60)
assert(recorder.get_latest_incident()["summary"]["worst_frame_ms"] == 42.0)
```

- [ ] **Step 2: Run and verify the new assertions fail**

Expected: missing event and summary APIs.

- [ ] **Step 3: Implement bounded events and summary calculations**

Aggregate counter events into 250 ms buckets keyed by category/name/details
signature. Retain ordered transition events with a hard cap. Calculate sorted
frame-time percentiles, threshold counts, largest counter deltas, and nearby
event groups.

- [ ] **Step 4: Run focused tests and expect zero failures**

### Task 3: Safe JSON/CSV Reporting

**Files:**
- Create: `autoload/performance/PerformanceIncidentWriter.gd`
- Modify: `autoload/PerformanceFlightRecorder.gd`
- Modify: `tools/tests/PerformanceFlightRecorderTest.gd`

**Interfaces:**
- Produces: `PerformanceIncidentWriter.write_incident(incident: Dictionary, directory: String) -> Dictionary`
- Returned dictionary: `{ok: bool, json_path: String, csv_path: String, error: String}`

- [ ] **Step 1: Write failing writer tests**

Use a temporary `user://performance_capture_tests` directory. Verify schema
version, sanitized filenames, metadata, summary, samples, events, CSV header,
and non-fatal write failure:

```gdscript
var result := writer.write_incident(incident, "user://performance_capture_tests")
assert(result.ok)
assert(FileAccess.file_exists(result.json_path))
```

- [ ] **Step 2: Run and verify the writer tests fail**

- [ ] **Step 3: Implement deferred report finalization**

Create the directory recursively, write JSON with `JSON.stringify`, and write a
CSV containing timestamp, frame/process/physics time, FPS, enemy/projectile
counts, flow state, and chunks. Sanitize the date/segment/sequence filename.
Call the writer through `call_deferred` after aftermath completes.

- [ ] **Step 4: Run focused tests and expect zero failures**

### Task 4: Runtime Sampling and Event Hooks

**Files:**
- Modify: `autoload/PerformanceFlightRecorder.gd`
- Modify: `autoload/EnemyIndex.gd`
- Modify: `core/systems/spawner/spawner.gd`
- Modify: `core/combat/projectile/ProjectileSimulationManager.gd`
- Modify: `core/systems/world/FlowFieldNav.gd`
- Modify: `core/systems/world/ChunkManager.gd`
- Modify: `core/systems/world/proc/ChunkGenImpl.gd`
- Modify the existing Threat/Resonance controller files identified by project search
- Modify encounter controllers only at existing start/end transition points
- Create: `tools/tests/PerformanceFlightRecorderIntegrationTest.gd`
- Create: `tools/tests/PerformanceFlightRecorderIntegrationTest.tscn`

**Interfaces:**
- Consumes: recorder APIs from Tasks 1–3
- Produces: `collect_runtime_sample() -> Dictionary`

- [ ] **Step 1: Locate exact transition methods and write failing integration tests**

The integration test invokes representative spawn, cull, flow, chunk, Threat,
Resonance, and projectile events and verifies stable categories are present in
the captured incident.

- [ ] **Step 2: Run and verify missing runtime sample/event assertions fail**

- [ ] **Step 3: Implement low-overhead frame sampling**

Sample primitive performance monitors every process frame. Read existing cached
debug counters; sample dictionaries and enemy-type distributions at 2 Hz.
Record sampler duration and increment `dropped_samples` if the buffer cannot
accept a sample.

- [ ] **Step 4: Add bounded event hooks at existing state transitions**

Use this guarded pattern:

```gdscript
if PerformanceFlightRecorder != null:
    PerformanceFlightRecorder.record_counter_event(&"spawn", enemy_id, amount, details)
```

Never emit per-hit, per-movement-tick, or per-projectile events. Emit projectile
capacity pressure as an aggregate counter.

- [ ] **Step 5: Run focused state, writer, and integration tests**

Expect zero failures and no parser errors.

### Task 5: Performance Lab Controls and Verification

**Files:**
- Modify: `ui/widgets/PerformanceOverlay.gd`
- Modify: `ui/widgets/PerformanceOverlay.tscn`
- Modify: `ui/screens/MainMenu.gd`
- Modify: `ui/screens/MainMenu.tscn` only if the existing Performance Lab checkbox cannot carry the recorder default
- Modify: `tools/tests/PerformanceOverlayUnitTest.gd`
- Create: `tools/tests/PerformanceFlightRecorderBenchmark.gd`
- Create: `tools/tests/PerformanceFlightRecorderBenchmark.tscn`
- Modify: `docs/PERFORMANCE_PATCH_CHANGELOG.md`

**Interfaces:**
- Consumes: `set_enabled`, `configure`, `mark_incident`, `get_status_snapshot`

- [ ] **Step 1: Write failing overlay tests**

Verify controls exist for enabled, automatic capture, threshold, sensitivity,
manual mark, clear session, state, incident count, latest summary, and report
path.

- [ ] **Step 2: Run and verify controls are missing**

- [ ] **Step 3: Add the Flight Recorder section**

Bind controls directly to recorder settings. Update status at the overlay's
existing refresh cadence. Display absolute report paths using
`ProjectSettings.globalize_path`.

- [ ] **Step 4: Add and run overhead benchmark**

Feed at least 100,000 synthetic samples through watching mode, report average
sampling cost, and fail only on unbounded growth or severe regression. Record
the development-machine observed overhead separately because headless timing
varies by environment.

- [ ] **Step 5: Run the full relevant verification set**

Run:

```powershell
Godot_v4.7.1-stable_win64_console.exe --headless --path . res://tools/tests/PerformanceFlightRecorderTest.tscn
Godot_v4.7.1-stable_win64_console.exe --headless --path . res://tools/tests/PerformanceFlightRecorderIntegrationTest.tscn
Godot_v4.7.1-stable_win64_console.exe --headless --path . res://tools/tests/PerformanceOverlayUnitTest.gd
Godot_v4.7.1-stable_win64_console.exe --headless --path . res://tools/tests/PerformanceFlightRecorderBenchmark.tscn
Godot_v4.7.1-stable_win64_console.exe --headless --editor --path . --quit-after 4
```

Expected: all assertions pass, project scan exits zero, reports are produced,
and buffers remain bounded.

- [ ] **Step 6: Update changelog and perform workspace checkpoint**

Document controls, report location/schema, instrumented systems, known
correlation limits, benchmark result, and runtime test procedure.
