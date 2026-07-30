# Tiled Procedural World Rendering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace repeated procedural-world visual scene nodes with `ChunkManager`-owned `TileMapLayer` rendering while preserving generation layout, collision scenes, navigation data, and interactive objects.

**Architecture:** A focused `ChunkTileRenderer` owns one persistent runtime `TileSet` and a bounded set of visual layers beneath `ChunkManager`. Streamed chunks contain no tile layers: generation writes global cell coordinates into the shared layers, and unloading erases only the chunk's cell range. Procedural generation continues producing the same collision and navigation data. A compatibility flag keeps the original visual path available.

**Tech Stack:** Godot 4.7, GDScript, `TileMapLayer`, runtime `TileSetAtlasSource`, existing procedural chunk generator.

## Global Constraints

- Do not delete or modify source textures.
- Preserve current collision objects and blocked-cell registration.
- Preserve `DistrictPlan`, chunk streaming, and `FlowFieldNav` behavior.
- Keep interactive world objects as scenes.
- Provide a fallback to the original sprite renderer.

---

### Task 1: Runtime tile renderer and safety boundary

**Files:**
- Create: `core/systems/world/ChunkTileRenderer.gd`
- Modify: `core/systems/world/ChunkManager.gd`
- Test: `tools/tests/ChunkTileRendererTest.gd`

**Interfaces:**
- Produces: `begin_chunk(chunk: Node2D)`, `paint_ground(...)`, `paint_block(...)`, `paint_deco(...)`, `visual_node_count(chunk)`, and `enabled`.
- Preserves: all generator cell dictionaries and collision scene instances.

- [x] Write a failing test that creates a chunk renderer, begins a chunk, and expects bounded manager-owned `TileMapLayer` children plus tile cells.
- [x] Run the test and confirm failure because `ChunkTileRenderer` does not exist.
- [x] Implement runtime tile sources and persistent manager-owned visual layers.
- [x] Run the focused test and confirm it passes.

### Task 2: Convert repeated procedural visuals

**Files:**
- Modify: `core/systems/world/ChunkManager.gd`
- Modify: `core/systems/world/proc/chunkgen/ChunkGenStamp.gd`
- Modify: `core/systems/world/proc/chunkgen/ChunkGenDeco.gd`
- Modify: `core/systems/world/proc/chunkgen/ChunkGenWalls.gd`
- Modify: `scenes/world/cover/CoverWall.gd`
- Modify: `scenes/world/cover/CoverHalf.gd`
- Modify: `scenes/world/cover/CoverWindow.gd`
- Test: `tools/tests/ChunkTileRendererTest.gd`

**Interfaces:**
- Consumes: `ChunkTileRenderer` painting methods.
- Produces: tiled ground/stamps/decor/wall visuals while retaining collision-only scene instances.

- [x] Extend the test with representative wall, window, half-cover, and decoration placements; retain the already-batched chunk ground.
- [x] Run it and confirm the legacy generator still creates repeated sprite children.
- [x] Route visual placement through the tile renderer and remove only equivalent collision-scene sprites.
- [x] Run the focused test and existing chunk-generation tests.

### Task 3: Diagnostics, fallback, and integration verification

**Files:**
- Modify: `core/systems/world/ChunkManager.gd`
- Modify: `ui/widgets/PerformanceOverlay.gd`
- Modify: `tools/tests/ChunkTileRendererTest.gd`
- Modify: `docs/PERFORMANCE_PATCH_CHANGELOG.md`

**Interfaces:**
- Produces: tiled/legacy flag and visual-node/tile-cell diagnostics.

- [x] Add tests for disabling tiled rendering and retaining legacy visuals.
- [x] Implement debug counters and console reporting.
- [x] Run the renderer, developer-console, runtime flow-field, Segment 1 startup, Segment 2 integration, and project startup checks.
- [x] Compare generated node counts and document the result.

## Self-Review

- Coverage: visual batching, collision preservation, navigation preservation, fallback, diagnostics, and verification are assigned.
- Destructive changes: none; assets and legacy visual construction remain available.
- Types: all tile-renderer calls are owned by `ChunkTileRenderer` and accessed through `ChunkManager`.
