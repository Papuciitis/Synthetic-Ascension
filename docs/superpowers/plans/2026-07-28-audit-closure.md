# Audit Closure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the remaining audit findings without removing Developer Mode.

**Architecture:** Add small data flags and pure calculation helpers at the existing ownership boundaries: item eligibility in `ItemData`/Global loading, item progression in `ItemInstance`, loot construction in `EnemyDrops`, value calculations in Global, comparison projection in `ItemTooltip`, retry scoring in `DistrictPlan`, and release policy in Godot export configuration. Exercise each behavior through Godot headless integration tests.

**Tech Stack:** Godot 4.7.1, GDScript, `.tres` resources, `.tscn` scenes, Godot headless tests, PowerShell release tooling.

## Global Constraints

- Developer Mode and `DevSetCollisionTools` remain unchanged.
- Existing saves remain loadable.
- Tests use isolated `GODOT_USER_HOME`.
- No working-tree recovery, patch, or history artifact is deleted.
- Production changes follow RED→GREEN tests.

---

### Task 1: Runtime Item Eligibility

**Files:**

- Modify: `data/items/ItemData.gd`
- Modify: `data/items/defs/item_test.tres`
- Modify: `autoload/global.gd`
- Create: `tools/tests/AuditClosureTest.gd`
- Create: `tools/tests/AuditClosureTest.tscn`

**Interfaces:**

- Produces: `ItemData.runtime_enabled: bool`.
- Consumes: `Global.load_items_from_dir(path)`.

- [ ] Write a test that directly loads `item_test.tres`, confirms it is disabled, reloads the runtime item database, and confirms `Global.item_db` excludes `item_test`.
- [ ] Run the headless test scene and verify it fails because the field/filter is absent.
- [ ] Add `@export var runtime_enabled: bool = true`, set the test resource to `false`, and require it in `_scan_items_dir_recursive`.
- [ ] Run the test and verify it passes.

### Task 2: Unified Enemy Instance Drops

**Files:**

- Modify: `core/actors/enemy/modules/EnemyDrops.gd`
- Modify: `core/actors/enemy/EnemySpec.gd`
- Modify: enemy specs/scenes that explicitly disable instance drops
- Modify: `tools/tests/AuditClosureTest.gd`

**Interfaces:**

- Produces: `EnemyDrops.compute_drop_rarity(base_min, base_max, elite_bonus, threat_bonus, roll) -> int` as a deterministic helper.
- Produces: every item entitlement through `_spawn_rolled_instance_pickup()`.

- [ ] Add table tests for configured rarity bounds, elite bonus, and Threat bonus.
- [ ] Add a resource scan test asserting no active enemy spec/scene disables instance drops.
- [ ] Verify RED under the legacy defaults and scene overrides.
- [ ] Default `drop_instance_roll` to `true`, migrate explicit overrides, and remove the stack branch from `drop_entitled_item`.
- [ ] Extract and use the rarity helper in `_spawn_rolled_instance_pickup`.
- [ ] Verify GREEN and run the splitter smoke coverage.

### Task 3: Zero-Roll Duplicate Feeding

**Files:**

- Modify: `data/items/ItemData.gd`
- Modify: `data/items/ItemInstance.gd`
- Modify: `data/items/defs/accessories/ring_crusher.tres`
- Modify: `data/items/defs/accessories/ring_regeneration.tres`
- Modify: `tools/tests/AuditClosureTest.gd`

**Interfaces:**

- Produces: `ItemData.duplicate_feed_value: float`.
- Consumes: `ItemInstance.feed_roll(roll_pct)`.

- [ ] Test that ten zero rolls upgrade each scripted ring from R0 to R1.
- [ ] Verify RED because the meter remains zero.
- [ ] Use `duplicate_feed_value` only when `roll_pct` is approximately zero and configure both rings to `0.10`.
- [ ] Verify GREEN and confirm non-zero percentage items retain existing behavior.

### Task 4: Effective Comparison and Pricing

**Files:**

- Modify: `data/items/ItemData.gd`
- Modify: relevant scripted accessory `.tres` resources
- Modify: `autoload/global.gd`
- Modify: `ui/widgets/ItemTooltip.gd`
- Modify: `tools/tests/AuditClosureTest.gd`

**Interfaces:**

- Produces: `ItemData.scripted_value_weight: float`.
- Produces: uncapped `Global.compute_item_value(inst)`.
- Produces: tooltip comparison rows for active percentage, scripted effect text, and projected set strength.

