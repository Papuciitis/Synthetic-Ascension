# Equipment Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement canonical item-project merging, centralized Luck/drop calculations, diminishing rarity scaling, polarity hooks, safe reward overflow, and coherent pricing.

**Architecture:** Put pure formulas in focused helpers (`RarityMath`, `LuckResolver`, `ItemGenerator`), state mutation in `ItemInstance.merge_from`, collection routing in existing inventory/router boundaries, and reward ownership in Global. Preserve existing serialized fields and resource defaults.

**Tech Stack:** Godot 4.7.1, GDScript resources, headless regression scenes.

## Global Constraints

- Developer Mode remains unchanged.
- Existing saves load without migration failures.
- POS and NEG projects stay separate.
- New gameplay paths use complete `ItemInstance` objects.
- No speculative NEG effects or augments.

---

### Task 1: Rarity and Luck Math

**Files:**

- Create: `core/systems/items/RarityMath.gd`
- Create: `core/systems/items/LuckResolver.gd`
- Modify: `tools/tests/AuditClosureTest.gd`

- [ ] Add failing literal tests for rarity potency at R0/R10/R100 and bounded monotonic Luck channels.
- [ ] Implement `RarityMath.potency`, `RarityMath.merge_quality`, `RarityMath.merge_mass`, and bounded `LuckResolver` channels.
- [ ] Verify GREEN.

### Task 2: Canonical Merge

**Files:**

- Modify: `data/items/ItemInstance.gd`
- Modify: `data/items/BagInventory.gd`
- Modify: `data/items/Inventory.gd`
- Modify: `scenes/world/pickups/ItemPickup.gd`
- Modify: `tools/tests/AuditClosureTest.gd`

- [ ] Add failing tests for equal-rarity upgrade, low-to-high non-zero progress, overflow, roll preservation, and polarity separation.
- [ ] Implement `ItemInstance.can_merge` and `merge_from`.
- [ ] Replace bag/inventory duplicate algorithms with `merge_from`.
- [ ] Convert pickup raw rolls to complete incoming instances before equip/feed/bag routing.
- [ ] Verify GREEN and scan for conflicting merge arithmetic.

### Task 3: Accessories and Diminishing Sets

**Files:**

- Modify: ring item resources and effect scripts.
- Modify: `data/items/Inventory.gd`
- Modify: `ui/widgets/ItemTooltip.gd`
- Modify: `tools/tests/AuditClosureTest.gd`

- [ ] Add failing tests for ring effect scaling and set potency.
- [ ] Give rings signed effect-strength ranges and apply `1 + active_pct`.
- [ ] Replace exponential set strength and tooltip projection with `RarityMath.potency`.
- [ ] Verify GREEN.

### Task 4: Drop Context and Generator

**Files:**

- Create: `core/systems/items/ItemDropContext.gd`
- Create: `core/systems/items/ItemGenerator.gd`
- Modify: enemy, exploration, indoor, and vendor generation paths.
- Modify: `tools/tests/AuditClosureTest.gd`

- [ ] Test monotonic deterministic promotion scores and over-cap behavior.
- [ ] Implement context and generator.
- [ ] Route existing generation paths through complete instances where their interfaces permit.
- [ ] Verify enemy-configured rarity and runtime item filtering remain intact.

### Task 5: Polarity Hooks and Reward Overflow

**Files:**

- Modify: `data/items/ItemData.gd`
- Modify: `data/items/Inventory.gd`
- Modify: `core/systems/items/ItemEffectRunner.gd`
- Modify: `autoload/global.gd`
- Modify: `core/systems/major_choice/effects/MCE_GrantItemRoll.gd`
- Modify: `tools/tests/AuditClosureTest.gd`

- [ ] Test negative metrics and set composition.
- [ ] Add POS/NEG effect-scene fallback selection.
- [ ] Test equip→bag→stash delivery and non-silent failure contract.
- [ ] Route major-choice item rewards through the delivery API.
- [ ] Verify GREEN.

### Task 6: Pricing

**Files:**

- Modify: `autoload/global.gd`
- Modify: `tools/tests/AuditClosureTest.gd`

- [ ] Test progress value, roll-preserving upgrade value, POS/NEG parity, and buy/sell anti-flip spread.
- [ ] Add progress/merge value and Luck bounds; remove universal NEG premium.
- [ ] Verify GREEN.

### Task 7: Full Verification

- [ ] Run equipment/audit regression suite.
- [ ] Run save-integrity suite.
- [ ] Run 360-plan procedural sweep.
- [ ] Run Godot editor smoke check when no competing editor lock prevents it.
- [ ] Run packaging dry-run.
- [ ] Confirm Developer Mode files were not edited.
- [ ] Report exact evidence and environmental limitations.

