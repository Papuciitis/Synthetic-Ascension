# Ascension Doctrines Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the weak one-off Segment 5 Major Choice with three save-safe, occult-industrial Ascension Doctrine decisions after Segments 3, 6, and 9, each carrying an explicit gift, price, and run-changing consequence.

**Architecture:** Preserve `MajorChoiceDef` and existing effect composition for save/resource compatibility, but add stage/role/family metadata and build-context scoring. Global owns pending-stage, persisted offer, selected-stage IDs, and generic Doctrine rules; focused gameplay adapters consume those rules in player, augment, Threat, exploration, and Exit Rite systems. The existing screens are restyled and restructured rather than replaced with a parallel navigation flow.

**Tech Stack:** Godot 4.7.1, typed GDScript Resources, existing `StatDelta` and `MajorChoiceEffect` composition, shared occult-institutional UI theme, headless SceneTree tests.

**Spec:** `docs/superpowers/specs/2026-08-26-ascension-doctrines-design.md`

## Global Constraints

- Doctrine stages are exactly `method` after Segment 3, `doctrine` after Segment 6, and `apotheosis` after Segment 9.
- Every offer contains exactly one `amplify`, one `transfigure`, and one `covenant` card in that display order.
- Version one contains exactly the nine named Doctrine resources in the spec; legacy resources remain loadable but are excluded from staged offers.
- Each new card has non-empty `gift_text`, `price_text`, and `consequence_text` and applies both its gift and its price.
- Offer IDs are deterministic from attempt seed plus stage and persist across reloads.
- Existing saves retain already-applied Major Choice effects and do not receive retroactive missed-stage popups.
- A Doctrine is applied once; reload, double-click, and confirm-key repeat cannot duplicate effects.
- Selection uses focus then explicit `Inscribe Doctrine` confirmation.
- Visible UI copy says `ASCENSION DOCTRINE`, uses square/brutalist ritual plates and the shared fonts/theme, and contains no generic rounded card style.
- The Doctrine system adds no deck, draw pile, rarity, card removal, or combat-time card mechanics.
- Preserve unrelated user changes and keep `.superpowers/` and performance captures out of feature commits.

---

## File Structure

- `core/systems/major_choice/MajorChoiceDef.gd`: compatible Doctrine definition with stage, role, family, authored copy, tags, and scoring.
- `core/systems/major_choice/MajorChoiceContext.gd`: immutable run snapshot used for eligibility, score, and previews.
- `core/systems/major_choice/MajorChoiceDB.gd`: deterministic one-per-role staged offer builder.
- `core/systems/major_choice/effects/MCE_ModDoctrineRule.gd`: generic numeric rule mutation used by authored resources.
- `core/systems/major_choice/effects/MCE_AddDoctrineTag.gd`: boolean/tag rule mutation.
- `autoload/global.gd`: stage scheduling, offer persistence, exactly-once apply, rule accessors, migration, Witness use state, and reset.
- `autoload/SaveData.gd`: persisted stage IDs, rules, version, pending stage, and Witness state.
- `core/systems/augments/AugmentRunner.gd` plus the five active augment scripts: Open Circuit cooldown and cross-lock contract.
- `core/actors/player/player.gd`: max-HP Doctrine multipliers, source-aware healing, and Manufactured Witness lethal interception.
- `autoload/ThreatDirector.gd`: Black Archive threat multiplier and Witness threat debt.
- `core/systems/world/SegmentProcBuilder.gd`: Black Archive secondary reward roll and Pilgrim exploration multiplier.
- `core/systems/world/ExitRite.gd`, `core/systems/world/rite/RitePulseResolver.gd`, and `core/systems/world/Wardstone.gd`: Vessel, Pilgrim, and Law of Admission rules.
- `core/systems/major_choice/DoctrineRewardService.gd`: deterministic extra item delivery for Black Archive.
- `ui/screens/MajorChoice.gd/.tscn` and `ui/screens/MajorChoiceCard.gd/.tscn`: focused Doctrine presentation and confirmation.
- `ui/widgets/RunSheetHUD.gd`: Doctrine history and `WITNESS EXPENDED` run record.
- `data/major_choices/doctrines/*.tres`: nine new authored resources.
- `tools/tests/AscensionDoctrineTest.gd/.tscn`: definition, offer, scheduling, rule, and exactly-once contracts.
- `tools/tests/AscensionDoctrineGameplayTest.gd/.tscn`: consumer behavior for all nine cards.
- `tools/tests/AscensionDoctrinePresentationTest.gd/.tscn`: hierarchy, copy, focus/confirm, and theme contract.
- `tools/tests/SaveIntegrityTest.gd`: new-schema round trip and legacy migration.

