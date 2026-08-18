# Enemy Simulation Budget Design

## Goal

Keep large ambient hordes responsive without allowing the number of nearby
`CharacterBody2D` actors to determine frame time. Preserve combat, navigation,
boss, objective, leech, projectile, and retirement behavior while making full
physics simulation a bounded resource.

## Evidence and success criteria

The 2026-08-18 recorder run remained near baseline at small populations, rose
to roughly 29 ms per frame around 118 enemies and 48 near-tier actors, and
reached 100-145 ms with 153-180 enemies and 84-140 near-tier actors. Slow
frames occurred with both low and high draw-call counts. All late-run enemies
were ordinary ambient actors. Flow construction was continuously active but
already limited to 1.5 ms per frame.

The implementation succeeds when a repeated run:

- never assigns more ordinary ambient actors to full simulation than the
  configured budget;
- keeps protected actors at full simulation regardless of ambient pressure;
- removes far ambient actors from the 2D physics space;
- preserves projectile hits and leech contact behavior in every eligible tier;
- exposes enough recorder data to compare assigned tiers, scheduled work,
  physics membership, flow work, and pool activity;
- passes all existing lifecycle, projectile, navigation, chunk, recorder, and
  integration tests without new parser warnings.

Performance improvement must be established by a new recorder run rather than
claimed from unit tests alone.

## Architecture

### Enemy simulation scheduler

A single `EnemySimulationScheduler` autoload owns ambient tier assignment and
reduced-rate scheduling. `EnemyIndex` remains the canonical registry and
spatial hash; the scheduler consumes its registry instead of creating a second
enemy collection or spatial structure.

The scheduler recomputes assignments at a configurable interval, initially
0.20 seconds. It ranks ordinary ambient actors using protected status, combat
commitment, on-screen relevance, distance, and their previous assignment.
Hysteresis prevents actors near a boundary from changing tier every refresh.

Default ordinary-ambient budgets are:

- full: 32 actors;
- mid: 48 additional actors;
- far: all remaining actors up to the existing population cap.

These defaults are deliberately conservative and exported for recorder-driven
tuning. Protected actors do not consume the ordinary budgets. Protected means
bosses, minibosses, elites, objectives, tutorial actors, active authored
encounters, never-cull actors, and combat-committed snipers.

Full actors retain their normal `_physics_process` callback. Mid and far actors
disable their individual physics callback. The scheduler processes mid actors
through two rotating groups and far actors through six rotating groups,
passing accumulated fixed-step delta to the enemy simulation method. Tier-list
rebuilds occur only at the assignment interval, not every frame.

### Enemy simulation API

`EnemyActor` separates its current `_physics_process` body into a callable
simulation step. The ordinary full callback forwards to that step. Scheduler
calls use the same gameplay code with an explicit tier and accumulated delta.

Enemy tier changes are applied through one method that synchronizes callback
state, collision state, hitbox state, interpolation reset, and cached steering.
Tests can call the deterministic assignment and transition helpers without a
running game.

### Physics membership

Full actors retain body collision and use `move_and_slide()` at 60 Hz.

Mid actors retain simplified world collision but run it only in their 30 Hz
group. They remain available to projectiles. Mid actors do not perform
unnecessary active Area2D monitoring unless their archetype requires contact
detection.

Far actors disable the body `CollisionShape2D`, disable both hitbox monitoring
and monitorability, and move logically using cached shared-flow steering at
10 Hz. Their position continues to update in `EnemyIndex`. On promotion, body
collision and the required hitbox roles are restored before full or mid work.
Promotion resets physics interpolation so the visual does not smear from its
last proxy transform.

### Hitbox roles

Hitbox detection is split into two independent capabilities:

- `monitorable`: another Area2D, such as a projectile, may detect this enemy;
- `monitoring`: this enemy actively detects other areas.

