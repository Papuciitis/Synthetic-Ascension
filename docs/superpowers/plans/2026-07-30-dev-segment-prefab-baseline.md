# Dev Segment Prefab Baseline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an isolated developer-only segment assembled from pre-authored empty-outdoor and room-corner scenes, without changing normal segment generation.

**Architecture:** The main menu sets a transient `Global.debug_dev_segment` flag and launches the existing game scene. `game.gd` detects the flag before normal world setup, disables procedural generation and the normal segment builder, and instantiates one pre-authored `DevSegment.tscn`. The prototype segment contains fixed instances of two reusable PackedScene piece types; it performs no runtime layout or geometry generation.

**Tech Stack:** Godot 4.7, GDScript, PackedScene/TS CN resources, existing main-menu developer panel.

## Global Constraints

- Normal Segment 1 and Segment 2+ paths must remain behaviorally unchanged.
- Dev Segment must be selectable only from the main-menu developer panel.
- The initial prototype has no procedural buildings, plazas, courts, objectives, enemies, or progression.
- Piece geometry and collisions must be authored in scenes, not constructed by script.
- Warning fixes must not change runtime behavior.

---

### Task 1: Dev Segment launch boundary

**Files:**
- Modify: `autoload/global.gd`
- Modify: `ui/screens/MainMenu.gd`
- Modify: `ui/screens/MainMenu.tscn`
- Test: `tools/tests/DevSegmentTest.gd`

**Interfaces:**
- Produces: `Global.debug_dev_segment: bool`
- Produces: main-menu handler `_on_start_dev_segment_pressed()`

- [x] Write a failing test that loads the main menu and asserts a `StartDevSegment` button exists and that its handler enables `debug_dev_segment`.
- [x] Run the test and confirm it fails because the button and flag do not exist.
- [x] Add the transient flag, reset it on ordinary menu entry/dev-run entry, and add the developer-panel button.
- [x] Run the test and confirm it passes.

### Task 2: Pre-authored prototype scene

**Files:**
- Create: `scenes/world/dev_segment/pieces/EmptyOutdoor.tscn`
- Create: `scenes/world/dev_segment/pieces/RoomCorner.tscn`
- Create: `scenes/world/dev_segment/DevSegment.tscn`
- Modify: `scenes/game.gd`
- Test: `tools/tests/DevSegmentTest.gd`

**Interfaces:**
- Consumes: `Global.debug_dev_segment`
- Produces: a `DevSegment` node containing instances tagged `piece_role = "empty_outdoor"` and `piece_role = "room_corner"`

- [x] Extend the test to assert the prototype scene loads, contains both piece roles, and contains authored collision bodies.
- [x] Run the test and confirm it fails because the scenes do not exist.
- [x] Author the two piece scenes and assemble a fixed prototype segment from them.
- [x] Route only the dev-segment flag through this scene while disabling ChunkManager generation, Level1, enemy spawning, and normal entry sequences.
- [x] Run the focused test and confirm it passes.

### Task 3: Warning cleanup and regression verification

**Files:**
- Modify: `core/systems/world/ChunkManager.gd`
- Test: `tools/tests/DevSegmentTest.gd`

**Interfaces:**
- Preserves: `paint_tiled_rect(...)` and `paint_tiled_texture(...)` behavior with clearer parameter names.

- [x] Reproduce the warning-producing scripts in the Godot editor.
- [x] Replace integer division with explicit floating-point calculation and rename `z_index`/`modulate` parameters to `layer_z_index`/`tile_modulate`.
- [x] Run the dev-segment, tile-renderer, world-integration, main-menu/developer-console, and editor parse checks.
