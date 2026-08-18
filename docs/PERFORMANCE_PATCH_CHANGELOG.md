# Performance Patch Changelog

## Recorded root-cause fixes

- Flow-field movement requests now replace one queued destination instead of
  cancelling the active BFS build. A pending build starts only after the active
  one completes; true navigation revisions can still invalidate stale work.
- Ordinary ambient swarm actors now use population-aware distance thresholds.
  Close actors stay fully responsive, while overflow mid-tier actors use a
  motion-preserving 30 Hz step and far actors retain their lower-rate step.
- Snipers, elites, bosses, minibosses, objectives, tutorial actors, protected
  encounters, and other non-ambient special actors remain exempt.
- Player projectile hit queries no longer allocate a result dictionary for
  every projectile on every physics frame. The exact nearest-hit and piercing
  exclusion behavior is preserved through reusable query fields.
- Chunk streaming now creates the center chunk immediately and queues remaining
  chunks nearest-first, generating one per frame by default instead of an
  entire missing row synchronously.
- Navigation revisions produced by queued chunk generation are batched until
  the queue drains.
- Automatic flight-recorder captures now require 30 recovered frames before
  rearming, preventing one sustained slowdown from producing overlapping
  reports every few seconds.
- The focused root-cause suite covers 20 behaviors, including flow coalescing,
  protected crowd behavior, 30 Hz scheduling, exact projectile hit order, and
  bounded nearest-first chunk generation.

## Performance flight recorder

- Added an opt-in developer flight recorder to the Performance Lab.
- Keeps a bounded ten-second rolling history and captures five seconds after an
  automatic or manually marked frame-time incident.
- Automatic capture uses both an absolute frame-time threshold and a moving
  baseline multiplier; adjacent bad frames are grouped into one incident.
- Records frame/process/physics time, FPS, rendering and physics-object counts,
  enemy population and simulation tiers, projectile population, loaded chunks,
  flow state, segment, Threat, Resonance, and recorder overhead.
- Correlates bounded events for enemy spawning, deaths, retirement, elite
  promotion, projectile stress/capacity pressure, flow rebuilds, navigation
  revisions, chunk creation/unloading, progression changes, and boss encounters.
- Writes a versioned JSON incident report plus a CSV frame timeline beneath
  `user://performance_captures/`.
- Performance Lab controls allow recording/automatic capture to be toggled,
  thresholds adjusted, incidents marked manually, and the current session
  cleared. The latest report path is shown as an absolute path.
- A 100,000-sample headless benchmark retained a bounded 600-sample history and
  measured approximately 11.5 microseconds per synthetic sample in the
  validation environment. Runtime overhead remains visible in every capture.
- Incident summaries describe temporal overlap and correlation; they do not
  claim an event caused a slowdown.

## Tooltip

- The entire item-tooltip subtree ignores mouse input.
- Tooltips prefer the right side of the hovered item, flip left near the viewport edge,
  and clamp vertically.
- Tooltip content and styling are unchanged.

## Enemy lifecycle

- Ambient enemies remain distance/stale cullable.
- Splitter descendants can now be distance/stale culled.
- Interior encounter protection is active only while its owner encounter is active.
- Orphaned boss/encounter adds can retire after their encounter ends.
- Summons retain their existing lifetime and summoner ownership.
- Bosses, minibosses, objectives, tutorial actors, and active encounters remain protected.
- Snipers remain protected while winding up, telegraphing, combat-relocating, or within
  their maximum firing/beam range plus a 450-pixel safety margin.
- `EnemyIndex.retire_enemy()` is the idempotent canonical retirement path.

## Far simulation

- Eligible far ambient swarm and splitter actors run movement/collision/index work at a
  staggered interval between 10 and 15 Hz.
- Accumulated motion is scaled so reduced update frequency does not reduce intended travel
  speed.
- Near/mid actors and protected combat actors immediately return to full-frequency work.

## Diagnostics

- Developer Mode includes a `Performance` button.
- The performance panel defaults between the left HUD and right-side tools, can be dragged,
  and switches between a compact summary and scrollable detailed view.
- The overlay reports FPS, process/physics time, draws, rendered objects, nodes, physics
  objects, scene/index enemy counts, population classes, simulation tiers, retirements,
  managed projectiles, actual projectile simulation time, hits, loaded chunks, flow-field
  rebuild reasons, navigation revisions, and invalidation causes.
- Projectile timing now measures elapsed manager execution instead of displaying frame delta.

## Enemy isolation controls