- [ ] Test that R13 is worth more than R12 and R21 more than R20.
- [ ] Test flat, scripted, and set-bearing items against an otherwise empty same-rarity item.
- [ ] Test comparison output for a scripted ring rarity change and a set average-rarity change.
- [ ] Verify RED for capped rarity and omitted contributions.
- [ ] Replace rarity clamping with monotonic uncapped growth, add bounded stat/script/set premiums, and retain polarity/buy/sell spread behavior.
- [ ] Extend tooltip comparison with effect-text and projected-set rows; suppress the neutral line when either changes.
- [ ] Verify GREEN.

### Task 5: Run Records and Debug Noise

**Files:**

- Modify: `autoload/global.gd`
- Modify: `autoload/SaveData.gd`
- Modify: `data/items/BagInventory.gd`
- Modify: `data/items/ItemInstance.gd`
- Modify: `tools/tests/AuditClosureTest.gd`

**Interfaces:**

- Consumes: the existing new-attempt entry point and `Global.write_save`.
- Produces: exactly-once `total_runs` increments and monotonic `best_followers`.

- [ ] Characterize the new-attempt entry point and add tests that continue/respawn paths do not increment.
- [ ] Test that `write_save` raises but never lowers `best_followers`.
- [ ] Test `BagInventory.new().debug_bag == false`.
- [ ] Verify RED.
- [ ] Increment `current_save.total_runs` only at new-attempt creation, update the follower record during save serialization, document reserved schema fields, and guard item/bag diagnostics.
- [ ] Verify GREEN.

### Task 6: Procedural Retry Selection and Route Length

**Files:**

- Modify: `core/systems/world/proc/DistrictPlan.gd`
- Modify: `tools/ProcPlanSmokeTest.gd`
- Modify: `tools/tests/AuditClosureTest.gd`

**Interfaces:**

- Produces: `DistrictPlan._validation_score(validation) -> int`.
- Produces: fallback metadata `fallback_selected` and `fallback_score`.

- [ ] Test score ordering with literal validation dictionaries.
- [ ] Extend the seed sweep to require objective-to-exit distance `>= 5` for Segment 2+.
- [ ] Verify RED for the later-segment distance threshold and last-candidate fallback.
- [ ] Track the highest-scoring candidate across six retries and return it only when no valid candidate exists.
- [ ] Change later-segment minimum objective-to-exit distance to five.
- [ ] Verify GREEN across the deterministic seed sweep.

### Task 7: Resonance Pacing

**Files:**

- Modify: `core/systems/world/SegmentProcBuilder.gd`
- Modify: `tools/tests/AuditClosureTest.gd`

**Interfaces:**

- Consumes: exported resonance rates and thresholds.
- Produces: low-action completion near 240 seconds after the 18% primary reward.

- [ ] Add literal timing assertions for ambient-only and ambient-plus-normal bonus flow, plus the unchanged `0.75` marker threshold.
- [ ] Verify RED under the existing `0.0015` ambient rate.
- [ ] Set `resonance_per_sec` to `0.00342` while preserving early boost and bonus cap.
- [ ] Verify GREEN.

### Task 8: Reproducible Windows Packaging

**Files:**

- Create: `export_presets.cfg`
- Create: `tools/package_release.ps1`
- Modify: `tools/tests/AuditClosureTest.gd`

**Interfaces:**

- Produces: Godot preset `Windows Desktop`.
- Produces: `tools/package_release.ps1 -GodotConsole <path> -OutputRoot <path> [-DryRun]`.

- [ ] Add a test that parses the preset and asserts the expected development-artifact exclusions.
- [ ] Verify RED because the preset is absent.
- [ ] Add the Windows preset with version `0.0.0.25.5` and exclusion filters.
- [ ] Add a script that refuses to overwrite an existing version directory, exports headlessly, and writes a sorted SHA-256 manifest.
- [ ] Run its dry-run validation and the Godot preset parse check.

### Task 9: Full Verification

**Files:**

- Review all modified files.

**Interfaces:**

- Produces: audit-closure evidence.

- [ ] Run `SaveIntegrityTest.tscn`.
- [ ] Run `AuditClosureTest.tscn`.
- [ ] Run `ProcPlanSmokeTest.gd` with the project in headless mode.
- [ ] Run Godot `--headless --editor --quit`.
- [ ] Run packaging dry-run validation.
- [ ] Confirm `DevSetCollisionTools.gd` and Developer Mode configuration were not edited.
- [ ] Report exact pass counts, exit codes, remaining warnings, and the absence of Git metadata.

