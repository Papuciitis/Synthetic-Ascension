# Authoritative Enemy World Design

## Goal

Replace the current Node-per-enemy runtime with a data-authoritative enemy
world that can sustain at least 500 concurrent enemies at 60 FPS on the
current development machine. Nearby enemies retain authored Godot scenes,
physics, animation, and complete brains. Every other enemy remains visible,
targetable, damageable, and killable as a lightweight data record.

This design supersedes the scaling assumptions in the 2026-08-18 enemy
simulation budget design. That design targeted roughly 180-220 enemies and
explicitly deferred a data-oriented rewrite. The project now requires 500+
enemies, so optimizing the old ownership model further would only postpone the
same migration.

## Success criteria

The implementation is complete only when all of the following are true:

- a controlled gameplay stress run maintains 500 concurrent logical enemies;
- the target run holds 60 FPS without recurring enemy-caused frame spikes, as
  measured by a fresh performance-recorder capture rather than inferred from
  unit tests;
- no more than the configured materialized-actor budget exists, initially 64
  with a tunable ceiling of 96;
- the old 180-enemy gameplay cap is replaced by a configurable safety limit of
  at least 600, without embedding 500 as a new architectural ceiling;
- data-only enemies remain visible and can be hit and killed by any attack that
  genuinely reaches them;
- bosses, objectives, and scripted encounter-critical actors remain fully
  materialized, while ordinary elites and smart archetypes may use data-only
  simulation when distant;
- health, status effects, cooldowns, elite state, ownership, and brain state
  survive repeated materialization and dematerialization;
- every logical enemy produces at most one death, reward, drop sequence, and
  population-accounting release;
- stale handles, freed pooled Nodes, and delayed projectiles fail safely;
- all automated suites, the editor parse gate, lifecycle stress tests, and a
  real-renderer projectile test pass without new warnings or script errors.

The runtime capture is the authority for the performance claim. A headless
benchmark can reject a regression but cannot prove stable gameplay frame time.

## Architecture

### One authoritative world

`EnemyWorld` owns the complete runtime state of every logical enemy. A Godot
enemy Node is no longer an enemy's identity or source of truth; it is a leased
physical representation bound to an enemy handle while the enemy is close or
otherwise requires full behavior.

The main data flow is:

1. The spawner creates a logical record in `EnemyWorld`.
2. `EnemyRepresentationManager` assigns a pooled Node when priority and the
   materialization budget allow it.
3. The Node performs full physics, animation, and near-combat behavior against
   the authoritative record.
4. When the Node is no longer required, its runtime state is committed to the
   record, the binding is removed, and the Node returns to its pool.
5. `EnemyProxySimulation` continues the same enemy using inexpensive movement
   and activity-brain updates.
6. All incoming combat resolves through the handle and mutates `EnemyWorld`,
   regardless of representation.
7. A single death pipeline removes the record and emits rewards exactly once.

`EnemyIndex` becomes a compatibility facade for materialized Nodes during the
migration. It is no longer the canonical population or combat registry. New
combat and targeting code queries the handle-based spatial index in
`EnemyWorld`; old Node-returning APIs remain only until their callers are
migrated.

### Stable handles and storage

An enemy handle is a 64-bit integer composed of a storage-slot index and a
generation. Reusing a slot increments its generation. A delayed damage command
containing an old generation therefore cannot hit the new occupant of that
slot.

Hot fields use typed or packed arrays indexed by stable slot:

- active flag and generation;
- archetype/specification identifier;
- current and previous position;
- velocity and facing;
- current and maximum health;
- movement speed and collision radius;
- representation, activity-brain, and death state;
- elite and gameplay flags;
- attack, decision, lifetime, and status timers;
- knockback and other short-lived movement state.

Cold or uncommon state is stored separately by slot:

- smart-brain phase and remembered target data;
- spawn owner and special-spawn kind;
- splitter, summoner, encounter, and objective metadata;
- drop entitlement and death-processing flags;
- status-effect details that do not belong in the hot update loop.

A dense active-slot list supports iteration, while a free-slot list supports
bounded reuse. Removing an enemy never changes another enemy's handle.
`EnemyWorld` owns a handle-based spatial grid that is incrementally updated as
positions move. No second proxy grid is introduced.

### Materialization policy

The materialization budget is a hard performance resource. The initial default
is 64 actors and may be tuned up to 96 only after recorder evidence supports
it. Priority is determined by:

1. boss, objective, tutorial, or scripted-critical responsibility;
2. immediate contact or attack relevance;
3. distance to the player and visibility;
4. elite or smart-archetype importance;
5. current representation, providing hysteresis.

The budget reserves capacity for critical and attack-ready actors. Reserved
capacity may be borrowed by ambient enemies when unused, but critical actors
can reclaim it. Additional scripted-critical spawns that would violate the
hard ceiling are delayed and diagnosed rather than silently making the physics
load unbounded.

