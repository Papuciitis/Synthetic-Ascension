# Audit Closure Design

## Goal

Resolve the remaining confirmed audit defects in loot, item progression, economy feedback, run records, procedural generation, pacing, and release packaging while preserving Developer Mode for ongoing testing.

## Scope and Ordering

Work is divided into five independently verifiable waves:

1. Loot integrity.
2. Item progression, comparison, and pricing.
3. Run records and production log noise.
4. Procedural reliability and resonance pacing.
5. Reproducible Windows packaging.

Each wave receives focused regression coverage and a Godot headless parse check before the next wave begins. The complete project receives a final smoke check after all waves.

Developer Mode and `DevSetCollisionTools` are explicitly out of scope and must remain functional.

## Wave 1: Loot Integrity

### Unified Enemy Drops

Every enemy item entitlement will create one or more complete `ItemInstance` objects before spawning pickups. The legacy stack-pickup branch will be removed from enemy drops.

Rarity calculation will always include:

- The configured inclusive `drop_rarity_min` to `drop_rarity_max` range.
- `EnemySpec.elite_rarity_bonus` for elite enemies.
- `ThreatDirector.loot_rarity_bonus`.

Configured amount ranges will still control how many independently rolled instances are spawned. Existing polarity overrides and item percentage ranges remain authoritative.

Existing enemy scenes or specs that explicitly opt into the legacy branch will be migrated to instance rolls. Splitter entitlement behavior remains unchanged: one original entitlement produces the configured number of item instances, and descendants do not gain additional entitlements.

### Development Item Filtering

`ItemData` will gain an exported `runtime_enabled: bool = true` flag. `item_test.tres` will set it to `false`.

The recursive item loader will exclude disabled items from `Global.item_db`. Vendor, exploration, and enemy selection already consume that database, so filtering at ingestion protects every unfiltered generator without duplicating checks.

The development item resource remains available for direct loading by Developer Mode or tests.

## Wave 2: Item Progression, Comparison, and Pricing

### Scripted Ring Feeding

Items whose percentage range is exactly zero still need duplicate progress. `ItemData` will gain an exported `duplicate_feed_value: float = 0.0`.

`ItemInstance.feed_roll()` will use `duplicate_feed_value` only when the incoming percentage roll is effectively zero. Crusher's Ring and Ring of Regeneration will receive an explicit non-zero value tuned to one rarity upgrade per ten duplicate feeds (`0.10` per copy). Their active scripted effects and zero displayed percentage roll remain unchanged.

### Effective Comparison

Item comparison will operate on an item contribution snapshot instead of only `rolled_mods`.

The comparison includes:

- Flat and percentage values from `rolled_mods`.
- The active percentage roll when it differs.
- The human-readable `ItemData.get_effects_short(inst)` output for scripted effects.
- Set identity and the projected equipped-set average rarity/strength change.

The tooltip will show ordinary numeric rows where direct comparison is possible. It will add concise before/after rows when scripted-effect text changes and numeric rows for projected set average rarity and strength. “No numeric stat change” will appear only when neither numeric, scripted, nor set contribution changes.

### Pricing

Market value will remain deterministic and shared by buy and sell calculations. It will include:

- Uncapped rarity growth using a monotonic formula that continues beyond R20.
- Magnitude of flat stats.
- Active percentage magnitude.
- Explicit scripted-effect value.
- Set membership and projected set-strength contribution.
- Existing polarity multiplier.

`ItemData` will expose a small `scripted_value_weight` field for effects that cannot be inferred from stats. Set items receive a bounded membership premium; pricing will not directly copy the full exponential combat multiplier, preventing runaway vendor costs.

Regression tests will prove monotonic growth past R12 and that meaningful flat/scripted/set items are worth more than an otherwise empty item at the same rarity.

## Wave 3: Run Records and Log Noise

`total_runs` will increment exactly once when a new attempt begins, not when continuing or respawning. `best_followers` will update whenever a profile save observes a higher current follower count.