### Task 1: Define Doctrine Metadata, Context, and Staged Offers

**Files:**
- Modify: `core/systems/major_choice/MajorChoiceDef.gd`
- Create: `core/systems/major_choice/MajorChoiceContext.gd`
- Modify: `core/systems/major_choice/MajorChoiceDB.gd`
- Create: `tools/tests/AscensionDoctrineTest.gd`
- Create: `tools/tests/AscensionDoctrineTest.tscn`

**Interfaces:**
- Consumes: `Global.selected_style_id`, `Global.permanent_augment_ids`, `Global.get_augment_level(id)`, `Global.run_inventory`, `Global.attempt_major_choice_taken_ids`, and a seeded `RandomNumberGenerator`.
- Produces: `MajorChoiceContext.from_global(g: Node, stage_id: StringName) -> MajorChoiceContext`, `MajorChoiceDef.score_for(context: MajorChoiceContext) -> float`, and `MajorChoiceDB.build_stage_offer(context: MajorChoiceContext, taken_ids: Array, rng: RandomNumberGenerator) -> Array[MajorChoiceDef]`.

- [ ] **Step 1: Write failing stage/role offer tests**

Create six in-memory definitions: two per role, all at `method`; mark one candidate in each role with a tag present in the fake context. Assert:

```gdscript
var offer := db.build_stage_offer(context, [], rng)
_check(offer.size() == 3, "one complete Doctrine offer is returned")
_check(offer[0].offer_role == &"amplify", "Amplify is first")
_check(offer[1].offer_role == &"transfigure", "Transfigure is second")
_check(offer[2].offer_role == &"covenant", "Covenant is third")
_check(offer[0].build_tags.has(&"active_augment"), "matching build candidate wins its role")
```

Also assert wrong-stage and taken unique definitions are excluded, an incomplete role returns an empty offer rather than two misleading cards, and two builds with the same seed/context produce identical IDs.

- [ ] **Step 2: Run the test and confirm the missing API failure**

```powershell
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/AscensionDoctrineTest.tscn
```

Expected: non-zero exit because stage metadata/context/build method do not exist.

- [ ] **Step 3: Extend `MajorChoiceDef` compatibly**

Add exports without deleting old fields:

```gdscript
@export var enabled: bool = true
@export_enum("method", "doctrine", "apotheosis") var stage: StringName = &"method"
@export_enum("amplify", "transfigure", "covenant") var offer_role: StringName = &"amplify"
@export var family_id: StringName = &""
@export_multiline var gift_text: String = ""
@export_multiline var price_text: String = ""
@export_multiline var consequence_text: String = ""
@export var build_tags: Array[StringName] = []
@export var base_offer_score: float = 1.0
```

`is_available` must reject `not enabled`, and `is_doctrine_complete()` must require a valid stage, role, family, and all three authored text fields.

- [ ] **Step 4: Implement the context and deterministic role builder**

`MajorChoiceContext` stores `stage_id`, `source_segment`, `style_id`, `augment_ids`, `augment_levels`, `set_piece_counts`, `prior_family_ids`, and a deduplicated `tags` dictionary. Add `active_augment` when any equipped augment effect exposes an active input, style tags such as `style:ranged`, and `family:<id>` for prior choices.

For each role in `[&"amplify", &"transfigure", &"covenant"]`, filter by stage/availability/not-taken, shuffle first with the supplied RNG for deterministic tie order, then choose the highest `base_offer_score + 10.0 per matching build tag + 25.0 for prior family match`. Return `[]` if any role has no candidate.

- [ ] **Step 5: Run the offer test**