Activation and deactivation use separate configurable distances. Actor churn
is also bounded per frame. Critical promotions may bypass the normal per-frame
conversion allowance but never the total actor ceiling. Node pooling handles
only representations; acquiring or releasing a Node must not change logical
population counts or emit spawn/death telemetry.

If materialization fails, the enemy remains a valid data-only record and the
failure is reported through a rate-limited diagnostic. If a bound Node is freed
externally, the binding is cleared safely and the logical enemy returns to
data-only representation unless a logical death or retirement was already in
progress.

### Nearby actors

A materialized `EnemyActor` is an adapter around its handle. On binding it
loads position, velocity, appearance, health presentation, statuses, brain
state, and cooldowns from `EnemyWorld`. It then enables only the collision and
monitoring roles required by its archetype.

During full simulation the Node owns transient Godot physics values for the
current step, but commits canonical gameplay fields through `EnemyWorld`.
Damage, healing, statuses, death, drops, and identity never become Node-owned.
On unbinding, the actor commits movement and complete-brain state before all
processing, collision, monitoring, timers, signals, and visuals are disabled.

The existing enemy scenes remain the authoring format for appearances and full
brains. The migration does not require designers to author enemies in a new
editor or discard current animation and encounter work.

### Data-only simulation and activity brains

Data-only enemies update in rotating groups at a configurable low frequency,
initially 10 Hz. Rendering interpolates between previous and current positions
so movement remains visually smooth at the display frame rate.

Ordinary movement uses the shared flow field plus inexpensive grid-based local
separation. It does not call `CharacterBody2D.move_and_slide()`, create physics
objects, run per-enemy scene callbacks, or query the scene tree. Flow-field
movement keeps enemies out of blocked navigation cells; local separation keeps
large proxy groups from collapsing into one point.

Elites and smart archetypes have two brain layers:

- an activity brain for travel, coarse positioning, cooldown progression, and
  choosing whether full interaction is needed;
- the existing complete brain after materialization.

Complex attacks, telegraphs, summoning actions, and physics-dependent behavior
begin only after materialization. An enemy approaching attack readiness gains
materialization priority. Brain phase, cooldowns, and deterministic random
state remain in the record, so switching representation does not reset or
reroll behavior.

Bosses, active objectives, and explicitly scripted-critical actors stay
materialized. Ordinary elites, snipers, leeches, tactical enemies, bombers,
chargers, splitters, and other ambient smart archetypes are eligible for the
two-brain path once their individual migration tests pass.

### Batched proxy rendering

`EnemyProxyRenderer` owns one `MultiMeshInstance2D` batch per compatible visual
key, such as texture/material/atlas combination. It renders data-only records
only; a materialized actor uses its normal scene visuals. Proxy instances use
interpolated transforms and may use a simplified distant animation frame or
atlas sequence, but their archetype and elite appearance must remain
recognizable.

Instance buffers are uploaded in bulk and explicitly notify Godot after raw
buffer changes. Batch-slot reuse has its own generation-safe bookkeeping so a
removed enemy cannot leave a visible ghost or cause another proxy to inherit
its transform or color.

Rendering is independent from logical simulation. Hiding or failing to render
a proxy never removes it from combat, and releasing a render slot never kills
the logical enemy.

## Combat and gameplay services

### Unified queries and damage

`EnemyCombatService` exposes handle-based nearest, radius, segment, swept
projectile, and target-validation queries backed by the world spatial grid.
Player projectiles, melee attacks, spells, area effects, DOT, knockback, and
target-selection systems migrate to these APIs before data-only representation
is enabled for enemies they must affect.

The centralized projectile manager already performs analytic movement and is
the first combat caller to migrate. A hit carries a handle and generation, not
a Node reference. Legacy Area2D attacks can continue detecting materialized
hitboxes temporarily; each hitbox exposes its bound handle and immediately
forwards damage to the same combat service.

Damage mutates health immediately after validating the handle. Re-entrant
lifecycle consequences are queued until the current combat operation ends.
The first transition to zero health marks the record as dying; later damage is
ignored. This preserves immediate hit semantics while preventing collection
mutation and duplicate death effects during projectile or area-query loops.

Data-only enemies remain fully damageable. A long-range projectile, spell, or
area effect that genuinely reaches a proxy can kill it without forcing a Node
allocation.

### Status, knockback, and time

Status timers and damage scheduling live in data services. Materialized actors
display and react to those values but do not own them. DOT uses central due-time
queues rather than one timer per enemy. Knockback adds world velocity while
data-only and drives the actor adapter while materialized.

Paused gameplay, time scaling, and accumulated low-frequency delta must follow
the same rules in both representations. A transition resets visual
interpolation but does not discard elapsed gameplay time.

### Death, rewards, and special lifecycles

`EnemyDeathService` is the only logical-death entry point. It atomically marks
the death as processed, releases population and reservation accounting, emits
kill telemetry, grants XP, rolls drops, and schedules special consequences.
It then removes the handle after current readers finish.

Representation cleanup is a consequence of logical death, never the death
authority. Returning a Node to the pool cannot grant rewards. Distance or
owner retirement removes a record through a distinct non-rewarding path.

