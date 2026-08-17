# Chunk Streaming Rearchitecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace node-per-cell procedural chunks and the regressed full-ground TileMap conversion with compact blocker data, bounded MultiMesh visuals, batched physics, and camera-aware millisecond-budgeted streaming.

**Architecture:** Existing procedural algorithms continue choosing cell content, but standard wall/window/half-cover placements are captured in `ChunkBuildData` rather than instantiated as scenes. `ChunkBlockRenderer` and `ChunkBlockPhysics` activate that data with a bounded number of engine objects, while ChunkManager owns request ordering, camera-derived desired coordinates, timing budgets, and cleanup.

**Tech Stack:** Godot 4.7.1, typed GDScript, PackedByteArray/PackedInt32Array, MultiMeshInstance2D, StaticBody2D shape-owner APIs, existing PerformanceFlightRecorder.

## Global Constraints

- Same seed and segment must preserve blocked cells, blocker kinds, connection masks, route connectivity, and gameplay entity positions.
- Windows remain movement-blocking and projectile-pass-through.
- Half cover retains its collision radius, deterministic visual selection, rotation, and projectile behavior.
- Segment 1, manual blocked cells, unload-as-void projectile behavior, and debug overlays remain functional.
- Procedural ground remains one region-repeated Sprite2D per active chunk and creates zero ground TileMap cells.
- Generated blockers create no CoverWall/CoverHalf nodes and no CollisionShape2D descendants.
- At most three blocker StaticBody2D nodes may exist per active procedural chunk.
- Default streaming activation budget is 2.0 ms, with the count ceiling retained as a safety bound.
- No new third-party dependency; Godot 4.7.1 is the supported runtime.
- The checkout is already dirty. Never use `git add .`; stage only new files and selected hunks belonging to this plan.

---

### Task 1: Compact blocker data and deterministic visual catalog

**Files:**
- Create: `core/systems/world/chunks/ChunkBuildData.gd`
- Create: `core/systems/world/chunks/ChunkBlockVisualCatalog.gd`
- Modify: `scenes/world/cover/CoverWall.gd:43-68,87-128,287-342`
- Modify: `scenes/world/cover/CoverHalf.gd:8-48`
- Create: `tools/tests/ChunkBuildDataTest.gd`
- Create: `tools/tests/ChunkBuildDataTest.tscn`

**Interfaces:**
- Produces: `ChunkBuildData.new(coord: Vector2i, cells_per_side: int)`, `add_blocker(local_cell, kind, mask, variant) -> bool`, `kind_at(local_cell) -> int`, `mask_at(local_cell) -> int`, `variant_at(local_cell) -> int`, `occupied_indices() -> PackedInt32Array`, `add_floor_stamp(rect, texture_index, alpha, z)`, `floor_stamp_count()`, and `interactive_nodes: Array[Node]`.
- Produces: `ChunkBlockVisualCatalog.wall_texture(kind, mask) -> Texture2D`, `half_variant(world_position) -> int`, `half_texture(variant) -> Texture2D`, `half_rotation(variant) -> float`, and `texture_count() -> int`.

- [ ] **Step 1: Write the failing compact-data test**

Create a Node test scene whose test body includes literal expectations:

```gdscript
var data := ChunkBuildData.new(Vector2i(-2, 3), 4)
_check(data.add_blocker(Vector2i(1, 2), WorldBlockerGeometry.Kind.WALL, 10, 0), "first blocker write succeeds")
_check(not data.add_blocker(Vector2i(1, 2), WorldBlockerGeometry.Kind.WINDOW, 5, 0), "duplicate blocker write is suppressed")
_check(data.kind_at(Vector2i(1, 2)) == WorldBlockerGeometry.Kind.WALL, "kind code decodes without colliding with empty zero")
_check(data.mask_at(Vector2i(1, 2)) == 10, "wall mask is retained")
_check(data.occupied_indices() == PackedInt32Array([9]), "occupied index is recorded once")
_check(data.kind_at(Vector2i(0, 0)) == -1, "empty cell decodes to no blocker")
data.add_floor_stamp(Rect2i(2, 3, 5, 7), 4, 0.75, -93)
_check(data.floor_stamp_count() == 1, "floor rectangle is retained as one descriptor")
```