Run `AscensionDoctrineTest.tscn`. Expected: offer/context section exits 0.

- [ ] **Step 6: Commit**

```powershell
git add -- core/systems/major_choice/MajorChoiceDef.gd core/systems/major_choice/MajorChoiceContext.gd core/systems/major_choice/MajorChoiceDB.gd tools/tests/AscensionDoctrineTest.gd tools/tests/AscensionDoctrineTest.tscn
git commit -m "feat: define staged ascension doctrine offers"
```

### Task 2: Schedule, Persist, Migrate, and Apply Each Stage Once

**Files:**
- Modify: `autoload/global.gd`
- Modify: `autoload/SaveData.gd`
- Modify: `tools/tests/AscensionDoctrineTest.gd`
- Modify: `tools/tests/SaveIntegrityTest.gd`

**Interfaces:**
- Consumes: `MajorChoiceContext.from_global`, `MajorChoiceDB.build_stage_offer`, existing save load/write/reset paths, and `on_segment_completed(completed_segment: int)`.
- Produces: `func pending_doctrine_stage() -> StringName`, `func get_major_choice_offer(count: int = 3) -> Array`, `func apply_major_choice(choice_id: StringName) -> bool`, `func get_doctrine_rule(key: StringName, fallback: Variant = null) -> Variant`, `func set_doctrine_rule(key: StringName, value: Variant) -> void`, and `func add_doctrine_rule(key: StringName, amount: float) -> void`.

- [ ] **Step 1: Add failing scheduling and exactly-once tests**

Test the exact segment map:

```gdscript
_check(Global.doctrine_stage_for_completed_segment(2) == &"", "Segment 2 has no Doctrine")
_check(Global.doctrine_stage_for_completed_segment(3) == &"method", "Segment 3 grants Method")
_check(Global.doctrine_stage_for_completed_segment(6) == &"doctrine", "Segment 6 grants Doctrine")
_check(Global.doctrine_stage_for_completed_segment(9) == &"apotheosis", "Segment 9 grants Apotheosis")
```

Queue Method, capture its offer IDs, serialize/restore, and assert the same IDs return. Apply one ID twice and assert the first returns true, the second false, the effect counter increments once, and only `method` is stored in `attempt_doctrine_stage_ids`.

- [ ] **Step 2: Add failing save migration assertions**

In `SaveIntegrityTest.gd`, create a legacy save with `attempt_major_choice_id = "major_ritual"`, empty taken IDs, and no Doctrine version. After load assert the old ID is present once in taken history, its existing modifier value is retained, no pending Doctrine is created, and no effect is re-applied.

- [ ] **Step 3: Run both tests and verify failure**

```powershell
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/AscensionDoctrineTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/SaveIntegrityTest.tscn
```

Expected: non-zero exits on the new schema/API.

- [ ] **Step 4: Add the schema and scheduling state**

Add to both runtime and `SaveData`:

```gdscript
const ASCENSION_DOCTRINE_VERSION: int = 1
var attempt_doctrine_version: int = ASCENSION_DOCTRINE_VERSION
var attempt_pending_doctrine_stage: StringName = &""
var attempt_doctrine_stage_ids: Dictionary = {}
var attempt_doctrine_rules: Dictionary = {}
var attempt_witness_used_segment: int = 0
var attempt_doctrine_threat_debt: float = 0.0
```

Persist `attempt_pending_doctrine_stage` and the current `attempt_major_choice_offer_ids`. Clear the offer whenever a new stage is queued. Reset Witness use and Threat debt in `on_segment_completed`.

- [ ] **Step 5: Make application an atomic boolean operation**

`apply_major_choice` must verify pending stage, membership in the persisted offer, definition stage match, and absence from taken IDs before applying effects. After success, write the stage ID and taken ID, clear pending/offer, request one autosave, and return true. Every failed validation returns false without mutation.

Migration copies a non-empty legacy `attempt_major_choice_id` into taken history once, sets version 1, and never calls its effects or queues stages already passed.

- [ ] **Step 6: Run scheduling/save tests**

Run both scenes again. Expected: exit 0, including a save round trip with a pending offer and a completed Method.

- [ ] **Step 7: Commit**

