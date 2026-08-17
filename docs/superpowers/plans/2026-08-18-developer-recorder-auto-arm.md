# Developer Flight Recorder Auto-Arm Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Arm automatic performance recording before every developer-launched scene transition while keeping ordinary sessions unrecorded.

**Architecture:** `MainMenu` owns the launch-time policy because it is the earliest shared boundary before developer game and hub transitions. A focused method enables the recorder without changing overlay state, so each launch path retains its current UI behavior.

**Tech Stack:** Godot 4.7.1, GDScript, headless scene tests.

## Global Constraints

- Normal runs and returning to the main menu must keep disabling the recorder.
- Developer capture must begin before `Global.goto_game()` or the hub scene transition.
- Existing automatic thresholds, history, aftermath, cooldown, and report paths remain unchanged.
- Preserve all unrelated uncommitted `MainMenu` and developer-segment changes.

---

### Task 1: Arm capture for developer launch paths

**Files:**
- Create: `tools/tests/DeveloperRecorderStartupTest.gd`
- Create: `tools/tests/DeveloperRecorderStartupTest.tscn`
- Modify: `ui/screens/MainMenu.gd`

**Interfaces:**
- Consumes: `PerformanceFlightRecorder.set_enabled(value: bool) -> void`
- Produces: `MainMenu.arm_developer_flight_recorder() -> void`

- [ ] **Step 1: Write the failing integration test**

Create a scene test that instantiates the real main menu, verifies its ready state disables the recorder, calls `arm_developer_flight_recorder()`, and checks that recording becomes enabled without changing `Global.debug_performance_lab`. Repeat with both `false` and `true` overlay states.

- [ ] **Step 2: Run the test and verify the expected failure**

Run:

```text
Godot_v4.7.1-stable_win64_console.exe --headless --path . res://tools/tests/DeveloperRecorderStartupTest.tscn
```

Expected: the test reports that `MainMenu` does not expose `arm_developer_flight_recorder`.

- [ ] **Step 3: Add the minimal startup policy**

Add:

```gdscript
func arm_developer_flight_recorder() -> void:
    PerformanceFlightRecorder.set_enabled(true)
```

Call it from `_on_start_dev_pressed` and `_on_start_dev_hub_pressed` where those functions currently disable or conditionally enable the recorder. Do not alter their overlay assignments.

- [ ] **Step 4: Run focused and regression verification**

Run the new scene, `PerformanceFlightRecorderTest.tscn`, `DeveloperConsoleTest.gd`, and a headless editor initialization. Require exit code zero and every test summary to report zero failures.

- [ ] **Step 5: Inspect and commit only owned changes**

Confirm `git diff --check` is clean. Stage the two new test files and only the recorder-policy hunks from `MainMenu.gd`; preserve all unrelated worktree changes. Commit:

```text
feat: auto-arm performance capture for developer runs
```