- A session-only debug filter discovers stable `EnemySpec.id` values.
- The detailed performance panel can enable, disable, or isolate one archetype.
- Disabling an archetype immediately retires its existing enemies through
  `EnemyIndex.retire_enemy()` and clears pending ambient reservations.
- Ambient, interior, summoner, splitter, boss, miniboss, and scripted arena creation paths
  consult the same filter.
- Protected bosses, minibosses, tutorial actors, and objective actors remain unless
  `Allow protected filtering` is enabled.
- Production cap mode preserves the table total of 180 and normal per-type caps.
- Custom mode exposes a total cap and per-type caps; zero means unlimited.
- Unlimited mode bypasses total and per-type caps without accelerating the spawn timer.
- `Only` switches to Custom mode and removes the selected archetype's production cap.
- Debug filters and cap overrides are never saved.

## Flow-field navigation

- Equal-cost eight-neighbor BFS remains in use; no Dijkstra or per-enemy pathfinding was
  introduced.
- Rebuild requests now identify `initial`, `player_moved`, or `nav_revision` as their cause.
- Repeated checks while the player and navigation revision are unchanged do not create new
  requests.
- Builds superseded by player movement or a newer world revision stop instead of completing
  stale work.
- Chunk generation, unloading, and manual walkability changes now coalesce into one navigation
  revision per frame while retaining per-cause counters.
- Per-expanded-cell direction and penalty arrays were replaced by constant direction data and
  reusable eight-entry buffers.

Synthetic candidate-order benchmark on Godot 4.7.1, 6,561 expanded cells:

| Implementation | Median |
|---|---:|
| Allocating candidate arrays | 27,078 µs |
| Reused fixed buffers | 15,361 µs |

The fixed-buffer stage was 1.76× faster and avoids the old temporary-array churn. This
benchmark isolates neighbor ordering; the live overlay supplies full rebuild CPU time.

## Verification added

- `SpawnFilterTest.gd`: 29 focused assertions.
- `FlowFieldUnitTest.gd`: 11 focused assertions.
- `PerformanceOverlayUnitTest.gd`: 7 focused assertions.
- `FlowFieldAllocationBenchmark.gd`: allocation-stage comparison.
- `EnemyLifecycleStressTest.tscn`: 12 cycles, 480 enemies, zero retained failures.
- `AuditClosureTest.tscn`: 50 assertions passed.
- `SaveIntegrityTest.tscn`: 29 assertions passed; its intentional corrupt-primary
  recovery fixture still emits the expected parse error before loading the backup.
- Godot 4.7.1 editor initialization completed without project parse errors.

`PerformanceLifecycleTest.tscn` could not complete in a second headless process while the
project remained open in the user's editor; it stalled before test output. Its new overlay
coverage was therefore also run through the standalone `PerformanceOverlayUnitTest.gd`.
The stationary-player live observation remains a manual in-editor check: leave the player
still, open Details, and watch the FLOW reason plus the listed world invalidation causes.

## Projectile benchmark

The reference repository's bulk MultiMesh buffer approach was benchmarked against the
existing per-instance transform/color setters on Godot 4.7.1:

| Projectiles | Existing setters | Bulk buffer | Existing advantage |
|---:|---:|---:|---:|
| 100 | 31 µs | 52 µs | 1.68× |
| 500 | 157 µs | 267 µs | 1.70× |
| 1,000 | 331 µs | 558 µs | 1.69× |
| 4,000 | 1,421 µs | 2,385 µs | 1.68× |

The bulk-buffer path was rejected because constructing its per-frame buffer was consistently
slower in this project's required transform-plus-color format. Projectile simulation and
rendering behavior therefore remain unchanged apart from accurate timing.
## 2026-07-30 — tiled procedural world visuals

- Added `ChunkTileRenderer`, which builds a runtime `TileSet` and bounded
  `TileMapLayer` set for repeated world artwork.
- Procedural walls, windows, half-cover, decals, and vegetation now become tile
  cells. Their collision bodies, projectile blockers, blocked-cell registration,
  and flow-field invalidation remain unchanged.
- Segment 1 uses the same tile renderer for handcrafted walls, fences, and
  cover. Opening progression barriers erase their tile cells and repaint
  neighbouring connection variants.
- The original sprite path remains available through
  `ChunkManager.tiled_world_rendering = false`.
- The developer console now reports tiled cell and layer totals.
- Deterministic representative-chunk comparison: 110 repeated `Sprite2D`
  nodes before, 0 after; 55 collision bodies and 55 blocked navigation cells
  in both modes.