Add catalog checks for masks `5`, `10`, `3`, `15`, and a window straight. Use literal legacy-RNG expectations: world position `(32,32)` selects texture index `3`, quarter-turn `1`; `(96,160)` selects texture index `1`, quarter-turn `3`; `(-32,96)` selects texture index `5`, quarter-turn `1`.

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
& $godot --headless --path $repo res://tools/tests/ChunkBuildDataTest.tscn
```

Expected: non-zero exit because `ChunkBuildData` and `ChunkBlockVisualCatalog` do not exist.

- [ ] **Step 3: Implement the compact representation**

Implement the storage boundary exactly as follows:

```gdscript
extends RefCounted
class_name ChunkBuildData

var coord: Vector2i
var cells_per_side: int
var blocker_kind_code := PackedByteArray()
var blocker_mask := PackedByteArray()
var blocker_variant := PackedByteArray()
var _occupied := PackedInt32Array()
var floor_rect_and_style := PackedInt32Array() # x,y,w,h,texture_index,z per stamp
var floor_alpha := PackedFloat32Array()
var interactive_nodes: Array[Node] = []

func _init(p_coord: Vector2i, p_cells_per_side: int) -> void:
    coord = p_coord
    cells_per_side = maxi(1, p_cells_per_side)
    var count := cells_per_side * cells_per_side
    blocker_kind_code.resize(count)
    blocker_mask.resize(count)
    blocker_variant.resize(count)

func add_blocker(cell: Vector2i, kind: int, mask: int = 0, variant: int = 0) -> bool:
    var index := _index(cell)
    if index < 0 or blocker_kind_code[index] != 0:
        return false
    blocker_kind_code[index] = clampi(kind + 1, 1, 255)
    blocker_mask[index] = mask & 0xFF
    blocker_variant[index] = variant & 0xFF
    _occupied.append(index)
    return true

func kind_at(cell: Vector2i) -> int:
    var index := _index(cell)
    return -1 if index < 0 or blocker_kind_code[index] == 0 else int(blocker_kind_code[index]) - 1

func mask_at(cell: Vector2i) -> int:
    var index := _index(cell)
    return 0 if index < 0 else int(blocker_mask[index])

func variant_at(cell: Vector2i) -> int:
    var index := _index(cell)
    return 0 if index < 0 else int(blocker_variant[index])

func occupied_indices() -> PackedInt32Array:
    return _occupied

func add_floor_stamp(rect: Rect2i, texture_index: int, alpha: float, z: int) -> void:
    floor_rect_and_style.append_array(PackedInt32Array([rect.position.x, rect.position.y, rect.size.x, rect.size.y, texture_index, z]))
    floor_alpha.append(alpha)

func floor_stamp_count() -> int:
    return floor_alpha.size()

func cell_for_index(index: int) -> Vector2i:
    return Vector2i(index % cells_per_side, index / cells_per_side)

func _index(cell: Vector2i) -> int:
    if cell.x < 0 or cell.y < 0 or cell.x >= cells_per_side or cell.y >= cells_per_side:
        return -1
    return cell.x + cell.y * cells_per_side
