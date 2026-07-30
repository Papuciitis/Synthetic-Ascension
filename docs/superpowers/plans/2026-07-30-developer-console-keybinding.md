# Developer Console Keybinding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Godot-reserved F8/F9 console shortcuts with the standard backtick/tilde key.

**Architecture:** Keep input handling inside `PerformanceOverlay`; change only its accepted toggle event and the two visible shortcut hints. Preserve Escape-to-close and developer-session gating.

**Tech Stack:** Godot 4.7, GDScript, headless SceneTree tests.

## Global Constraints

- F8 and F9 must not toggle the console.
- Backtick/tilde must toggle the console.
- Escape must continue to close the console.

---

### Task 1: Replace the console shortcut

**Files:**
- Modify: `tools/tests/DeveloperConsoleTest.gd`
- Modify: `ui/widgets/PerformanceOverlay.gd`
- Modify: `ui/widgets/PerformanceOverlay.tscn`
- Modify: `ui/screens/MainMenu.tscn`

**Interfaces:**
- Consumes: `PerformanceOverlay._input(event: InputEvent)`.
- Produces: backtick/tilde toggling with no F8/F9 handling.

- [ ] Add assertions that keycode 96 opens the console and F8 leaves it closed.
- [ ] Run `DeveloperConsoleTest.gd` and confirm the shortcut assertions fail.
- [ ] Replace the F8/F9 condition with keycode 96 and update both UI hints.
- [ ] Run the console and overlay tests and confirm they pass.
