# Chunk Streaming Rearchitecture Design

## Purpose

Replace the procedural world's node-per-cell runtime representation and count-based loading queue with compact chunk data, batched blocker rendering and physics, and measured main-thread streaming. The change must preserve deterministic layouts, traversal, projectile/window behavior, visuals, and gameplay entities while removing chunk generation as a source of multi-frame stalls and sustained node/physics pressure.

## Baseline Evidence

The deterministic Segment 2 audit seed `251337` establishes the regression baseline on Godot 4.7.1:

- The 0.25.5 implementation creates 25 chunks synchronously in about 865 ms and retains about 23,000 nodes.
- The current queued implementation with tiled rendering disabled spends about 794 ms generating the same 25 chunks, with a median queued-chunk cost of 29.5 ms.
- The current queued tiled renderer spends about 5.61 seconds, with a median queued-chunk cost of 235 ms, retains about 17,000 nodes, and raises static memory by about 97 MB.
- The tiled renderer expands repeated ground into 1,024 cells per chunk and records 40,618 TileMap cells for 25 chunks.
- The generated area contains 2,776 blocker bodies and 13,871 CollisionShape2D nodes. A dense chunk contains up to 2,454 nodes.
- DistrictPlan generation itself takes about 2.25 ms. The macro procedural algorithm and save format are not the primary bottlenecks.

## Scope

This work covers procedural chunk request ordering, generation lifecycle, blocker data, blocker visuals, blocker physics, ground/floor representation, projectile registration, navigation invalidation, unloading, diagnostics, and regression/performance tests.

It does not redesign district topology, procedural building layouts, enemy spawning, combat, fog-of-war persistence, or save-file structure. Existing deterministic seeds and claimed-loot delta persistence remain authoritative.

## Selected Approach

Use a staged migration centered on a compact `ChunkBuildData` object and batched runtime services.

The existing procedural modules remain responsible for deciding where walls, windows, half cover, floors, volumes, loot, sockets, and landmarks belong. Instead of instantiating a cover scene for every blocked cell, their blocker calls write compact descriptors into `ChunkBuildData`. A dedicated blocker renderer and physics builder activate those descriptors in batches. Interactive objects remain normal nodes.

This approach removes the dominant cost without rewriting the proven district and building algorithms at the same time. It also creates a clean boundary that permits pure-data worker-thread generation later, without making threading a dependency of the first safe release.

### Rejected alternatives

1. **Keep the current TileMap conversion and tune its queue.** Rejected because it makes the measured workload roughly seven times slower, increases memory, and leaves blocker physics nodes intact.
2. **Only reduce the load radius.** Rejected as a complete fix because radius 1 still creates 8,872 nodes and takes 351 ms for the initial nine chunks.
3. **Rewrite every procedural module into worker-thread code immediately.** Rejected for the first migration because the measured plan-generation cost is already small and the current modules also create interactive Godot objects. Blocker batching provides the largest benefit with substantially lower gameplay risk.

## Architecture

### ChunkBuildData

`ChunkBuildData` is a RefCounted value owned by one chunk coordinate. It stores:

- `coord: Vector2i`
- `cells_per_side: int`
- `blocker_kind_code: PackedByteArray`, one byte per cell
- `blocker_mask: PackedByteArray`, one connection-mask byte per cell
- `half_cover_variant: PackedByteArray`, one deterministic visual variant byte per cell
- compact floor stamp descriptors
- interactive nodes produced by existing generators until those generators are independently data-separated

Kind code `0` means walkable; occupied cells store `WorldBlockerGeometry.Kind + 1` so the existing enum value `SOLID_CELL == 0` remains representable. Wall, window, and half-cover values decode back to `WorldBlockerGeometry.Kind`. Duplicate writes follow the current first-writer-wins behavior so overlaps and corner suppression remain deterministic.

The object exposes explicit methods for adding a blocker, reading a blocker, enumerating occupied cell indices, and clearing its arrays. Tests cover negative/global coordinates at the ChunkManager boundary rather than storing global positions in every descriptor.

### Procedural generation adapter

ChunkManager creates `ChunkBuildData` before invoking `ChunkGenImpl`. During generation, `_spawn_block` recognizes the configured full-wall, window, and half-cover scenes and records a descriptor instead of instantiating the scene. Wall generation passes its computed connection mask directly through a new blocker-recording API; it no longer creates a wall, changes a property after `_ready`, and invokes `_apply` again.