Reserved schema fields (`meta_augment_levels`, unlocked races, and unlocked spells) remain in `SaveData` for compatibility. They will be documented as reserved rather than deleted or given speculative progression behavior.

`BagInventory.debug_bag` will default to `false`. Item upgrade and bag merge/add/feed diagnostics will be guarded behind their owning debug flag or removed when they duplicate an existing guarded diagnostic. Player-facing warnings and real errors remain.

## Wave 4: Procedural Reliability and Pacing

### Candidate Selection

`DistrictPlan.generate()` will score every invalid candidate produced during its six deterministic retries and return the highest-scoring candidate if none is fully valid.

The score prioritizes hard correctness in this order:

1. Reachable primary objective and exit.
2. Reciprocal connectors.
3. Required secondary reachability and count.
4. Required urban access.
5. Start-to-objective and objective-to-exit distance margins.

The returned validation dictionary will identify that fallback selection occurred and include the score. Fully valid candidates still return immediately.

### Route Length

The minimum primary-objective-to-exit route will be five graph steps for Segment 2 and later procedural segments. Segment 1 remains governed by its handcrafted layout.

The deterministic smoke sweep will assert the new minimum across a representative seed range.

### Resonance

Ambient resonance will target approximately four minutes from 18% primary completion with no kill/item bonus, while normal combat bonus flow brings an ordinary run closer to three minutes.

The base ambient rate becomes approximately `(1.0 - 0.18) / 240 = 0.00342` per second. The existing early boost and capped bonus buffer remain, and tests will calculate low-action and normal-action timing bounds from the configured values.

The gate marker remains hidden until 75% resonance, and gate opening still requires 100% plus required boss conditions.

## Wave 5: Packaging

Add `export_presets.cfg` with a reproducible Windows Desktop preset for Godot 4.7.1. The preset will export the playable project and exclude:

- `.godot/`
- Test user-data directories.
- Recovery archives.
- Historical patch files and audit manifests.
- Superpowers planning documents.

A PowerShell release script will:

1. Invoke the Godot console executable in headless release-export mode.
2. Stage output in a versioned release directory.
3. Generate a fresh SHA-256 manifest from staged files.
4. Fail when export or hashing fails.

The script will not delete source-tree artifacts. Because the project currently identifies itself as `0.0.0.25.5`, packaging will preserve that version unless a later request explicitly changes it.

## Testing Strategy

Godot tests will run using an isolated `GODOT_USER_HOME`.

Coverage will include:

- Runtime database exclusion while direct development-resource loading still works.
- Enemy rarity calculation with base, elite, and Threat bonuses.
- Zero-roll scripted item duplicate feeding.
- Effective tooltip comparison behavior.
- Pricing monotonicity and contribution sensitivity.
- Exactly-once run-count updates and best-follower records.
- Debug defaults.
- Procedural fallback scoring and route-distance seed sweeps.
- Resonance timing calculations and unchanged marker threshold.
- Export preset parsing and dry-run packaging validation.

The final verification consists of all focused suites, `ProcPlanSmokeTest`, a Godot editor parse/import smoke check, and a release-script dry run that does not overwrite an existing release.

## Compatibility and Safety

- Existing saves continue loading because all new resource fields have defaults.
- No player save is used by tests.
- No historical or recovery artifact is deleted.
- Developer Mode remains visible and operational.
- The save-integrity transaction from the prior patch remains unchanged except where new tests exercise it.

## Success Criteria

- All active enemy drops honor rarity and Threat/elite bonuses.
- `item_test` cannot enter normal loot or vendor stock.
- Scripted zero-roll rings gain rarity from duplicates.
- Tooltips and prices reflect meaningful item contributions.
- Save cards display real run and follower records.
- Default long-run logs no longer contain bag/item-upgrade spam.
- Procedural generation returns the best retry candidate and later routes meet the five-step minimum.
- Low-action resonance completes near four minutes and ordinary combat approaches three minutes.
- A Windows release can be reproduced without bundling development artifacts.
- Developer Mode is unchanged.
