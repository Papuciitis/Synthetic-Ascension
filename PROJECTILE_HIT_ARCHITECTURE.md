# Projectile and Hit Architecture

## Migration boundary

Migrated in 0.21:

- Ordinary player ranged shots formerly instantiated from `RangedBullet.tscn`.
- Ordinary `EnemyProjectile.tscn` shots fired through `EnemyShooter` (currently Spitter/Herald paths).

Deliberately not migrated:

- Melee slashes and magic impacts.
- Homing/magic missiles.
- Reflected or chain projectiles.
- Mines, damage circles and beams.
- Boss Arcanist/Pylon projectile ownership and other signature boss attacks.
- Set/augment effect projectiles that still have unique movement or trigger semantics.

The old scenes remain as compatibility/fallback implementations.

## Simulation and visuals

`ProjectileSimulationManager` keeps a dense active range across parallel packed arrays: current/previous position, velocity, life/range, radius, team, damage, visual family and resolved hit properties. Removal swaps the last active entry into the removed index. Capacity defaults to 4096; overflow increments a rejected counter rather than allocating beyond the configured bound.

Movement is swept from previous to new position. Player bullets query nearby candidates through `EnemyCombat`'s data-side segment queries (2026-08-30: this doc predates the EnemyWorld/EnemyCombat split and originally said `EnemyIndex`), select the earliest segment-circle hit and compare it with the first intentional blocker-shape hit reported by `ChunkManager`. Enemy bullets sweep against the player and the same world geometry. Lifetime/range and piercing are manager-owned.

One `MultiMeshInstance2D` renders simple stretched quads with per-instance color/transform. It is never collision authority. Exotic projectile scenes retain their own visuals and collision.

## Hit ledger rules

One `HitLedger` is created per struck target per physics frame, not per projectile. It receives already-resolved hits.

| Mechanic | Aggregation rule |
|---|---|
| Damage | Sum raw resolved damage; target damage-taken multiplier applies once to the sum |
| Boss hit cap | Per-hit cap multiplied by ledger `hit_count`, preserving the result of separate capped hits |
| Critical hits | Critical outcome is resolved before insertion; total damage and `critical_hits` preserve the resolved results |
| Chance on-hit | Must be rolled before insertion and recorded as a resolved outcome; the ledger never rerolls |
| Lifesteal | `RunEvents.damage_dealt` emits once with final batch damage, preserving total healing while removing repeated signal chains |
| Knockback | Vector sum, clamped to 900 before one application |
| Firestone Burn | Same as legacy `BurnDot`: max stacks, refreshed/max duration, fastest tick, maximum per-stack tick damage; pellets do not silently multiply stacks |
| Piercing | Projectile decrements remaining pierce after a hit and remembers the last target to prevent consecutive re-hits |
| Chain/reflection | Not aggregated or migrated; existing node implementations retain their trigger semantics |
| Once-per-attack effects | Resolve before pellet spawning (for example, Hex Mark already modifies attack damage before shotgun distribution) |

`Enemy.apply_hit_ledger()` is the new explicit entry point. `take_damage()` remains a compatibility wrapper for old projectiles, DoTs, melee, magic and boss mechanics.

## Item compatibility

The Player owns one reusable `HitProfileAdapter`. `ItemEffectRunner` applies managed-profile hooks synchronously, then the projectile manager copies scalar values. Firestone uses `apply_to_hit_profile()` and retains its warm color and Burn payload. Melee and magic Firestone paths are unchanged.

Any future item that previously expects a bullet Node must add an explicit managed-profile hook before its projectile path is migrated. Silent fallback that loses an effect is not acceptable.

## Developer stress test

Enable **Projectile Stress Test + Counters** in the developer console (`ui/widgets/PerformanceOverlay.gd`, Performance tab — not the Main Menu; corrected 2026-08-30). It requests:

- 100 projectiles in one frame;
- sustained additions up to roughly 550 simultaneous logical projectiles;
- five visual colors;
- collisions against the live world/enemy index;
- counters for logical/visual count, hits, hit batches, capacity, rejected shots and physics-step milliseconds.

This is a test harness. Record actual frame time and profiler data in Godot 4.7 before adjusting capacity or claiming a performance result.

## 0.22 world-collision addendum

Migration ownership is unchanged: ordinary straight shots remain managed and exotic shots retain their node movement/target semantics. World collision is now consistent across both sides of that boundary. `RangedBullet`, `EnemyProjectile`, `MagicMissileProjectile` and `ReflectedProjectile` ask `ChunkManager.projectile_hit_t()` for the same swept blocker result as managed bullets.

The broad phase is a grid DDA over crossed cells with a one-cell neighborhood for projectile radius. The narrow phase expands intentionally simple connected-wall/fence rectangles or the half-cover circle by the projectile radius and returns the earliest swept hit. Windows return no projectile hit. Manual/unknown blocked cells conservatively use a full 64 px cell. No projectile Area node or alpha-polygon physics query is introduced by this path.
