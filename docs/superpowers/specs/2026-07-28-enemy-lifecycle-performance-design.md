# Enemy Lifecycle and Performance Design

## Goal

Prevent gradual FPS degradation during long exploration sessions without reducing the
intended nearby horde density, changing enemy combat behavior, or replacing the existing
projectile simulation.

The patch also fixes the backpack tooltip intercepting item interactions and adds enough
diagnostics to distinguish enemy, projectile, procedural-streaming, physics, and rendering
costs during later testing.

## Confirmed causes

Normal ambient enemies follow a complete retirement path:

1. The spawner selects a distant or stale enemy.
2. The enemy is explicitly removed from `EnemyIndex`.
3. The enemy is queued for deletion.
4. Its exit callback safely attempts unregistering again.

The gradual accumulation risk is instead caused by the current eligibility rules:

- Every enemy with a non-empty `special_spawn_kind` is excluded from culling.
- Interior enemies are additionally marked `never_cull`.
- Splitter descendants are special enemies and have no lifetime.
- Far enemies continue running `CharacterBody2D.move_and_slide()`, collision work,
  distance checks, and spatial-index maintenance every physics frame. Only expensive
  steering decisions are currently throttled.
- The projectile debug display reports frame delta as projectile time rather than measuring
  the projectile manager's actual execution time.

Procedural chunks themselves unload outside the configured radius. Their generation can
cause transition spikes, but the current evidence does not identify chunk retention as the
primary cause of steadily worsening FPS.

## Enemy retirement policy

Enemy protection is determined by gameplay responsibility rather than by one broad
`special_spawn_kind != ""` rule.

### Permanently protected while active

- Bosses and minibosses.
- Objective-owned enemies explicitly marked as required for the active objective.
- Opening/tutorial actors.
- Enemies explicitly marked `never_cull` by a currently active scripted encounter.
- Snipers that are aiming, telegraphing, firing, relocating as part of an attack, or inside
  their configured engagement envelope.

### Distance-cullable

- Ambient enemies.
- Splitter descendants.
- Interior enemies after their associated interior is no longer active.
- Encounter adds after their owning encounter or boss has ended.

### Lifetime-owned

- Summoned enemies retain their existing ten-second lifetime and summoner ownership.
- If their summoner disappears, they retire immediately.

Interior protection must be reversible. Entering or activating an interior may protect its
current encounter, but leaving it must remove that protection. A procedural interior cannot
leave permanently protected enemies behind after its chunk becomes irrelevant.

## Far simulation tiers

Enemies close enough to affect the player continue using full physics frequency.

Eligible distant enemies use staggered simulation:

- Near: normal physics and AI cadence.
- Mid: normal movement with the existing reduced steering cadence.
- Far: movement, collision, and index updates at approximately 10–15 Hz using accumulated
  delta, staggered per enemy.
- Beyond the retention boundary: retire the enemy instead of simulating it.

Bosses, minibosses, elites engaged with the player, active objectives, telegraphing enemies,
and scripted encounters remain full-frequency.

The far tier is allowed only when an enemy cannot immediately attack or collide with the
player. Returning to the near or mid tier restores full-frequency simulation immediately.

Snipers are evaluated using their attack state and configured range rather than the camera
rectangle. Their design intentionally permits attacks from outside the visible screen. An
idle sniper may only become distance-cullable when it is beyond its maximum engagement
range plus a safety margin, has no live telegraph or pending shot, and is not relocating as
part of its combat behavior. Entering any attack state immediately restores full simulation.

## Index and ownership integrity

`EnemyIndex` remains the canonical enemy registry.

- Retirement removes an enemy from the index before queueing deletion.
- Exit-tree unregister remains idempotent.
- Dead enemies release population accounting immediately.
- Maintenance pruning remains a repair mechanism, not the normal lifecycle.
- Debug counters compare indexed enemies with valid enemy nodes in the scene tree.
- A mismatch is reported but does not crash or alter release gameplay.