Ordinary non-leech enemies never actively monitor. Full and mid ordinary
enemies remain monitorable; far enemies are neither. Leech enemies monitor the
player hurtbox only while in full or mid simulation. This preserves the current
leech signals without paying active monitoring cost for every enemy.

The centralized projectile manager continues to use `EnemyIndex` as its
authoritative broad phase. Existing Area2D projectiles retain compatibility
with full and mid hitboxes.

### Flow-field load shedding

The existing flow implementation and completed field remain authoritative.
No per-enemy pathfinding is introduced. Rebuild requests continue to coalesce.

When the scheduler reports that its measured physics step exceeded its target,
an active flow build keeps its state but uses a smaller expansion time budget
for that frame. The initial reduced budget is 0.50 ms; the normal budget remains
1.50 ms. Navigation-revision requests are debounced so repeated chunk changes
within one short window produce the latest pending request rather than a chain
of redundant builds. The last completed field remains readable throughout.

### Bounded ambient pooling

Only ordinary ambient enemies spawned by the regular spawner are pooled.
Bosses, authored encounters, summons, split children, tutorial actors, and
objective actors keep their existing lifecycle.

The pool is bounded per scene path, with a default maximum of 32 inactive nodes
per common ambient scene. Release unregisters the actor from `EnemyIndex` and
the scheduler, disables processing, collision, monitoring, rendering, and
transient timers, then detaches it under the pool owner. Acquisition restores
the scene-owned specification and performs one explicit spawn reset before the
node becomes visible or collidable. A node that cannot satisfy the reset
contract is freed instead of pooled. This fail-closed rule prevents stale
health, module timers, metadata, drops, or combat state from leaking between
spawns.

Pooling addresses allocation and spawn/death spikes; it is not used as a
substitute for the simulation budget.

### Diagnostics

The scheduler exposes counters for full, mid, far, protected, scheduled mid
steps, scheduled far steps, physics-enabled enemies, and assignment refresh
cost. The pool exposes acquisitions, reuse hits, releases, misses, and current
inactive count. The flight recorder samples these counters alongside existing
enemy tiers and flow state.

Developer logging inside recurring combat transactions is gated behind an
explicit debug flag so console output does not distort performance runs.

## Alternatives rejected

### Distance-only LOD

The existing system uses this approach and permits 84-140 enemies to become
full actors when the horde collapses around the player. It cannot guarantee a
frame-time ceiling.

### Full ECS, C++ GDExtension, or GPU simulation

These approaches are appropriate for thousands of agents. The current target
is roughly 180-220 enemies, and the profiler points to unbounded full physics,
not a requirement for tens of thousands of data-oriented entities. They remain
future options only if the bounded Godot implementation cannot meet the target.

### MultiMesh enemy rendering

Draw-call counts did not correlate with the recorded stalls, and normal frame
times returned while higher draw-call counts remained. Rendering changes are
deferred until a future capture identifies rendering as the limiting stage.

### A second spatial grid

`EnemyIndex` already provides the required spatial hash for separation,
projectiles, area effects, and targeting. A duplicate grid would add rebuild
and synchronization cost without solving the measured problem.

## Testing strategy

Tests are written before each production change and must fail for the missing
behavior. Focused tests cover:

- deterministic hard budgets and protected-actor exemptions;
- hysteresis and stable ranking;
- mid/far rotating tick groups and accumulated delta;
- physics-shape and hitbox-role transitions;
- projectile compatibility and leech monitoring;
- flow budget load shedding without cancelling an active build;
- pool reset, bounded capacity, unsupported-actor fallback, and registry
  consistency;
- recorder schema and counters.

After focused tests pass, run the full existing headless suite, parser scan, and
performance benchmarks. The final runtime check is a fresh developer run using
the automatic recorder, compared against the 2026-08-18 capture bins.

## Scope protection

The implementation does not change enemy population balance, damage values,
drop probabilities, procedural generation, projectile damage ordering, or the
visual design of enemies. Existing uncommitted developer-segment and warning
cleanup changes are user work and must remain untouched.