```powershell
git add -- autoload/global.gd autoload/SaveData.gd tools/tests/AscensionDoctrineTest.gd tools/tests/SaveIntegrityTest.gd
git commit -m "feat: persist ascension doctrine progression"
```

### Task 3: Author the Nine Doctrines and Their Generic Rules

**Files:**
- Create: `core/systems/major_choice/effects/MCE_ModDoctrineRule.gd`
- Create: `core/systems/major_choice/effects/MCE_AddDoctrineTag.gd`
- Create: `data/major_choices/doctrines/method_open_circuit.tres`
- Create: `data/major_choices/doctrines/method_frame_of_ash.tres`
- Create: `data/major_choices/doctrines/method_black_archive.tres`
- Create: `data/major_choices/doctrines/doctrine_choir_of_recurrence.tres`
- Create: `data/major_choices/doctrines/doctrine_vessel_without_mercy.tres`
- Create: `data/major_choices/doctrines/doctrine_pilgrim_engine.tres`
- Create: `data/major_choices/doctrines/apotheosis_perfected_engine.tres`
- Create: `data/major_choices/doctrines/apotheosis_law_of_admission.tres`
- Create: `data/major_choices/doctrines/apotheosis_manufactured_witness.tres`
- Modify: all ten legacy `data/major_choices/major_*.tres`
- Modify: `tools/tests/AscensionDoctrineTest.gd`

**Interfaces:**
- Consumes: existing `MCE_AddStatDelta`, `MCE_UpgradeEquippedAugments`, `MCE_ModAttemptFloat`, and Global Doctrine rule accessors.
- Produces: `MCE_ModDoctrineRule` exports `rule_key`, `multiply`, `add`, `clamp_min`, `clamp_max`; `MCE_AddDoctrineTag` exports `rule_key` and `value`; exactly nine complete staged definitions.

- [ ] **Step 1: Add failing content validation**

Load `res://data/major_choices/`, filter `enabled && is_doctrine_complete()`, and assert exactly nine definitions, three per stage, one per role per stage, unique IDs, and exact card titles from the spec. For every resource, apply its effects to a fresh fake Global and assert at least one positive gift state and one negative price state changes.

- [ ] **Step 2: Run the content test and confirm failure**

Run `AscensionDoctrineTest.tscn`. Expected: non-zero exit because no complete staged content exists.

- [ ] **Step 3: Implement composable rule effects**

`MCE_ModDoctrineRule.apply(g)` reads a numeric value with default `1.0` when `multiply != 1.0`, otherwise `0.0`; computes `(current * multiply) + add`; clamps; then calls `g.set_doctrine_rule`. Its preview returns the authored effect label exported as `preview_text`. `MCE_AddDoctrineTag` writes the exact bool/int/string value.

- [ ] **Step 4: Author Method resources with exact mechanics**

- Open Circuit: `StatDelta.haste = 0.20`; rules `active_augment_cooldown_mul = 0.70`, `active_augment_cross_lock_seconds = 2.0`; family `circuit`; tag `active_augment`.
- Frame of Ash: `StatDelta.power = 0.30`, `move_speed = 15.0`; rule `max_hp_mul = 0.75`; family `vessel`.
- Black Archive: `StatDelta.luck = 0.20`; rules `secondary_reward_rolls = 1`, `threat_gain_mul = 1.25`; family `archive`; tag `exploration`.

Copy Gift/Price/Consequence text verbatim from the spec rather than relying on generated effect preview lines.

- [ ] **Step 5: Author Doctrine resources with exact mechanics**

- Choir of Recurrence: `MCE_UpgradeEquippedAugments.amount = 2`; `StatDelta.haste = 0.15`, `power = -0.15`; family `circuit`; tag `active_augment`.
- Vessel Without Mercy: rules `ritual_healing_mul = 1.60`, `other_healing_mul = 0.50`, `rite_stun_bonus_seconds = 0.10`; family `vessel`.
- Pilgrim Engine: `MCE_ModAttemptFloat.property = attempt_exit_hold_mul`, multiply `1.25`; rules `rite_safeguard_capacity = 5`, `rite_safeguard_source_multiplier = 2`; family `archive`; tag `exploration`.