Special-enemy reservations must be released exactly once. Changing culling eligibility must
not cause ambient, split, summon, interior, or boss-add counters to drift.

## Performance diagnostics

Developer Mode gains an optional lightweight performance overlay containing:

- FPS and frame time.
- Godot process and physics time where available.
- Draw calls and rendered object counts where available.
- Total scene nodes and physics collision objects.
- Scene-tree enemy count.
- `EnemyIndex` total, ambient, and special counts.
- Counts by special kind.
- Near, mid, and far enemy simulation tiers.
- Total enemies retired by distance, stale cleanup, owner cleanup, and lifetime.
- Active managed projectiles, hits, batches, and dropped projectiles.
- Actual measured projectile simulation time.
- Loaded procedural chunk count.

Counters update at a low frequency and must not perform expensive scene-tree scans every
frame. Full consistency scans are limited to the diagnostics refresh interval or an explicit
developer action.

## Projectile scope

The existing `ProjectileSimulationManager` remains authoritative for ordinary straight
player and enemy projectiles. It already implements the important architecture from the
reference repository: lightweight projectile data and one MultiMesh renderer.

This patch may:

- Replace per-instance MultiMesh transform/color setter calls with a compatible bulk-buffer
  upload after an isolated benchmark proves it is faster.
- Correct the manager's timing measurement.
- Route ordinary boss bullets through the manager when they have identical behavior.

This patch must not:

- Replace custom mines, beams, telegraphs, homing attacks, or other exotic attacks.
- Remove piercing, burn, critical hits, knockback, world collision, or damage batching.
- Adopt the reference repository's per-bullet physics point query.

If the bulk-buffer benchmark does not show a meaningful improvement, the existing renderer
is retained.

## Tooltip interaction and placement

The complete `ItemTooltip` control subtree is mouse-transparent. Showing a tooltip must
never prevent clicking, right-clicking, dragging, equipping, locking, or discarding the
underlying backpack slot.

The tooltip is positioned relative to the hovered slot, following the usual RPG pattern:

- Prefer the outside/right side of the hovered slot with a small gap.
- If that side would leave the viewport, place it to the left.
- Clamp vertically to the viewport.
- Never overlap the hovered slot unless the viewport is physically too narrow to fit the
  tooltip on either side.
- Continue following the current hovered item when its contents change.

The tooltip's visual styling and content remain unchanged.

## Testing

Automated tests cover:

- Tooltip descendants all use `MOUSE_FILTER_IGNORE`, and placement avoids the source slot
  while respecting viewport edges.
- Ambient, split, expired-interior, and orphaned encounter-add enemies are cullable.
- Active bosses, objectives, tutorial actors, and active encounter enemies are protected.
- Engaged or telegraphing offscreen snipers remain protected and full-frequency.
- Idle snipers outside their configured engagement envelope can eventually retire.
- Summons retain lifetime/owner cleanup.
- Retirement unregisters exactly once and leaves no index or population-count drift.
- Far-tier scheduling is staggered and restores immediate full simulation when approaching.
- The performance overlay reads counters without mutating gameplay state.
- Projectile timing measures elapsed execution time rather than frame delta.
- Existing equipment, save-integrity, procedural-generation, and audit tests remain green.

A runtime stress scenario compares:

- Stable standing combat.
- Long-distance exploration across repeated chunk loads/unloads.
- Maximum ambient population.
- Splitter and summoner-heavy populations.
- High managed-projectile count.

The comparison records frame time, physics time, live/indexed enemies, nodes, collision
objects, projectiles, and loaded chunks over time. Success means retired enemies and index
counts remain bounded and FPS does not degrade merely because previously visited areas
contained enemies.

## Compatibility and scope

- Developer Mode remains available.
- Save data is unchanged.
- Enemy combat values, rewards, drop chances, and nearby spawn pressure are unchanged.
- The existing maximum population remains a safety cap, not the primary performance fix.
- No large enemy ECS rewrite is included.
- No procedural-generation redesign is included unless measurements demonstrate retained
  chunks or generation caches after the enemy lifecycle changes.
