# Unified Developer Console Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace fragmented developer panels with one tabbed F8 console while keeping a compact developer-run launcher on the main menu.

**Architecture:** Extend `PerformanceOverlay` into the single runtime console and treat `DevSetCollisionTools` as a headless action service. Gate the console through a new session-only `Global.debug_dev_mode` flag set by developer launch actions.

**Tech Stack:** Godot 4.7, GDScript, `.tscn` scenes, headless SceneTree tests.

## Global Constraints

- Developer tools are unavailable in ordinary runs.
- Projectile stress defaults off and is visibly identified as artificial load.
- Main Menu and Exit Game require confirmation.
- F8 toggles the console; Escape closes it.

---

### Task 1: Developer session and console contract

**Files:**
- Modify: `autoload/global.gd`
- Modify: `ui/screens/MainMenu.gd`
- Test: `tools/tests/DeveloperConsoleTest.gd`

- [ ] Write a failing headless test asserting the global developer-session flag exists and starts false.
- [ ] Run the test and confirm the missing-property failure.
- [ ] Add `debug_dev_mode`, reset it on menu entry, and enable it from both developer launch routes.
- [ ] Run the test and confirm it passes.

### Task 2: Tabbed runtime console

**Files:**
- Modify: `ui/widgets/PerformanceOverlay.tscn`
- Modify: `ui/widgets/PerformanceOverlay.gd`
- Test: `tools/tests/DeveloperConsoleTest.gd`

- [ ] Extend the failing test to require Overview, Enemies, Performance, and Tests tabs plus footer navigation.
- [ ] Run the test and confirm the missing-node failures.
- [ ] Recompose the overlay as a centered tabbed panel, preserve snapshot/enemy/recorder behavior, and wire F8/Escape.
- [ ] Add projectile stress and confirmation-based menu/exit actions.
- [ ] Run the console and existing overlay tests.

### Task 3: Fold set/collision/opening tools into the console

**Files:**
- Modify: `autoload/DevSetCollisionTools.gd`
- Modify: `ui/widgets/PerformanceOverlay.gd`
- Modify: `ui/widgets/PerformanceOverlay.tscn`
- Test: `tools/tests/DeveloperConsoleTest.gd`

- [ ] Extend the failing test to require all test-action groups.
- [ ] Stop `DevSetCollisionTools` from constructing its own panel while retaining its public action methods.
- [ ] Connect console controls to those methods, including set grants, combat-state actions, collision fixture, opening modes/phases/responses, migration, and segment jumps.
- [ ] Run the full headless test suite and project validation.

### Task 4: Main-menu cleanup and final verification

**Files:**
- Modify: `ui/screens/MainMenu.tscn`
- Modify: `ui/screens/MainMenu.gd`

- [ ] Remove runtime-only toggles from the launcher and improve labels/help text.
- [ ] Run a headless project parse, targeted console tests, and all existing tests.
- [ ] Inspect the console at 1920×1080 and verify it remains usable at smaller viewport sizes.