```

Move the texture preloads and mask-to-texture match into `ChunkBlockVisualCatalog`. Encode half-cover texture in bits `0..2` and quarter-turn in bits `3..4`. Make CoverWall and CoverHalf call the catalog so legacy and batched paths have one visual authority.

- [ ] **Step 4: Run GREEN and legacy cover checks**

Run the new test and `ChunkTileRendererTest.gd`. Expected: both exit with zero test failures.

- [ ] **Step 5: Commit only Task 1 files**

```powershell
git add -- core/systems/world/chunks/ChunkBuildData.gd core/systems/world/chunks/ChunkBlockVisualCatalog.gd tools/tests/ChunkBuildDataTest.gd tools/tests/ChunkBuildDataTest.tscn
git add -p -- scenes/world/cover/CoverWall.gd scenes/world/cover/CoverHalf.gd
git commit -m "feat: add compact procedural blocker data"
```

### Task 2: Batched blocker collision geometry

**Files:**
- Create: `core/systems/world/chunks/ChunkBlockPhysics.gd`
- Create: `tools/tests/ChunkBlockPhysicsTest.gd`
- Create: `tools/tests/ChunkBlockPhysicsTest.tscn`

**Interfaces:**
- Consumes: `ChunkBuildData` and `WorldBlockerGeometry` dimensions.
- Produces: `build(data: ChunkBuildData, cell_size: int) -> void`, `clear() -> void`, `body_count() -> int`, `shape_count() -> int`, and static `rectangles_for_kind(data, kind, cell_size) -> Array[Rect2]`.

- [ ] **Step 1: Write failing geometry tests with hand-derived rectangles**

Use four 4x4 fixtures:

```gdscript
# Two horizontal wall cells: W/E masks create one 64x24 run between centers.
data.add_blocker(Vector2i(1, 1), WorldBlockerGeometry.Kind.WALL, WorldBlockerGeometry.E)
data.add_blocker(Vector2i(2, 1), WorldBlockerGeometry.Kind.WALL, WorldBlockerGeometry.W)
_check(physics.rectangles_for_kind(data, WorldBlockerGeometry.Kind.WALL, 64) == [Rect2(96, 84, 64, 24)], "two half-arms merge into one run")
```

Also assert an isolated post is `24x24` at its cell center, an L corner produces one horizontal and one vertical run, window geometry is returned separately, and two half-cover cells produce two circle owners but no CollisionShape2D nodes.

- [ ] **Step 2: Run the test and verify RED**

Expected: `ChunkBlockPhysics` is missing.

- [ ] **Step 3: Implement half-arm merging and shape-owner bodies**

Represent every N/E/S/W arm as an axis-aligned half-cell interval tagged by collision kind. Sort horizontal intervals by `(y, start_x)` and vertical intervals by `(x, start_y)`, then merge touching intervals. Create bodies only for kinds present, using layers `257` for walls, `513` for windows, and `1025` for half cover. Add RectangleShape2D/CircleShape2D resources through `shape_owner_create`, `shape_owner_add_shape`, and `shape_owner_set_transform`; do not add CollisionShape2D children.

Expose literal diagnostics from the bodies rather than making tests inspect private arrays.

- [ ] **Step 4: Run GREEN and projectile geometry tests**

Run `ChunkBlockPhysicsTest.tscn` and `PerformanceRootCauseFixTest.tscn`. Expected: all checks pass.

- [ ] **Step 5: Commit Task 2**

```powershell
git add -- core/systems/world/chunks/ChunkBlockPhysics.gd tools/tests/ChunkBlockPhysicsTest.gd tools/tests/ChunkBlockPhysicsTest.tscn
git commit -m "feat: batch procedural blocker physics"
```

### Task 3: Bounded MultiMesh blocker renderer

**Files:**
- Create: `core/systems/world/chunks/ChunkBlockRenderer.gd`
- Create: `tools/tests/ChunkBlockRendererTest.gd`
- Create: `tools/tests/ChunkBlockRendererTest.tscn`

**Interfaces:**
- Consumes: `ChunkBuildData`, ChunkBlockVisualCatalog, chunk/cell sizes.
- Produces: `configure(host, chunk_size, cell_size)`, `add_chunk(data)`, `remove_chunk(coord)`, `clear()`, and `get_stats() -> Dictionary` with `batches`, `instances`, `shadow_instances`, and `runtime_images_created`.

- [ ] **Step 1: Write the failing renderer behavior test**

Create two real ChunkBuildData objects containing repeated straight walls, a corner, a window, and half cover. Add both and assert:

```gdscript
var stats := renderer.get_stats()
_check(int(stats.instances) == 5, "one visual instance is emitted per occupied blocker cell")
_check(int(stats.shadow_instances) == 5, "shadow batches retain blocker readability")
_check(int(stats.batches) <= ChunkBlockVisualCatalog.texture_count() * 2, "renderer node count is bounded by texture variants")
_check(int(stats.runtime_images_created) == 0, "streaming creates no runtime image textures")
renderer.remove_chunk(Vector2i.ZERO)
_check(int(renderer.get_stats().instances) == 2, "chunk removal retires only its instances")
```

Verify the host contains MultiMeshInstance2D nodes but no Sprite2D, TileMapLayer, or per-cell children.

- [ ] **Step 2: Run and verify RED**

Expected: renderer script missing.

- [ ] **Step 3: Implement append-friendly texture batches**

Each texture batch owns one visual and one shadow MultiMeshInstance2D. Store arrays of `Transform2D` and owning chunk coordinates. Additions append transforms and grow MultiMesh capacity geometrically; removals swap-remove matching owners and rewrite only affected texture batches. Use the source texture directly, `TRANSFORM_2D`, scale `0.0625`, nearest/linear filtering matching legacy scenes, and the legacy `(2, 3)` shadow offset with `Color(0,0,0,0.35)`.

Never call `Texture2D.get_image`, `Image.resize`, `Image.rotate_90`, or `ImageTexture.create_from_image`.

- [ ] **Step 4: Run GREEN**

Expected: renderer test passes with zero runtime-created images and bounded nodes.

- [ ] **Step 5: Commit Task 3**

```powershell
git add -- core/systems/world/chunks/ChunkBlockRenderer.gd tools/tests/ChunkBlockRendererTest.gd tools/tests/ChunkBlockRendererTest.tscn
git commit -m "feat: batch procedural blocker visuals"
```

### Task 4: Route standard procedural blockers through compact activation

**Files:**
- Modify: `core/systems/world/ChunkManager.gd:30-38,111-149,255-286,623-679,937-950`
- Modify: `core/systems/world/proc/ChunkGenImpl.gd:207-210`
- Modify: `core/systems/world/proc/chunkgen/ChunkGenWalls.gd:106-119,122-148`
- Modify: `core/systems/world/proc/SiteOverlayImpl.gd:70-132`
- Create: `tools/tests/ChunkBlockIntegrationTest.gd`
- Create: `tools/tests/ChunkBlockIntegrationTest.tscn`

**Interfaces:**
- Produces: ChunkManager `_record_blocker(chunk, scene, cell_x, cell_y, connections_mask := 0) -> bool`, `get_block_batch_stats()`, and `batched_chunk_blockers := true`.
- Preserves: `_spawn_block(...) -> Node2D` legacy fallback for unknown PackedScenes.

- [ ] **Step 1: Write failing same-seed integration tests**

Generate a deterministic building chunk with batching enabled. Assert blocked cells are non-empty, every occupied build-data cell has the identical packed projectile descriptor, no CoverWall/CoverHalf node exists, no CollisionShape2D descendant exists, and the chunk has at most three generated blocker StaticBody2D nodes. Generate the same chunk with `batched_chunk_blockers = false` and compare literal sets of global blocked coordinates and projectile descriptors.

Add a custom PackedScene fixture and assert unknown scenes still instantiate through `_spawn_block`.

- [ ] **Step 2: Run and verify RED**

Expected: `batched_chunk_blockers` and compact activation diagnostics are absent.

- [ ] **Step 3: Integrate capture and activation**

Preload the three new chunk classes. At `_create_chunk`, allocate ChunkBuildData, make it the active generation target, run existing generation, capture generator-created Area2D/Marker2D/gameplay nodes into `data.interactive_nodes` while leaving them as normal chunk children, then:

```gdscript
var physics := ChunkBlockPhysics.new()
chunk.add_child(physics)
physics.build(data, cell_size_px)
_block_renderer.add_chunk(data)
_chunk_build_data[coord] = data
```

For standard cover scenes, `_record_blocker` writes the descriptor, `_blocked_cells`, `_chunk_blocked`, and `_projectile_blockers` directly. It computes half-cover variant from global cell center. `ChunkGenWalls` passes its mask directly instead of setting `connections_mask` on a live scene and calling `_apply` again. Other standard cover calls use mask zero. Unknown scenes keep the exact legacy path.

On unload, remove renderer instances and build data before queue-freeing the chunk; erase projectile entries for the chunk's occupied cells. Cleanup must remain safe when called twice.

- [ ] **Step 4: Run GREEN plus current chunk tests**

Run `ChunkBlockIntegrationTest.tscn`, `ChunkBuildDataTest.tscn`, `ChunkBlockPhysicsTest.tscn`, `ChunkBlockRendererTest.tscn`, and `PerformanceRootCauseFixTest.tscn`.

- [ ] **Step 5: Commit selected Task 4 hunks**

Stage new tests normally. Stage only implementation-plan hunks from the already-dirty ChunkManager and generator files, inspect `git diff --cached`, then commit:

```powershell
git commit -m "feat: activate procedural blockers from compact data"
```

### Task 5: Remove the procedural TileMap regression while preserving Segment 1

**Files:**
- Modify: `core/systems/world/ChunkManager.gd:366-422,437-580,682-744`
- Modify: `core/systems/world/proc/chunkgen/ChunkGenStamp.gd:1-68`
- Modify: `core/systems/world/ChunkTileRenderer.gd`
- Modify: `core/systems/world/Level1Builder.gd`
- Replace assertions in: `tools/tests/ChunkTileRendererTest.gd`
- Replace assertions in: `tools/tests/WorldTileIntegrationTest.gd`

**Interfaces:**
- Produces: procedural `get_chunk_render_stats()` reporting `ground_sprites`, `floor_sprites`, `block_instances`, and zero procedural tile cells.
- Preserves: verified authored Segment 1 tile conversion behind its existing path.

- [ ] **Step 1: Rewrite tests first for desired ground/stamp behavior**

Change the representative procedural test to expect one `Ground` region Sprite2D, no procedural TileMapLayer cells, no per-block sprites, and non-zero MultiMesh instances. Keep a separate authored Level1 fixture proving `_tile_authored_geometry` still converts and erases handcrafted barrier visuals.

Change WorldTileIntegrationTest to load Segment 2 and assert blocker batch stats plus region-ground counts instead of `WorldTiles_*` cells.

- [ ] **Step 2: Run and verify RED**

Expected: current procedural path still creates ground/stamp tile cells and violates new assertions.

- [ ] **Step 3: Restore low-count procedural visuals**

Make `_add_ground` always use the existing region Sprite2D branch for procedural chunks. During generation, `_stamp_floor_rect_cells` records one compact descriptor on the active ChunkBuildData; after generation, `_activate_floor_stamps(data, chunk)` creates one region-repeated Sprite2D per descriptor using the existing WorldArt texture index, alpha, and z-index. Stop `_tile_repeated_visuals` from scanning batched procedural chunks. Keep the old renderer callable only from Level1Builder or explicit legacy comparison mode. Default `tiled_world_rendering` off for procedural work without deleting the authored consumer.

- [ ] **Step 4: Run GREEN and Segment 1 integration**

Run ChunkTileRendererTest, WorldTileIntegrationTest, Segment1TileIntegrationTest, and AuditClosureTest. Expected: Segment 1 behavior remains green and Segment 2 reports zero ground TileMap cells.

- [ ] **Step 5: Commit selected Task 5 hunks**

Inspect staged diffs carefully because ChunkManager, ChunkTileRenderer, and WorldTileIntegrationTest were dirty before this plan.

### Task 6: Camera-derived desired set and elapsed-time scheduler

**Files:**
- Create: `core/systems/world/chunks/ChunkStreamPlanner.gd`
- Modify: `core/systems/world/ChunkManager.gd:6-12,170-249`
- Modify: `tools/tests/PerformanceRootCauseFixTest.gd:85-115`
- Create: `tools/tests/ChunkStreamingSchedulerTest.gd`
- Create: `tools/tests/ChunkStreamingSchedulerTest.tscn`

**Interfaces:**
- Produces: `ChunkStreamPlanner.desired_coords(center, visible_world_rect, chunk_size, prefetch) -> Array[Vector2i]` and `ordered_missing(desired, loaded, center) -> Array[Vector2i]`.
- Produces: ChunkManager exports `use_camera_stream_bounds := true`, `stream_prefetch_chunks := 1`, `stream_activation_budget_ms := 2.0`.
- Preserves: `max_chunk_generations_per_frame` as hard safety ceiling and `debug_chunk_queue()`.

- [ ] **Step 1: Write failing planner and budget tests**

Use literal cases: a `1920x1080` rect centered inside a `2048` chunk plus prefetch must produce a 3x3 desired set; a rect crossing both axes must produce the hand-listed expanded coordinate rectangle. Verify center-first Chebyshev ordering and deterministic y/x ties.

In a real ChunkManager fixture with generation/ground disabled, set `stream_activation_budget_ms = 0.001`, enqueue nine chunks, and assert a call processes at least one but fewer than nine jobs. Set count ceiling two and a large time budget, then assert exactly two jobs.

- [ ] **Step 2: Run and verify RED**

Expected: planner and elapsed-time export missing; current API only understands load radius and count.

- [ ] **Step 3: Implement planner, tokens, and budget**

Derive visible world rect from `get_viewport().get_camera_2d()`, viewport size, camera zoom, and camera global position. Use a 3x3 fallback when no camera exists. Increment `_stream_generation` whenever desired coordinates change; queued entries carry `{coord, generation}` and stale entries are discarded.

In `process_chunk_generation_queue`, always permit the first job, then stop before the next job if elapsed microseconds meet `stream_activation_budget_ms * 1000` or the count ceiling is reached. Flush renderer diagnostics once after the loop. Missing center data receives highest priority; movement never invokes an unbounded synchronous strip.

- [ ] **Step 4: Run GREEN and queue regression tests**

Run ChunkStreamingSchedulerTest and PerformanceRootCauseFixTest. Replace the old one-chunk-only assertion with separate time-budget and hard-ceiling behavior.

- [ ] **Step 5: Commit Task 6 hunks**

```powershell
git add -- core/systems/world/chunks/ChunkStreamPlanner.gd tools/tests/ChunkStreamingSchedulerTest.gd tools/tests/ChunkStreamingSchedulerTest.tscn
git add -p -- core/systems/world/ChunkManager.gd tools/tests/PerformanceRootCauseFixTest.gd
git commit -m "feat: budget camera-aware chunk streaming"
```

### Task 7: Eliminate procedural startup double generation

**Files:**
- Modify: `core/systems/world/ChunkManager.gd:151-180,341-363`
- Modify: `core/systems/world/SegmentProcBuilder.gd:68-120,241-300`
- Modify: `scenes/game.gd:109-130`
- Create: `tools/tests/SegmentProcStartupTest.gd`
- Create: `tools/tests/SegmentProcStartupTest.tscn`

**Interfaces:**
- Produces: `ChunkManager.configure_procedural_world(seed: int, connectors: Dictionary, urban_access: Dictionary, roles: Dictionary, terrain: Dictionary, archetypes: Dictionary) -> void`, `start_streaming(player_position: Vector2) -> void`, and `streaming_started: bool`.
- Removes: SegmentProcBuilder's need to call `reset_world()` after generation-disabled chunks already exist.

- [ ] **Step 1: Write failing startup lifecycle test**

Load a Segment 2 game, enable PerformanceFlightRecorder, and assert exactly one `chunk_created` event for the center coordinate before queued neighbors begin. Assert no procedural chunk was created before plan seed/roles/connectors were installed. Load Segment 1 and assert procedural streaming never starts.

- [ ] **Step 2: Run and verify RED**

Expected: current ChunkManager starts in `_ready`, then SegmentProcBuilder resets it.

- [ ] **Step 3: Implement explicit configure/start boundary**

ChunkManager `_ready` acquires dependencies but does not stream until `start_streaming`. Game setup calls the handcrafted Segment 1 path directly or creates SegmentProcBuilder. SegmentProcBuilder generates and installs all plan maps, moves/checkpoints the player, then starts streaming once. Retain `reset_world` for explicit runtime resets but do not use it for initial Segment 2 setup.

- [ ] **Step 4: Run GREEN and game integration**

Run SegmentProcStartupTest, WorldTileIntegrationTest, Segment1TileIntegrationTest, SaveIntegrityTest, and AuditClosureTest.

- [ ] **Step 5: Commit selected Task 7 hunks**

Stage only plan-owned changes from already-dirty `scenes/game.gd` and ChunkManager.

### Task 8: Remove flow-field hot-loop allocations

**Files:**
- Modify: `core/systems/world/FlowFieldNav.gd:301-342,378-405`
- Modify: `tools/tests/FlowFieldUnitTest.gd`
- Modify: `tools/tests/FlowFieldAllocationBenchmark.gd`
- Create: `tools/tests/FlowFieldUnitTest.tscn`

**Interfaces:**
- Preserves: flow directions, diagonal corner-cut prevention, wall-penalty preference, rebuild coalescing, and 1.5 ms build budget.

- [ ] **Step 1: Add a failing allocation-sensitive behavior test**

Build a literal 9x9 obstacle fixture and assert the same hand-derived directions at open, corner, and doorway cells before and after repeated rebuilds. Extend the benchmark to warm up, run 100 fixed expansions, and assert allocation delta does not grow with expansion count beyond reusable buffer initialization.

- [ ] **Step 2: Run and verify RED or record the existing hang**

Run the scene-based FlowFieldUnitTest with a 30-second process timeout. The pre-plan baseline was observed hanging under `--script`; the scene wrapper must either produce a behavior failure or expose the existing lifecycle hang before production changes.

- [ ] **Step 3: Replace per-cell arrays with reusable fixed buffers**

Move the eight direction vectors to a constant PackedVector2Array. Add reusable eight-entry candidate direction and penalty buffers on FlowFieldNav. Fill them in place, insertion-sort only the valid prefix, and replace `for oy in [-1,0,1]` literals with integer while loops. Do not alter `_visit` order semantics.

- [ ] **Step 4: Run GREEN and benchmark**

Run FlowFieldUnitTest.tscn, FlowFieldAllocationBenchmark, PerformanceRootCauseFixTest, and the Segment 2 integration scene.

- [ ] **Step 5: Commit Task 8**

```powershell
git add -- core/systems/world/FlowFieldNav.gd tools/tests/FlowFieldUnitTest.gd tools/tests/FlowFieldUnitTest.tscn tools/tests/FlowFieldAllocationBenchmark.gd
git commit -m "perf: reuse flow-field neighbor buffers"
```

### Task 9: Deterministic performance audit and complete verification

**Files:**
- Create: `tools/tests/ChunkStreamingPerformanceAudit.gd`
- Create: `tools/tests/ChunkStreamingPerformanceAudit.tscn`
- Modify: `ui/widgets/PerformanceOverlay.gd`
- Modify: `docs/PERFORMANCE_PATCH_CHANGELOG.md`

**Interfaces:**
- Produces: machine-readable `CHUNK_AUDIT` JSON with plan time, per-chunk build/activation times, blocker cells, body/shape/node counts, renderer batches/instances, tile cells, static memory, and boundary-strip totals.

- [ ] **Step 1: Add the acceptance audit before final tuning**

Use Segment 2 seed `251337`, warm resources with one discarded chunk, then generate compatibility radius 2. Fail the scene unless:

```gdscript
_check(cover_nodes == 0, "generated blocker scenes are eliminated")
_check(collision_shape_nodes == 0, "generated CollisionShape2D nodes are eliminated")
_check(blocker_body_count <= loaded_chunks * 3, "blocker bodies scale with chunks")
_check(ground_tile_cells == 0, "ground does not expand into TileMap cells")
_check(median_chunk_ms < 4.0, "median warmed chunk activation is below 4 ms")
_check(max_chunk_ms < 12.0, "no warmed chunk activation exceeds 12 ms")
```

Record static memory relative to a tiled-disabled baseline constructed in the same process.

- [ ] **Step 2: Run the audit and verify it fails any unmet gate**

Do not weaken thresholds to obtain green. Profile any failed phase using its separate timer, fix the responsible implementation under a new failing focused assertion, and rerun.

- [ ] **Step 3: Expose useful runtime diagnostics**

Update PerformanceOverlay to show queue length, oldest request age, last/median chunk build time, blocker cells, blocker bodies/shapes, MultiMesh instances/batches, and streaming budget. Remove the procedural tile-cell headline while retaining authored-tile diagnostics.

- [ ] **Step 4: Run the full verification matrix fresh**

Run, individually, with Godot 4.7.1:

```text
ChunkBuildDataTest.tscn
ChunkBlockPhysicsTest.tscn
ChunkBlockRendererTest.tscn
ChunkBlockIntegrationTest.tscn
ChunkStreamingSchedulerTest.tscn
SegmentProcStartupTest.tscn
FlowFieldUnitTest.tscn
ChunkTileRendererTest.gd
WorldTileIntegrationTest.gd
Segment1TileIntegrationTest.gd
PerformanceRootCauseFixTest.tscn
PerformanceLifecycleTest.tscn
AuditClosureTest.tscn
SaveIntegrityTest.tscn
ChunkStreamingPerformanceAudit.tscn
```

Also run a clean editor import and verify zero `SCRIPT ERROR` or parse errors. Read every exit code and final `passed, 0 failed` summary.

- [ ] **Step 5: Inspect final scope and document evidence**

Run `git diff --check`, inspect `git status --short`, and compare the final diff against this plan. Update PERFORMANCE_PATCH_CHANGELOG with before/after audit JSON values and any acceptance gate that remains unmet; do not claim completion for an unmet gate.

- [ ] **Step 6: Commit only final audit/diagnostic changes**

```powershell
git add -- tools/tests/ChunkStreamingPerformanceAudit.gd tools/tests/ChunkStreamingPerformanceAudit.tscn docs/PERFORMANCE_PATCH_CHANGELOG.md
git add -p -- ui/widgets/PerformanceOverlay.gd
git commit -m "test: verify chunk streaming performance gates"
```

## Plan Self-Review

- Spec coverage: compact data, deterministic visuals, physics batching, visual batching, direct projectile/nav registration, procedural TileMap removal, camera bounds, time budget, startup lifecycle, flow allocations, rollback, diagnostics, parity, and performance gates all have assigned tasks.
- Type consistency: every later task consumes the exact `ChunkBuildData`, `ChunkBlockVisualCatalog`, `ChunkBlockPhysics`, `ChunkBlockRenderer`, and `ChunkStreamPlanner` interfaces introduced earlier.
- Dirty-tree safety: no step stages the whole repository; shared dirty files require selected-hunk staging and cached-diff inspection.
- Test integrity: every production behavior begins with a real failing unit or integration test and includes the command and expected failure reason.