- [ ] **Step 6: Author Apotheosis resources with exact mechanics**

- Perfected Engine: upgrade all augments by 2; `StatDelta.power = 0.35`; rules `max_hp_mul *= 0.70`, `force_augment_identity = true`; family `circuit`.
- Law of Admission: rules `rite_initial_seals = 1`, `rite_burst_count_mul = 1.50`; family `vessel`.
- Manufactured Witness: rule `manufactured_witness = true`; family `archive`; Gift/Price text contains the exact 100 Followers, 50% HP, 2.0 seconds, and 25 Threat values.

Set `enabled = false` on the ten legacy resources; do not delete or rename them.

- [ ] **Step 7: Run content and parse tests**

```powershell
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/AscensionDoctrineTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/ScriptParseAuditTest.tscn
```

Expected: both exit 0; staged content count is exactly nine.

- [ ] **Step 8: Commit**

```powershell
git add -- core/systems/major_choice/effects/MCE_ModDoctrineRule.gd core/systems/major_choice/effects/MCE_AddDoctrineTag.gd data/major_choices tools/tests/AscensionDoctrineTest.gd
git commit -m "feat: author nine ascension doctrines"
```

### Task 4: Consume Combat, Healing, Threat, and Witness Rules

**Files:**
- Modify: `core/systems/augments/AugmentRunner.gd`
- Modify: `effects/augments/logic/HexBlinkMarkEffect.gd`
- Modify: `effects/augments/logic/ReflectShieldEffect.gd`
- Modify: `effects/augments/logic/SpiderlingSummonEffect.gd`
- Modify: `effects/augments/logic/SpiritSlashEffect.gd`
- Modify: `effects/augments/logic/StaminaCoreEffect.gd`
- Modify: `core/actors/player/player.gd`
- Modify: `autoload/ThreatDirector.gd`
- Modify: `autoload/RunEvents.gd`
- Modify: `ui/widgets/RunSheetHUD.gd`
- Create: `tools/tests/AscensionDoctrineGameplayTest.gd`
- Create: `tools/tests/AscensionDoctrineGameplayTest.tscn`

**Interfaces:**
- Consumes: Global rule keys `active_augment_cooldown_mul`, `active_augment_cross_lock_seconds`, `max_hp_mul`, `ritual_healing_mul`, `other_healing_mul`, `manufactured_witness`, and `force_augment_identity`.
- Produces: `Global.doctrine_active_cooldown(base_seconds: float) -> float`, `Global.notify_active_augment_used(slot: int) -> void`, `Global.active_augment_slot_blocked(slot: int) -> bool`, `Global.doctrine_healing_multiplier(source: StringName) -> float`, `Player.heal(amount: float, source: StringName = &"generic") -> void`, and `Global.try_consume_manufactured_witness() -> bool`.

- [ ] **Step 1: Write failing gameplay rule tests**

Cover these exact cases with fake effects/player state:

```gdscript
_check(is_equal_approx(Global.doctrine_active_cooldown(10.0), 7.0), "Open Circuit scales cooldown")
Global.notify_active_augment_used(1)
_check(Global.active_augment_slot_blocked(0), "other slot is cross-locked")
_check(not Global.active_augment_slot_blocked(1), "activating slot remains usable")
_check(is_equal_approx(Global.doctrine_healing_multiplier(&"generic"), 0.50), "Vessel halves ordinary healing")
_check(is_equal_approx(Global.doctrine_healing_multiplier(&"exit_rite"), 1.60), "Vessel amplifies Rite healing")
```

For Witness, set Followers to 150, simulate lethal damage twice in one segment, and assert the first leaves 50 Followers, 50% HP, 2.0 seconds invulnerability, and 25 Threat debt; the second follows normal death handling.

- [ ] **Step 2: Run the gameplay test and confirm failure**

Run `AscensionDoctrineGameplayTest.tscn`. Expected: non-zero exit on missing rule consumers.

- [ ] **Step 3: Apply max-HP and augment rules at existing ownership boundaries**