Unknown/custom PackedScenes continue through the legacy node-instantiation path. This compatibility path prevents unrelated procedural content from disappearing and gives future scene types an explicit migration route.

### Blocker rendering

`ChunkBlockRenderer` owns bounded MultiMeshInstance2D batches under ChunkManager. Batches are grouped by source texture; instance transforms provide position and rotation. The original imported textures are used directly with their existing 0.0625 visual scale. No texture is copied, resized, rotated, or converted during chunk loading.

Wall/window texture selection moves into a side-effect-free catalog shared by legacy CoverWall and the batch renderer. Half-cover texture selection uses the same world-coordinate hash as CoverHalf so seed/position visual determinism is preserved.

The renderer keeps descriptors per active chunk and rebuilds only dirty texture batches after chunk activation or retirement. Rebuild work is instrumented separately. Shadows are rendered by a second bounded batch set using the same transforms with the established offset and modulation. The total number of renderer nodes is bounded by texture variants, not occupied cells or active chunks.

Ground remains one region-repeated Sprite2D per active chunk. Floor rectangles remain region sprites or existing low-count stamp nodes. The current behavior that paints every ground cell into TileMapLayer is removed. `ChunkTileRenderer` is no longer used by procedural chunks and may remain only if another verified consumer exists.

### Blocker physics

`ChunkBlockPhysics` owns at most one StaticBody2D per collision layer required by a chunk: solid wall, window, and half cover. It adds shapes through shape owners rather than CollisionShape2D child nodes.

Connected wall arms are converted into maximal horizontal and vertical rectangle runs using `WorldBlockerGeometry.WALL_THICKNESS`. Isolated wall cells use `WALL_POST_SIZE`. Window cells retain their distinct collision layer while using equivalent movement geometry. Half covers reuse one CircleShape2D resource with `HALF_COVER_RADIUS` and per-owner transforms.

The expected invariant is zero generated CoverWall/CoverHalf nodes and zero generated CollisionShape2D descendants. Physics-body count grows with active chunks and collision categories, not blocked-cell count.

### Navigation and projectile data

ChunkManager continues to expose global blocked-cell and projectile queries during migration. Activating `ChunkBuildData` populates these indices directly, including the exact wall/window mask. Unloading removes entries using the chunk's occupied indices. Batched blockers do not register themselves through scene-tree group searches or owner instance IDs.

Navigation revision requests are coalesced. One revision is committed after a streaming activation/retirement batch, not once per generated or unloaded chunk. The flow-field allocation cleanup is included after chunk activation is stable: neighbor direction constants are reused and per-expanded-cell candidate arrays are removed.

### Streaming scheduler

The scheduler retains nearest-first request ordering and cancellation when the player changes chunk. It replaces the one-chunk count limit with both:

- `stream_activation_budget_ms`, default `2.0`
- `max_chunk_generations_per_frame`, retained as a safety ceiling

Each frame processes jobs while the measured elapsed time remains below the millisecond budget. Because a single generation step cannot be preempted, blocker batching must first reduce a representative dense chunk below the acceptance ceiling. Instrumentation records request age, data-build time, activation time, renderer rebuild time, and retirement time.

The center/spawn chunk is built before control is handed to the player. Surrounding chunks stream nearest-first. When the player approaches unavailable collision data, movement cannot enter the missing chunk; the scheduler prioritizes it instead of synchronously generating an unbounded strip.

The default live footprint changes from a fixed 5x5 square to camera bounds plus one chunk of prefetch. ChunkManager computes the desired rectangle from the active Camera2D viewport transformed into world space. A conservative 3x3 fallback is used when no camera is available. Unload hysteresis applies to compact data separately from active render/physics state.

### Segment startup

Segments 2+ install the DistrictPlan metadata and seed before the first procedural stream begins. ChunkManager must not first generate a generation-disabled 25-chunk field and then tear it down through `reset_world`. Segment setup gains an explicit configure/start boundary so the initial center chunk is constructed once.

Segment 1 retains its handcrafted behavior and does not activate procedural blockers.

## Failure Handling

