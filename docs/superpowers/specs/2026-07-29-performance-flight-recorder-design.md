# Performance Flight Recorder Design

## Purpose

Random frame-rate drops are difficult to diagnose from the live performance
overlay because the relevant cause may have occurred several seconds before the
developer notices it. The performance flight recorder will preserve a compact
timeline around each incident and correlate frame health with important game
events.

This tool is developer-only. It does not change gameplay, spawn rules, enemy
behavior, projectile behavior, or release-mode balancing.

## User Experience

The Performance Lab gains a **Flight Recorder** section containing:

- Recorder enabled
- Automatic spike capture enabled
- Spike threshold in milliseconds
- Relative-baseline sensitivity
- Manual **Mark incident** button
- **Clear session** button
- Current state: idle, watching, or capturing aftermath
- Captured incident count
- Latest incident summary and saved report path

Starting a developer run with the Performance Lab enabled starts the recorder
in watching mode. It can be disabled independently when an uncontaminated
performance comparison is needed.

The default automatic trigger fires when either:

1. frame time exceeds the configured absolute threshold; or
2. frame time materially exceeds the recent moving baseline.

Defaults will target visible stutters rather than ordinary small frame-time
variance. Several adjacent bad frames are grouped into one incident.

## Capture Lifecycle

The recorder maintains a bounded rolling buffer containing ten seconds of
frame samples and event markers. A trigger freezes that history and collects
five seconds of aftermath.

The states are:

1. **Watching** — overwrite the oldest rolling samples.
2. **Triggered** — preserve the ten-second pre-trigger window.
3. **Aftermath** — append five seconds after the trigger.
4. **Finalize** — calculate a summary and write the report asynchronously or
   incrementally so a large synchronous file write does not create another
   measured spike.
5. **Cooldown** — suppress duplicate incidents briefly before returning to
   watching.

Manual markers use the same lifecycle and record the developer-provided trigger
type as `manual`.

## Frame Samples

Frame samples use preallocated or bounded containers and primitive values where
practical. Each sample records:

- monotonic timestamp and elapsed run time;
- frame delta, FPS, process time, and physics time;
- rendered objects and draw calls;
- total nodes and active 2D physics objects;
- total, ambient, special, and elite enemy counts;
- enemy simulation LOD counts;
- enemy counts by stable enemy ID when the snapshot changes;
- active and visible projectile counts;
- loaded chunk count;
- flow-field build state, revision, cells processed, and rebuild counters;
- current segment, Threat, and Resonance;
- recorder overhead when measurable.

Expensive dictionaries are not reconstructed every frame. Slowly changing
population and world snapshots are sampled at a lower frequency and referenced
by frame samples.

## Event Markers

Subsystems report small timestamped markers through a central recorder API.
Initial instrumentation covers:

- ambient spawn batch requested and completed;
- enemy type spawned, elite promotion, death, retirement, and mass cull;
- projectile stress test enabled or disabled;
- projectile capacity pressure and dropped projectile requests;
- flow-field rebuild requested, started, completed, or superseded;
- navigation revision committed;
- chunk generation, load, activation, unload, and unusually slow generation;
- procedural district generation start, validation retry, and completion;
- Resonance threshold changes and completion;
- Threat tier changes;
- boss, miniboss, event, or authored encounter start and end;
- major set/augment mass effects when they create large projectile or enemy
  batches.

Repeated high-volume events are aggregated by type and time bucket instead of
allocating one object per projectile, hit, or enemy movement tick.

The API accepts a stable category, event name, and a small details dictionary.
It must safely do nothing when recording is disabled.

## Incident Analysis

Finalization calculates:

- worst frame and its timestamp;
- average, median, 95th, and 99th percentile frame times;
- time spent below 60, 45, and 30 FPS;
- largest changes in enemy, projectile, physics-object, and node counts;
- flow or chunk operations overlapping the spike;
- event groups occurring immediately before and during the spike;
- whether process time, physics time, or both dominated;
- recorder overhead and any dropped diagnostic samples.

The report identifies correlation, not guaranteed causation. Summaries use
phrasing such as “overlapped with” and “largest nearby change” rather than
claiming an event caused a spike.

## Report Format

Each incident writes one JSON report beneath:

`user://performance_captures/`

The filename includes the date, run segment, and incident sequence. The JSON
contains metadata, summary, frame samples, slow snapshots, and event markers.
A compact CSV containing the frame timeline is written beside it for graphing.

Reports include the game version and recorder settings. A small session index
lists all incidents from the current run.

The Performance Lab displays the resolved absolute filesystem path so the
developer can find and share the files.

## Overhead Controls

- All history buffers have fixed upper bounds.
- Frame samples avoid scene-tree scans and use existing cached counters.
- Detailed population/world snapshots run at approximately 2 Hz.
- Event floods are aggregated.
- No per-enemy or per-projectile stopwatch is active during normal watching.
- Optional deep timing activates only for the five-second aftermath and only
  around selected system-level entry points.
- File output never occurs on the trigger frame.
- The recorder tracks its own sampling and finalization time.
- If the recorder exceeds its overhead budget, it records that condition and
  automatically disables optional deep timing.

The target watching overhead is below 0.20 ms per frame on the development
machine, with no unbounded memory growth.

## Architecture

### PerformanceFlightRecorder autoload

Owns settings, state transitions, rolling buffers, aggregation, incident
analysis, and report persistence. It exposes:

- `record_event(category, name, details)`
- `record_counter_event(category, name, amount, details)`
- `mark_incident(reason)`
- `set_enabled(enabled)`
- `get_status_snapshot()`

### Existing systems

Spawner, EnemyIndex, projectile simulation, flow navigation, chunk management,
procedural generation, Threat, Resonance, and encounter controllers emit
bounded event markers at existing state-transition points. They do not own
recorder state or report logic.

### PerformanceOverlay

Controls recorder settings and displays status/latest results. It does not
collect or analyze the timeline itself.

## Failure Handling

- Failure to create or write the report directory leaves the game running and
  shows an error in the Performance Lab.
- Invalid settings are clamped.
- A scene change finalizes an active incident when sufficient data exists;
  otherwise it discards the incomplete incident explicitly.
- Reports use schema versioning so future tooling can migrate them.
- Recorder failures never block spawning, navigation, combat, or scene changes.

## Testing

Automated tests cover:

- rolling-buffer eviction;
- absolute and relative spike detection;
- incident grouping and cooldown;
- ten-second pre-history and five-second aftermath boundaries;
- manual incident capture;
- event aggregation;
- percentile and worst-frame summaries;
- report schema and safe filename creation;
- disabled-recorder no-op behavior;
- write-failure handling;
- bounded memory and dropped-sample accounting;
- overlay controls and status formatting.

A headless integration test emits synthetic frames and subsystem events, then
verifies the resulting incident timeline. A benchmark verifies that watching
overhead remains within the stated target in the test environment. Runtime
testing will then compare recorder-off and recorder-on FPS in the same stress
scenario.

## Out of Scope

- Redesigning the complete Developer Mode interface.
- Automatically changing gameplay to fix a detected spike.
- Claiming causal certainty from timing correlation.
- Recording every collision, hit, projectile, or enemy tick.
- Shipping the recorder enabled in ordinary player runs.