In the final player stat recomputation, multiply `stats.max_hp` by `Global.get_doctrine_rule(&"max_hp_mul", 1.0)` after additive deltas and clamp to at least 1.0. In `AugmentRunner`, pass each effect its slot and cooldown multiplier. Add `set_doctrine_cooldown_multiplier(value: float)` to the five active effect scripts and apply it to their canonical cooldown maximum, never repeatedly to the already-scaled value.

After each successful active activation, call `Global.notify_active_augment_used(slot)`. Replace the current generic `active_augment_input_blocked()` check in those scripts with `active_augment_slot_blocked(slot)` so the activating slot is not self-locked.

When `force_augment_identity` is true, Run Sheet identity renders all three augment seals as part of the Perfected Engine even when a physical slot is empty; it does not instantiate a missing augment or grant an extra effect.

- [ ] **Step 4: Make player healing source-aware**

Change the signature to `heal(amount: float, source: StringName = &"generic")`. Compute multiplier `ritual_healing_mul` only for `exit_rite` and `wardstone`; otherwise use `other_healing_mul`. Apply the multiplier before the existing landed-heal calculation. Update Wardstone restoration to identify `wardstone`, and update Rite per-second/pulse calls to identify `exit_rite`. Existing callers compile unchanged because the second argument has a default.

- [ ] **Step 5: Implement Witness before normal death**

Immediately before `die()` on lethal damage, call `Global.try_consume_manufactured_witness()`. That method succeeds only when the rule is true, the current segment has not used it, and Followers are at least 100. It performs one `transaction_followers(-100, &"manufactured_witness", ...)`, marks the current segment, adds 25.0 to `attempt_doctrine_threat_debt`, emits `RunEvents.doctrine_event_recorded(&"witness_expended", "WITNESS EXPENDED")`, and returns true. Player then restores to 50% Max HP and grants 2.0 seconds invulnerability instead of calling `die()`.

Add `attempt_doctrine_threat_debt` to ThreatDirector's computed threat after applying `threat_gain_mul`. Reset debt on segment completion. Append Doctrine events under a compact `DOCTRINE RECORD` section in the Run Sheet.

- [ ] **Step 6: Run gameplay and existing player tests**

```powershell
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/AscensionDoctrineGameplayTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/PlaytestRegressionTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/RunSheetArchiveTest.tscn
```

Expected: all exit 0; ordinary augments/healing/death behavior is unchanged when no rules are set.

- [ ] **Step 7: Commit**

```powershell
git add -- core/systems/augments/AugmentRunner.gd effects/augments/logic core/actors/player/player.gd autoload/ThreatDirector.gd autoload/RunEvents.gd ui/widgets/RunSheetHUD.gd tools/tests/AscensionDoctrineGameplayTest.gd tools/tests/AscensionDoctrineGameplayTest.tscn
git commit -m "feat: apply combat ascension doctrines"
```

### Task 5: Consume Exploration and Exit Rite Rules

**Files:**
- Create: `core/systems/major_choice/DoctrineRewardService.gd`
- Modify: `core/systems/world/SegmentProcBuilder.gd`
- Modify: `core/systems/world/ExitRite.gd`
- Modify: `core/systems/world/rite/RitePulseResolver.gd`
- Modify: `core/systems/world/Wardstone.gd`
- Modify: `tools/tests/AscensionDoctrineGameplayTest.gd`
- Modify: `tools/tests/RiteSafeguardIntegrationTest.gd`
- Modify: `tools/tests/ExitRiteTest.gd`

**Interfaces:**
- Consumes: rules `secondary_reward_rolls`, `rite_safeguard_capacity`, `rite_safeguard_source_multiplier`, `rite_stun_bonus_seconds`, `rite_initial_seals`, and `rite_burst_count_mul`; `Global.deliver_guaranteed_item`.
- Produces: `DoctrineRewardService.grant_secondary_roll(g: Node, source_id: int, roll_index: int) -> bool` and `ExitRite.configure_doctrine_rules() -> void`.

- [ ] **Step 1: Add failing exploration/Rite assertions**

Assert Black Archive calls the reward service once per unique secondary, never on duplicate completion. With Pilgrim rules, assert Rite capacity is five and a new source adds two charges but a repeated source adds zero. With Law of Admission, assert a new Rite starts at one-third with one sealed glyph, its first automatic pulse and all burst stages below one-third are marked spent without firing, and later spawn counts are `ceili(base_count * 1.50)`.

