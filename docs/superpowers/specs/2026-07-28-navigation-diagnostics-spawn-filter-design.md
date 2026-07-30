# Navigation Diagnostics and Spawn Filtering Design

## Goal

Make performance testing readable and repeatable, determine exactly why the
flow field rebuilds, reduce rebuild overhead without changing path semantics,
and allow individual enemy archetypes to be isolated during live tests.

## Navigation

The existing equal-cost eight-neighbor BFS remains the pathfinding algorithm.
Diagonal corner cutting remains forbidden. This patch does not introduce
Dijkstra, NavigationAgent2D, or per-enemy path searches.

`FlowFieldNav` will expose diagnostics for:

- total and recent rebuild count;
- rebuild reason: player movement, navigation revision, or initial build;
- rebuild start and completion revision;
- whether the player moved since the prior rebuild;
- expanded-cell count and elapsed CPU time;
- stale builds superseded by a newer navigation revision;
- current pending/building state.

The player-moving condition remains a two-cell threshold. A stationary player
must not trigger a rebuild unless walkability changed. The diagnostics must make
any such walkability revision visible rather than assuming it is legitimate.

The BFS hot path will use constant direction data and reusable fixed buffers.
It will not allocate new step or candidate arrays for every expanded cell.
Open-cell preference remains a deterministic equal-cost tie-break and will not
be described as a weighted path cost.

Chunk generation and unloading may mutate walkability many times in one frame.
Those changes will be collected and committed as one navigation revision at the
end of the frame. A build made stale by a newer revision will stop instead of
finishing obsolete work and then rebuilding again.

## Performance Overlay

The overlay will become a compact developer window that does not cover the
inventory HUD or the right-side developer tools at the default 1920x1080
layout. It will:

- default to the lower-left safe area beneath the normal HUD;
- support dragging by its header;
- provide compact and detailed modes;
- remain mouse-interactive only inside its own panel;
- show frame, physics, rendering, enemy, projectile, chunk, flow rebuild, and
  spawn-filter information in grouped sections;
- avoid printing raw dictionaries across wide lines;
- retain its selected mode and position for the current session.

The compact view prioritizes FPS, frame/physics time, enemies by simulation
tier, projectiles, and latest flow rebuild reason. The detailed view adds
special-enemy counts, retirement reasons, loaded chunks, draw information,
per-archetype spawn counts, and complete flow diagnostics.

## Enemy Spawn Filters

A central runtime debug filter will use stable `EnemySpec.id` values. Every
enemy creation route must consult it at the canonical spawn boundary, including:

- ambient spawns;
- indoor encounters;
- scripted spawns;
- summoner-created enemies;
- splitter descendants;
- boss adds.

The developer panel will provide:

- master spawning enabled/disabled;
- one toggle per discovered enemy archetype;
- Enable all;
- Disable all;
- Only this type;
- a spawn-cap mode selector: Production, Custom, or Unlimited;
- editable Custom total-alive and per-type caps, where zero means unlimited;
- protected encounter actor filtering as a separate explicit toggle;
- current live count and spawn count per archetype.

Production mode preserves the spawn table's normal per-type caps and the
spawner's current total cap. Custom mode replaces both with the values shown in
the developer panel. Unlimited mode bypasses both total and per-type caps while
leaving spawn cadence and batch size unchanged.

Choosing Only this type enables that archetype, disables every other ordinary
archetype, switches to Custom cap mode, sets that type's cap to unlimited, and
keeps the current editable total cap. The tester can set the Custom total cap to
zero for a completely uncapped stress test or to a number such as 180 for a
controlled single-archetype comparison. The panel always displays the effective
total and selected-type caps so production limits cannot silently invalidate a
test.

Changing a filter immediately retires all existing enemies whose archetype is
now disabled. It also releases their pending spawn reservations so subsequent
measurements begin from a clean state. Retirement uses the canonical
`EnemyIndex.retire_enemy()` path with a `debug_spawn_filter` reason.

Bosses, minibosses, tutorial actors, and objective-required enemies are not
retired by ordinary archetype changes. The tester must first enable the
separate protected-actor filtering toggle. Summons, splitters, inactive
interior enemies, and ordinary scripted enemies receive no such exemption.

Changing filters does not modify save data and resets when the game process
restarts.

Debug cap overrides also remain session-only. They do not edit
`SpawnTable_Default.tres`, production balance, or save data.

## Verification

Automated tests will establish:

- a stationary player does not request movement rebuilds;
- several walkability changes in one frame create one revision;
- a superseded flow build is abandoned;
- BFS output and diagonal corner rules remain unchanged;
- disabled archetypes cannot enter through any spawn route;
- Production, Custom, and Unlimited cap modes apply their documented limits;
- Only this type bypasses that archetype's production cap;
- changing filters retires matching live enemies and releases reservations;
- protected actors survive unless protected filtering is explicitly enabled;
- overlay compact/detail formatting remains bounded and includes flow reasons.

Godot parsing, the focused test scenes, the existing audit closure tests, and a
live stationary-player diagnostic check will be run before completion.

## Scope

This patch does not rebalance enemy behavior, increase the flow-field radius,
add weighted paths, redesign procedural layouts, or change production spawn
probabilities when debug filters are inactive.