Special cases preserve existing gameplay:

- a data-only splitter killed by a valid attack creates child records;
- summoned enemies preserve owner and lifetime cleanup without requiring a
  Node;
- an orphaned encounter add can retire without granting a kill;
- drop ownership and eligibility survive representation changes;
- a materialized death can play its authored animation while the record is
  already protected against duplicate rewards.

## Migration strategy

The rewrite ships as tested vertical slices rather than a flag-day replacement.
Each phase leaves the game runnable and has a rollback flag until its runtime
gate passes.

1. **World foundation:** add handles, storage, spatial queries, lifecycle
   invariants, and recorder counters. Existing Nodes shadow their state into
   records without changing behavior.
2. **Authoritative lifecycle:** move logical spawn, identity, population,
   damage, death, retirement, rewards, and pooled-representation ownership to
   world services while every enemy is still materialized.
3. **Combat migration:** move managed projectiles, targeting, melee, spells,
   AOE, DOT, and knockback to handle-based queries. Keep compatibility hitboxes
   for materialized legacy attacks.
4. **Proxy vertical slice:** enable data-only movement, batched rendering, and
   Node transitions for the simplest ambient chase archetype.
5. **Archetype expansion:** migrate ranged, bomber, charge, tactical, sniper,
   leech, splitter, summoned, and elite variations one at a time. Each gains an
   explicit activity-brain contract and round-trip tests.
6. **Budget enforcement:** enable the hard representation budget, remove the
   old scheduler exemptions that add protected or smart actors above budget,
   and turn `EnemyIndex` into a compatibility-only facade.
7. **Scale validation:** raise the safety population limit in measured steps,
   verify 180, 300, 500, and at least 600 logical enemies, then make the new
   system the default and remove dead dual-path code.

An archetype is not proxy-eligible until every player attack that can reach it
uses a proxy-aware combat path and its state round-trip is covered. This avoids
invisible or invulnerable enemies during the migration.

## Diagnostics and failure handling

The performance recorder adds low-cost counters for:

- logical, materialized, and data-only enemy counts;
- materialization requests, successes, failures, evictions, and churn;
- actor-budget occupancy and reserved occupancy;
- proxy simulation, spatial-query, combat-command, and batch-upload time;
- active spatial cells and maximum cell occupancy;
- stale-handle rejections and duplicate-death attempts;
- flow build state and the actual `last_revision` key;
- per-archetype logical and materialized counts.

Recurring diagnostics are rate limited and never print from hot loops in normal
gameplay. Debug assertions verify binding consistency, but release paths fail
closed: invalid handles are ignored, invalid pooled variants are discarded,
and a missing render or Node representation cannot invalidate logical state.

The current flight-recorder captures showed that recorder overhead is small
and not the main frame-time cause. Recorder work remains measured so future
captures can detect a regression.

## Testing strategy

Every production behavior is introduced test-first. Focused tests cover:

- slot allocation, generation reuse, stale-handle rejection, and iteration;
- incremental spatial-grid updates and all required query shapes;
- spawn, retirement, death, reward, and population accounting exactly once;
- 500- and 600-record deterministic world simulation;
- materialization priority, hard budget, reserves, hysteresis, and bounded
  conversion work;
- forced Node deletion and pool reuse without freed-object casts;
- complete Node-to-record-to-Node state round trips;
- managed projectile, piercing, melee, spell, AOE, DOT, and knockback hits on
  both materialized and data-only targets;
- proxy death, drops, splitter children, summons, and owner cleanup;
- activity-to-complete-brain transitions for every eligible smart archetype;
- proxy batch-slot reuse, bulk-buffer publication, and visibility;
- recorder schema and counters, including flow revision;
- deterministic pause and time-scale behavior.

Integration gates include the existing 480-enemy lifecycle stress test, a new
600-record representation-cap stress test, the full scene-based suite, the
editor parser scan, and real-renderer projectile/proxy checks. Tests must have
zero failures, script errors, freed-object casts, and newly introduced parser
warnings.

Runtime validation uses comparable recorder sessions at 180, 300, 500, and
600 enemies. Reports include average, p95, and worst frame/physics times,
materialized counts, proxy costs, draw calls, flow work, and conversion churn.
The population cap is raised in release defaults only after the 500-enemy run
meets the 60 FPS target.

## Scope and compatibility

This work changes enemy runtime ownership and representation, not combat
balance. It does not intentionally change damage, health, movement speed,
drop probability, spawn composition, encounter scripting, or procedural chunk
generation. Distant animation may be simplified, but nearby authored visuals
and behaviors remain intact.

No C++ GDExtension, GPU compute simulation, or new worker thread is required
for the first implementation. A single-threaded data core is easier to verify
and should be sufficient for 500-600 enemies. The service boundaries permit a
future worker snapshot or native backend without changing combat callers or
enemy handles if measurements later justify it.

Active uncommitted pool-safety, projectile-buffer publication, warning cleanup,
and their regression tests are preserved. They are prerequisites or diagnostics
for this migration and must not be overwritten.