- Invalid or missing cover textures skip only the affected visual batch and report one structured warning per texture path; collision and navigation remain active.
- A malformed blocker kind is ignored and counted by diagnostics rather than instantiating an unknown scene.
- Unknown custom blocker scenes use the legacy instantiation path.
- Stale queued jobs carry a stream generation token and are discarded before activation.
- Chunk retirement is idempotent: missing renderer, physics, blocked-grid, or projectile entries do not abort cleanup.
- Performance instrumentation is no-op safe when PerformanceFlightRecorder is disabled.

## Compatibility Requirements

- Same seed and segment must produce the same blocked cells, blocker kinds, connection masks, route connectivity, and gameplay entity positions as the pre-migration generator.
- Windows remain movement-blocking and projectile-pass-through.
- Half cover retains its collision radius, projectile behavior, deterministic texture, and rotation.
- Existing camera-independent tests may use the conservative fallback desired rectangle.
- Segment 1, manual blocked cells, unload-as-void projectile behavior, and debug overlays remain functional.
- No new third-party dependency is introduced.
- Godot 4.7.1 is the supported runtime.

## Test Strategy

Tests are written before each production change and must be observed failing for the missing behavior.

### Unit tests

- `ChunkBuildDataTest`: descriptor insertion, duplicate suppression, mask retention, half-cover variants, and occupied-index enumeration.
- `ChunkBlockPhysicsTest`: isolated posts, straight-run merging, corner/junction geometry, window layer separation, half-cover shapes, and cleanup.
- `ChunkBlockRendererTest`: deterministic texture selection, bounded batch count, instance counts, unload/rebuild behavior, and absence of runtime-generated ImageTextures.
- `ChunkStreamingSchedulerTest`: nearest-first order, stale-token cancellation, camera-derived desired rectangles, elapsed-time budget stopping, and fallback bounds.
- Existing WorldBlockerGeometry projectile tests remain green.

### Integration tests

- Same-seed parity test compares blocked cells and packed projectile descriptors between a legacy capture fixture and the batched generator.
- Procedural world test asserts no CoverWall/CoverHalf nodes and no CollisionShape2D descendants under streamed chunks.
- Segment transition test asserts the initial procedural center is generated once.
- Boundary crossing test asserts no synchronous five-chunk strip and verifies retirement cleans render, physics, blocked, and projectile state.
- Existing WorldTileIntegrationTest is replaced with blocker-batch and ground-region assertions.

### Performance acceptance test

Using Segment 2 seed `251337`, Godot 4.7.1 headless, load radius compatibility mode 2:

- No generated blocker scene nodes.
- No generated CollisionShape2D descendants.
- At most three generated blocker StaticBody2D nodes per active chunk.
- Ground representation is one region sprite per active chunk and creates zero ground TileMap cells.
- Static memory does not exceed the current tiled-disabled baseline in the same process.
- Median dense-chunk build plus activation is below 4 ms after resource warm-up.
- No measured queued chunk exceeds 12 ms after resource warm-up.
- The scheduler performs no more work after reaching its 2 ms inter-job budget.

Performance thresholds are regression gates for the fixed audit seed and environment, not claims about complete gameplay frame time.

## Delivery Sequence

1. Add failing compact-data and texture-selection tests, then implement `ChunkBuildData` and the shared visual catalog.
2. Add failing physics-batch tests, then implement `ChunkBlockPhysics`.
3. Add failing renderer tests, then implement `ChunkBlockRenderer` without runtime texture conversion.
4. Add parity tests, then route standard cover generation into descriptors while keeping a custom-scene fallback.
5. Replace tiled procedural ground/floor conversion and update integration tests.
6. Add scheduler tests, then introduce the camera-derived desired set, generation tokens, and elapsed-time budget.
7. Add startup-transition tests, then remove the procedural double-generation path.
8. Remove flow-field hot-loop allocations under tests.
9. Run the complete Godot test suite, same-seed parity suite, and performance audit; document before/after measurements.

## Rollback

The migration retains a temporary `batched_chunk_blockers` project setting/export. During development it can select the legacy cover-scene path for parity comparison. The flag is removed only after the parity and performance acceptance tests pass. The current `tiled_world_rendering` path defaults off immediately and is not used as the rollback for blockers because it is a measured regression.