- [ ] **Step 2: Run focused tests and verify failure**

Run `AscensionDoctrineGameplayTest.tscn`, `RiteSafeguardIntegrationTest.tscn`, and `ExitRiteTest.tscn`. Expected: non-zero exits on unconsumed rules.

- [ ] **Step 3: Implement deterministic Black Archive reward rolls**

`DoctrineRewardService` sorts valid `Global.item_db` IDs, seeds an RNG with `attempt_world_seed ^ source_id ^ (roll_index * 0x9E3779B9)`, selects one definition, creates an `ItemInstance` at rarity `clampi(attempt_segment / 2, 1, 5)` with positive polarity and `roll_pct = 0.35`, and delivers it through `Global.deliver_guaranteed_item(inst, false)`. No world-drop node is required, so streamed chunks cannot orphan the reward.

Call it only after `_secondary_completed` accepts a unique objective ID and repeat for `int(get_doctrine_rule(&"secondary_reward_rolls", 0))`.

- [ ] **Step 4: Configure Rite rules once in `_ready()`**

Read capacity/source multiplier and hold multiplier before channeling. For initial seals, call `ledger.initialize_sealed(1)`, set `_hold = hold_time / 3.0`, set `_burst_stage` to the first burst index above one-third, and mark lower indices spent. Do not call the first automatic pulse.

When firing later bursts, use `ceili(float(stage.y) * burst_count_mul)`. Add `rite_stun_bonus_seconds` to automatic pulses only. Apply the source multiplier inside `grant_safeguard` while preserving source deduplication and capacity clamping.

- [ ] **Step 5: Route ritual healing sources**

Update `RitePulseResolver.apply` to call `player.heal(amount, &"exit_rite")`; update `_mend` the same way. In `Player.wardstone_full_restore`, route the restoration through the `wardstone` source multiplier and clamp the result to Max HP.

- [ ] **Step 6: Run focused and save tests**

```powershell
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/AscensionDoctrineGameplayTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/RiteSafeguardIntegrationTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/ExitRiteTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/SaveIntegrityTest.tscn
```

Expected: all exit 0.

- [ ] **Step 7: Commit**

```powershell
git add -- core/systems/major_choice/DoctrineRewardService.gd core/systems/world/SegmentProcBuilder.gd core/systems/world/ExitRite.gd core/systems/world/rite/RitePulseResolver.gd core/systems/world/Wardstone.gd tools/tests/AscensionDoctrineGameplayTest.gd tools/tests/RiteSafeguardIntegrationTest.gd tools/tests/ExitRiteTest.gd
git commit -m "feat: apply exploration ascension doctrines"
```

### Task 6: Rebuild the Choice Screen as a Ritual Thesis

**Files:**
- Modify: `ui/screens/MajorChoice.gd`
- Modify: `ui/screens/MajorChoice.tscn`
- Modify: `ui/screens/MajorChoiceCard.gd`
- Modify: `ui/screens/MajorChoiceCard.tscn`
- Modify: `ui/screens/HubShop.gd`
- Create: `tools/tests/AscensionDoctrinePresentationTest.gd`
- Create: `tools/tests/AscensionDoctrinePresentationTest.tscn`
- Modify: `tools/tests/InterfaceThemeConsistencyTest.gd`

**Interfaces:**
- Consumes: `MajorChoiceDef` stage/role/family/Gift/Price/Consequence fields and boolean `Global.apply_major_choice(id)`.
- Produces: `MajorChoiceCard.focused(definition: MajorChoiceDef)` signal, `MajorChoice.focus_choice(definition: MajorChoiceDef) -> void`, and `MajorChoice.confirm_focused_choice() -> bool`.

- [ ] **Step 1: Write failing presentation and interaction tests**

Instantiate the screen with three fake Doctrine definitions and assert title `ASCENSION DOCTRINE`, stage subtitle, exactly three cards, visible `GIFT`, `PRICE`, and `CONSEQUENCE` labels, and no card stylebox corner radius above 2. Simulate one card press and assert no effect applies; then press `Inscribe Doctrine` and assert one apply. Press confirmation again and assert no second apply.

