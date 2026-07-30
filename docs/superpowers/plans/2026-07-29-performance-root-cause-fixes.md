# Performance Root-Cause Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the measured navigation churn, crowd-simulation pressure, projectile query allocations, and multi-chunk synchronous streaming spikes.

**Architecture:** Preserve existing gameplay algorithms while changing their scheduling and hot-path data transfer. Each root cause receives a focused regression test and independent verification.

**Tech Stack:** Godot 4.7.1, typed GDScript, existing headless tests and benchmarks.

## Global Constraints

- Snipers, elites, bosses, objectives, and active authored encounters retain full behavior.
- Projectile hit ordering, piercing, damage, and visuals do not change.
- Chunk generation remains on the main thread because scene-tree mutation is not thread-safe.
- No unbounded queues or per-frame scene-tree scans.

### Task 1: Flow build coalescing

- [ ] Add a failing test showing player movement does not cancel an active build.
- [ ] Keep the active build and replace only the pending destination.
- [ ] Permit nav revision invalidation while coalescing same-revision requests.
- [ ] Verify flow unit tests and completion counters.

### Task 2: Population-aware ambient scheduling

- [ ] Add failing tier/scheduler tests for light and heavy populations.
- [ ] Add adaptive near/mid thresholds to ordinary ambient actors.
- [ ] Run pressured mid-tier movement at 30 Hz with accumulated delta.
- [ ] Verify protected actors and snipers remain full-rate.

### Task 3: Projectile query allocation removal

- [ ] Add a failing exact-hit test for the new boolean query contract.
- [ ] Replace per-projectile result dictionaries with reusable fields.
- [ ] Verify nearest hit, exclusion, piercing inputs, and projectile tests.

### Task 4: Chunk generation queue

- [ ] Add failing queue-order and per-frame-budget tests.
- [ ] Queue missing chunks nearest-first and deduplicate coordinates.
- [ ] Generate at most one queued chunk per frame by default.
- [ ] Prune obsolete requests and preserve immediate center creation.

### Task 5: Full verification

- [ ] Run focused regression tests.
- [ ] Run recorder, overlay, lifecycle, flow, projectile, and grunt benchmarks.
- [ ] Run a complete Godot project parse scan.
- [ ] Update the performance changelog and provide the repeat-test procedure.
