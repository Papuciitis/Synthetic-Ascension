# Godot Diagnostic Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove every warning and runtime physics error in the supplied Godot log without changing gameplay behavior.

**Architecture:** Cover the physics-flush failure with a focused scene test, then make opening actor creation cross a safe frame boundary before adding collision objects. Clean the static diagnostics with local renames, explicit integer rounding, and removal of declarations proven unused by repository-wide search.

**Tech Stack:** Godot 4.7.1, GDScript, scene-based headless tests

**Spec:** `C:/Users/NaurisKrišjānis/.codex/attachments/a87016e4-9e6f-4956-848d-303d1ef33bd0/pasted-text.txt`

## Global Constraints

- Preserve gameplay semantics; warning cleanup must be behavior-neutral.
- A spawned opening actor must be inside the scene tree and ready before `_spawn_actor` returns.
- Verify reported test summaries and diagnostics, not only process exit codes.

---

### Task 1: Opening-sequence physics safety

**Files:**
- Create: `tools/tests/OpeningSequencePhysicsSafetyTest.gd`
- Create: `tools/tests/OpeningSequencePhysicsSafetyTest.tscn`
- Modify: `core/systems/world/opening/OpeningSequenceController.gd:144-178,299-310`

**Interfaces:**
- Consumes: `OpeningSequenceController._spawn_actor(role, world_position, actor_spec, starts_hostile, fallback_hp)`
- Produces: an awaited `_spawn_actor` result that is ready and safely added outside physics-query flushing

- [x] **Step 1: Write the failing physics-overlap regression test**

Create an `Area2D` overlap callback that asks the controller to spawn an `OpeningActor`, then asserts after the awaited call that the actor is inside the tree and ready.

- [x] **Step 2: Run the test and verify the current implementation emits `flushing_queries` errors**

Run the focused scene headlessly and treat the matching engine error as failure.

- [x] **Step 3: Make actor spawning asynchronous at a safe frame boundary**

Add `await get_tree().process_frame` before `add_child`, and await `_spawn_actor` at all five call sites so its return contract remains “ready in tree.”

- [x] **Step 4: Re-run the focused test**

Expected: the assertions pass and output contains no `flushing_queries` error.

### Task 2: Static GDScript diagnostics

**Files:**
- Modify: the 16 scripts named by the supplied warnings under `core/`, `autoload/`, and `scenes/`

**Interfaces:**
- Consumes: existing public APIs and serialized data unchanged
- Produces: scripts that parse without the supplied shadowing, unused-value, confusable-local, or integer-division diagnostics

- [x] **Step 1: Run the parse audit with a diagnostic-output gate**

Expected before edits: the command fails because the supplied warning codes are present.

- [x] **Step 2: Apply behavior-neutral cleanup**

Rename shadowing locals/parameters; prefix intentionally unused parameters; delete declarations with no reads or writes; remove dead local constructions; replace non-negative integer division with explicit `floori(float(numerator) / float(denominator))`.

- [x] **Step 3: Run affected ascension and objective suites**

Expected: each suite reports zero failed assertions.

### Task 3: Final verification

**Files:**
- Verify all files changed by Tasks 1-2

**Interfaces:**
- Consumes: focused and existing test suites
- Produces: clean test evidence and a reviewed diff

- [x] **Step 1: Run `ScriptParseAuditTest` last**

Expected: all scripts compile, zero failed, with none of the supplied diagnostic codes in output.

- [x] **Step 2: Review the final diff and working-tree status**

Confirm changes are scoped to diagnostics, the regression test, and this plan.