- Follow-up correction: chunk ground, floor stamps, decals, vegetation, and
  landmarks now write directly to tile cells as well. The persistent tile
  layers and runtime `TileSet` sources are owned once by `ChunkManager`;
  streamed chunks only write and erase their global cell ranges. A live
  25-chunk Segment 2 integration run reports roughly 39,000 tile cells across
  7 shared layers, with zero `TileMapLayer` or `Sprite2D` descendants beneath
  streamed chunks.
- Segment 1 map geometry is also sprite-free; only deliberately interactive
  waypoint sigils retain their own animated sprite scene.

## 2026-08-17 - batched procedural chunk streaming

- Procedural blocker generation now records compact cell descriptors and activates at most
  three physics bodies per chunk. Shapes are attached directly through physics shape owners;
  no procedural `CollisionShape2D`, `CoverWall`, or `CoverHalf` nodes are created.
- Blocker visuals are pooled into shared `MultiMeshInstance2D` texture batches. Chunk unloads
  remove owned instance ranges with swap-removal rather than freeing hundreds of scene nodes.
- Procedural ground is one repeating region sprite per chunk. Procedural TileMap expansion is
  disabled, while authored Segment 1 tile diagnostics and rendering remain available.
- Streaming starts explicitly after the procedural plan is installed, uses camera visibility
  bounds, orders work center-first, and enforces a 2 ms / four-activation hard scheduler cap.
- Ground materials are loaded during procedural configuration, outside timed chunk activation.
  This removed a measured 44 ms first-use dirt-texture hitch from the streaming path.
- Flow-field candidate ordering reuses fixed buffers. Its 6,561-cell synthetic benchmark
  improved from a 35,648 us median to 16,494 us (2.16x).
- The performance overlay now reports queue length/age, last and median build time, activation
  budget, blocker cells/bodies/shapes, MultiMesh batches, and authored tile totals.

Godot 4.7.1 deterministic audit, seed 251337, one discarded site warm-up, then radius 2:

| Metric | Before final streaming tune | Final |
|---|---:|---:|
| Loaded chunks | 25 | 25 |
| Median chunk activation | 0.274 ms | 0.175 ms |
| Maximum chunk activation | 78.010 ms | 2.663 ms |
| Static-memory delta after warm baseline | 11,260,132 bytes | 1,257,932 bytes |
| Procedural TileMap cells | about 39,000 (prior 25-chunk integration) | 0 |
| Procedural cover nodes | per-cell scenes | 0 |
| Procedural `CollisionShape2D` nodes | per-cell nodes | 0 |
| Blocker cells / bodies / owned shapes | - | 193 / 14 / 68 |
| MultiMesh instances / batches | - | 193 / 34 |

The final `CHUNK_AUDIT` passed all 12 gates. Its six remaining `CollisionShape2D` nodes are
intentional interactive site volumes, not procedural blocker physics. The audit reports these
separately and does not count them as blocker-node regressions.

## 2026-08-18 - scalable horde simulation foundation

- Added a deterministic enemy simulation scheduler. Protected bosses, objectives, authored
  encounters, and smart archetypes remain full-rate; ordinary ambient enemies use a hard budget
  of 32 full-rate actors, 48 reduced actors, and an uncapped far-proxy population.
- Mid actors retain world collision and remain hittable while running in two rotating tick groups.
  Far actors leave individual physics processing and the physics broadphase, then receive one
  manager-driven movement update every six physics frames.
- Enemy hitboxes now separate active monitoring from monitorability. Ordinary enemies remain
  hittable without every Area2D actively searching; Leech contact detection remains active.
- Flow fields build into an inactive buffer and publish atomically, so enemies keep following the
  last completed field during a replacement build. Under physics pressure, the build budget drops
  from 1.50 ms to 0.50 ms per frame without cancelling the build.
- Ordinary ambient enemy instances are recycled through a fail-closed pool capped at 32 instances
  per scene. HP, motion, control state, navigation caches, DOT children, collision roles, and index
  membership are reset. Elites and special/authored actors are always freed instead.
- The flight recorder's cached slow snapshot now includes scheduler tier/step costs and pool reuse
  counters. Recurring follower-transaction and Conduit ArcBolts logs are disabled unless their
  explicit debug flags are enabled.

Fresh Godot 4.7.1 verification passed 200 focused assertions/audit gates, a 480-enemy lifecycle stress test
with zero failures, and the existing chunk audit. The 180-enemy synthetic simulation benchmark
improved from 379.15 ms to 89.17 ms across 120 frames (4.25x speedup, 0.743 ms per adaptive frame).
These are deterministic test results; the next gameplay capture is required to establish the live
before/after frame-time curve and tune the full/mid budgets for the target 500+ on-screen horde.
