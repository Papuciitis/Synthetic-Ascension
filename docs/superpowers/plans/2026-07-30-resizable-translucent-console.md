# Resizable Translucent Console Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the developer console translucent and resizable from every edge and corner.

**Architecture:** Keep presentation and pointer handling in `PerformanceOverlay`. Separate pure edge detection and rectangle calculation from event handling so resize behavior is deterministic and directly testable.

**Tech Stack:** Godot 4.7, GDScript, `.tscn` theme resources, headless SceneTree tests.

## Global Constraints

- Panel background alpha is 0.72.
- Minimum panel size is 720×480.
- All four edges and four corners resize with appropriate cursors.
- Resulting rectangles remain inside the viewport.
- Tabs shrink and scroll rather than clip.

---

### Task 1: Resize geometry

**Files:**
- Modify: `tools/tests/DeveloperConsoleTest.gd`
- Modify: `ui/widgets/PerformanceOverlay.gd`

**Interfaces:**
- Produces: `resize_edges_at(local_position: Vector2, panel_size: Vector2) -> int`
- Produces: `resized_rect(start_rect: Rect2, edge_mask: int, drag_delta: Vector2, viewport_size: Vector2) -> Rect2`

- [ ] Add failing assertions for right-edge detection, bottom-right detection, minimum-size clamping, and viewport clamping.
- [ ] Run the developer-console test and confirm the new methods are missing.
- [ ] Implement edge masks and pure resize geometry.
- [ ] Run the test and confirm the geometry assertions pass.

### Task 2: Pointer interaction and adaptive layout

**Files:**
- Modify: `ui/widgets/PerformanceOverlay.gd`
- Modify: `ui/widgets/PerformanceOverlay.tscn`
- Test: `tools/tests/DeveloperConsoleTest.gd`
- Test: `tools/tests/PerformanceOverlayUnitTest.gd`

**Interfaces:**
- Consumes: resize geometry from Task 1.
- Produces: live edge/corner dragging, cursor feedback, 72% opacity, and scrollable adaptive tabs.

- [ ] Wire mouse press, motion, and release to the resize geometry.
- [ ] Change panel background alpha to 0.72 and reduce the tab minimum height to support 720×480.
- [ ] Run both focused test suites and headless project startup.
- [ ] Visually verify resizing and readability at 1920×1080.