- [ ] **Step 2: Run the presentation test and verify failure**

```powershell
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/AscensionDoctrinePresentationTest.tscn
```

Expected: non-zero exit against the current instant-select rounded cards.

- [ ] **Step 3: Recompose the card hierarchy**

Each card contains, in order: seal index, uppercase stage/role, title, family, thin rule, `GIFT`, Gift copy, `PRICE`, Price copy, `CONSEQUENCE`, Consequence copy. Keep all body copy wrapped and give the center plate a minimum width that fits three cards at 1920×1080. Use the shared Theme; override only ochre/ivory/muted-red colors and 0-2 px corner radii.

Focused cards gain a double-line border and expand their consequence section; unfocused cards remain readable. Disabled/incomplete definitions must never instantiate.

- [ ] **Step 4: Implement focus then confirm**

Card press emits `focused` only. The screen stores one ID, updates the confirm button to `INSCRIBE DOCTRINE`, and shows a concise `This cannot be revised.` line. Confirm calls `Global.apply_major_choice` once; only a true return closes the screen. Escape/back clears focus first and does not bypass a pending Doctrine to Continue.

Keyboard/controller focus order is left-to-right cards, then confirm, then back. Mouse double-click still only focuses because application belongs exclusively to the confirm handler.

- [ ] **Step 5: Run presentation, theme, and Hub regressions**

```powershell
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/AscensionDoctrinePresentationTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --script res://tools/tests/InterfaceThemeConsistencyTest.gd
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/ManagementPauseProbe.tscn
```

Expected: all exit 0; Hub Continue remains disabled only while a stage is pending.

- [ ] **Step 6: Commit**

```powershell
git add -- ui/screens/MajorChoice.gd ui/screens/MajorChoice.tscn ui/screens/MajorChoiceCard.gd ui/screens/MajorChoiceCard.tscn ui/screens/HubShop.gd tools/tests/AscensionDoctrinePresentationTest.gd tools/tests/AscensionDoctrinePresentationTest.tscn tools/tests/InterfaceThemeConsistencyTest.gd
git commit -m "feat: present ascension doctrines as ritual theses"
```

### Task 7: Full Verification and Balance Pass

**Files:**
- Modify feature files only when a failing test or measured playtest identifies a concrete defect.

**Interfaces:**
- Consumes: completed Tasks 1-6 and the Exit Rite Safeguards plan implementation.
- Produces: a verified three-stage progression with documented balance observations.

- [ ] **Step 1: Run all deterministic suites**

```powershell
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/ScriptParseAuditTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/AscensionDoctrineTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/AscensionDoctrineGameplayTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/AscensionDoctrinePresentationTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/SaveIntegrityTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/ExitRiteTest.tscn
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe' --headless --path . --scene res://tools/tests/RunSheetArchiveTest.tscn
```

Expected: every command exits 0.

- [ ] **Step 2: Verify all nine cards through controlled runs**

Use a developer save immediately before each reward segment. Select each of the three cards at Method, Doctrine, and Apotheosis once across repeated runs. For each selection record the displayed Gift/Price/Consequence, before/after stats/rules, save/reload result, and one combat observation proving both gift and price are active.

- [ ] **Step 3: Check choice quality rather than only correctness**

Reject a card if its price can be ignored by the build that benefits most from its gift, if its consequence is only descriptive, or if the correct choice is obvious in all three style builds. Tune only the numeric values named in the spec and keep their direction: every gift stays substantial and every price stays material.

- [ ] **Step 4: Verify migration with a copied legacy profile**

Load a pre-change profile containing `major_ritual` or another old selected ID. Confirm its prior modifier remains, no missed Method/Doctrine prompt is synthesized, the next future scheduled stage appears normally, and saving again writes Doctrine version 1 without deleting legacy history.

- [ ] **Step 5: Commit only evidence-driven corrections**

Stage exact corrected paths and use:

```powershell
git commit -m "fix: close ascension doctrine verification gaps"
```

Skip this commit when verification finds no defect.
