# Current Game Data — Synthetic Ascension

Snapshot of the numeric truth of the game as read from code and resources on 2026-08-28 (branch `enemy-world-work`, Godot 4.7.1). Every table names the file(s) it was read from. Nothing here is estimated; if a value is a script default it is labelled as such.

## Quick answers

1. **Items:** 32 `ItemData` `.tres` files under `data/items/defs/`; 31 load into `Global.item_db` (`item_test` has `runtime_enabled = false`).
2. **Curses:** 8 items whose id begins with `curse_` (all `pct_max = 0`, `drop_weight = 0.3`); 3 of them carry a `negative_effect_scenes` behaviour script (Slow Heart, Sour Providence, Tithe Bones).
3. **Sets:** 3 (`conduit`, `gravemarch`, `lattice`), 6 pieces each, tiers at 2 / 4 / 6 pieces.
4. **Augments:** 13 `AugmentData` resources in `data/augments/`; levels start at 1 with no upper cap in code.
5. **Manifestations:** 18 rules in `ManifestationCatalog`, over 5 nouns; **pairs:** 10 (complete C(5,2) matrix) in `ManifestationPairCatalog`.
6. **Enemy archetypes:** 11 `EnemySpec.AI` kinds; 17 `EnemySpec_*.tres` (13 have scenes in `scenes/world/enemies/`, plus 2 bosses and 2 opening-sequence actors).
7. **Proxy-eligible enemies:** only actors whose *active* AI is `CHASE` (0) and that carry none of ELITE/CRITICAL/OBJECTIVE/TUTORIAL/NEVER_RETIRE/SPECIAL — in practice non-elite ambient **Grunt, Brute, Runner**. Summoned minions (`SPECIAL`), beat/interior spawns (`SPECIAL`), elites, bosses and tutorial actors are never proxied.
8. **Corruption Engine:** `power += min(0.30, heaviest_two_active_severity × 0.24·L/(L+1))` — cap +30 % Power, rate 12 % at L1 approaching 24 %.
9. **Doctrine of Burden qualifying rule:** a NEG item in a statistical slot (0–5) whose `|active_pct| / |pct_min| ≥ 0.10` and that is not suppressed by the Lens; pays `armor += min(96, 16·L/(L+1)·count)` and `max_hp ×= 1 + min(0.54, 0.09·L/(L+1)·count)`.
10. **Luck (via `LuckResolver.effective = luck / (|luck| + 0.5)`) affects:** POS/NEG coin (±12 %), roll quality (±0.15), rarity promotion (±0.18), item and health drop chance (0.75–1.35×), lucky crit (≤8 %, ×1.5 damage), lucky evasion (≤6 %), extra Follower per kill (≤20 %), Cult of Personality chance, vendor buy (−≤12 %)/sell (+≤8 %) prices, vendor stock threat (±0.20), Manifestation roll chance (+0.12·eff), Wager Shrine odds (±0.18), indoor loot chance (±0.12).

---

## 1. Items

Source: `data/items/defs/**/*.tres` (loaded recursively by `autoload/global.gd` `load_items_from_dir(ITEMS_DIR)`, `ITEMS_DIR = "res://data/items/defs"`, lines 16–20 and 677–706: only resources with a non-empty `id` and `runtime_enabled == true` enter `Global.item_db`). Schema: `data/items/ItemData.gd`.

`ItemData` defaults (`data/items/ItemData.gd`): `pct_min = -0.9999`, `pct_max = 0.9999`, `drop_weight = 1.0`, `duplicate_feed_value = 0.0`, `scripted_value_weight = 0.0`, `max_stack = 10`, `equip_slot = NONE (-1)`. `EquipSlot` enum: `HP=0, ARMOR=1, MOVE=2, POWER=3, HASTE=4, LUCK=5, OFFHAND=6, RING=7`.

`negative_effect_scenes` fire only while the instance is NEG; `positive_effect_scenes` only while POS; `effect_scenes` always (`ItemData.get_effect_scenes`). `ItemEffectRunner` watches all 8 slots (`core/systems/items/ItemEffectRunner.gd:14`).

| id | display name | slot | pct_min / pct_max | set_id | mods (flat) | rarity_base (per potency step) | effect scenes | negative_effect_scenes (curse behaviour) | scripted_value_weight | drop_weight | curse_? |
|---|---|---|---|---|---|---|---|---|---|---|---|
| acc_firestone | Firestone | 6 OFFHAND | −0.10 / +0.25 | — | power 0.02, haste 0.01 | power 0.01 | `effects/items/scenes/FirestoneEffect.tscn` | — | 18 | 1.0 (default) | no |
| acc_oakheart | Oakheart (Shield) | 6 OFFHAND | −0.10 / +0.20 | — | max_hp 20, armor 40, move −10 | max_hp 10, armor 15 | `OakheartShieldEffect.tscn` | — | 22 | 1.0 | no |
| ring_crusher | Crusher's Ring | 7 RING | −0.20 / +0.35 | — | move 35 | move 8 | `SpeedRingEffect.tscn` | — | 24 | 1.0 | no |
| ring_regeneration | Ring of Regeneration | 7 RING | −0.20 / +0.30 | — | max_hp 10 | max_hp 5 | `RegenerationRingEffect.tscn` | — | 24 | 1.0 | no |
| conduit_actuators | Conduit Actuators | 4 HASTE | −0.20 / +0.35 | conduit | (none) | haste 0.02 | — | — | 0 | 1.0 | no |
| conduit_charm | Conduit Charm | 5 LUCK | −0.50 / +0.80 | conduit | (none) | luck 0.01 | — | — | 0 | 1.0 | no |
| conduit_greaves | Conduit Greaves | 2 MOVE | −0.25 / +0.40 | conduit | (none) | move 10 | — | — | 0 | 1.0 | no |
| conduit_heart | Conduit Heart | 0 HP | −0.35 / +0.50 | conduit | (none) | max_hp 20 | — | — | 0 | 1.0 | no |
| conduit_lens | Conduit Lens | 3 POWER | −0.20 / +0.35 | conduit | (none) | power 0.02 | — | — | 0 | 1.0 | no |
| conduit_plating | Conduit Plating | 1 ARMOR | −0.35 / +0.50 | conduit | (none) | armor 2 | — | — | 0 | 1.0 | no |
| curse_ashen_ballast | Ashen Ballast | 1 ARMOR | −0.95 / 0.00 | — | armor 34 | armor 7 | — | — (stat only) | 0 | 0.3 | **yes** |
| curse_hollow_reliquary | Hollow Reliquary | 3 POWER | −0.80 / 0.00 | — | power 0.22 | power 0.05 | — | — (stat only) | 0 | 0.3 | **yes** |
| curse_jinxed_coin | Jinxed Coin | 5 LUCK | −0.95 / 0.00 | — | luck 0.30 | luck 0.06 | — | — (stat only) | 0 | 0.3 | **yes** |
| curse_leadfoot_vigil | Leadfoot Vigil | 2 MOVE | −0.45 / 0.00 | — | move 30 | move 6 | — | — (stat only) | 0 | 0.3 | **yes** |
| curse_slow_heart | Slow Heart | 0 HP | −0.30 / 0.00 | — | max_hp 40 | max_hp 9 | — | `SlowHeartCurse.tscn` → `effects/items/logic/curses/SlowHeartCurse.gd`: intercepts 85 % of each heal (`INTERCEPT 0.85`), returns it at ≤3.5 % max-HP/s (`RELEASE_PER_SEC 0.035`), bank capped at 60 % max HP (`BANK_CAP_FRACTION 0.60`) | 18 | 0.3 | **yes** |
| curse_sour_providence | Sour Providence | 5 LUCK | −0.30 / 0.00 | — | luck 0.22 | luck 0.05 | — | `SourProvidenceCurse.tscn` → `SourProvidenceCurse.gd`: adds `BIAS_STRENGTH 0.55` (scaled by the item's severity) to `Global.curse_drop_bias`, which `ItemGenerator.roll_signed_range` subtracts from the POS coin | 18 | 0.3 | **yes** |
| curse_starving_crown | Starving Crown | 0 HP | −0.60 / 0.00 | — | max_hp 55 | max_hp 12 | — | — (stat only) | 0 | 0.3 | **yes** |
| curse_tithe_bones | Tithe Bones | 1 ARMOR | −0.30 / 0.00 | — | armor 26 | armor 6 | — | `TitheBonesCurse.tscn` → `TitheBonesCurse.gd`: bills `FOLLOWERS_PER_HEALTH_BAR 22` Followers per full max-HP of damage taken via `transaction_followers` (`SAFETY_MARGIN 0`) | 18 | 0.3 | **yes** |
| gravemarch_bonekey | Gravemarch Bonekey | 5 LUCK | −0.25 / +0.40 | gravemarch | luck 0.015 | luck 0.01 | — | — | 0 | 1.0 | no |
| gravemarch_carapace | Gravemarch Carapace | 1 ARMOR | −0.25 / +0.40 | gravemarch | armor 1.5 | armor 0.35 | — | — | 0 | 1.0 | no |
| gravemarch_censer | Gravemarch Censer | 3 POWER | −0.25 / +0.40 | gravemarch | power 0.04 | power 0.015 | — | — | 0 | 1.0 | no |
| gravemarch_clockjaw | Gravemarch Clockjaw | 4 HASTE | −0.25 / +0.40 | gravemarch | haste −0.01 | haste 0.005 | — | — | 0 | 1.0 | no |
| gravemarch_stompers | Gravemarch Stompers | 2 MOVE | −0.25 / +0.40 | gravemarch | move −4 | move 1 | — | — | 0 | 1.0 | no |
| gravemarch_vessel | Gravemarch Vessel | 0 HP | −0.25 / +0.40 | gravemarch | max_hp 14 | max_hp 3 | — | — | 0 | 1.0 | no |
| lattice_fingerprint | Lattice Fingerprint | 5 LUCK | −0.20 / +0.35 | lattice | luck 0.02 | luck 0.01 | — | — | 0 | 1.0 | no |
| lattice_focusnode | Lattice Focusnode | 3 POWER | −0.20 / +0.35 | lattice | power 0.03 | power 0.01 | — | — | 0 | 1.0 | no |
| lattice_pulsecoil | Lattice Pulsecoil | 0 HP | −0.20 / +0.35 | lattice | max_hp 8 | max_hp 2 | — | — | 0 | 1.0 | no |
| lattice_shellplate | Lattice Shellplate | 1 ARMOR | −0.20 / +0.35 | lattice | armor 1.0 | armor 0.25 | — | — | 0 | 1.0 | no |
| lattice_strideframe | Lattice Strideframe | 2 MOVE | −0.20 / +0.35 | lattice | move 8 | move 2 | — | — | 0 | 1.0 | no |
| lattice_tickspurs | Lattice Tickspurs | 4 HASTE | −0.20 / +0.35 | lattice | haste 0.02 | haste 0.01 | — | — | 0 | 1.0 | no |
| item_test | Test Item | −1 NONE | (defaults) | — | max_hp 20 | — | — | — | 0 | 1.0 | no — **not loaded** (`runtime_enabled = false`) |

Random-item selection everywhere goes through `Global.pick_weighted_item_id(rng, keys)` (`autoload/global.gd:468-484`), weighted by `drop_weight`. Enemy drop pools are filtered by `drop_pool_prefixes` (`EnemySpec`, default `["conduit_","lattice_","gravemarch_","acc_","ring_"]`), so `curse_*` items only enter enemy pools via prefixes that include them (none of the shipped specs do); they reach the player through vendor/vault/other `item_db`-wide picks.

---

## 2. Sets

Source: `data/sets/conduit/Conduit.tres`, `data/sets/gravemarch/Gravemarch.tres`, `data/sets/lattice/Lattice.tres`; schema `data/sets/SetData.gd`, `data/sets/SetTier.gd`; runtime `data/sets/SetRunner.gd`; loaded by `Global.load_sets_from_dir("res://data/sets")` (resources with an empty `id`, i.e. the template `data/sets/SetData.tres`, are skipped). `SetTier.required_count` defaults to 2.

| set id | display name | pieces (items with this `set_id`) | 2-piece tier | 4-piece tier | 6-piece tier | active ability |
|---|---|---|---|---|---|---|
| conduit | Conduit | conduit_heart (HP), conduit_plating (ARMOR), conduit_greaves (MOVE), conduit_lens (POWER), conduit_actuators (HASTE), conduit_charm (LUCK) | **Live Circuit**: +15 move speed, +6 % haste | **Arc Relay**: +`effects/conduit/scenes/ConduitArcBolts.tscn` (weapon attacks periodically arc to a nearby enemy, chain once more) | **Overclock Protocol**: +`ConduitOverclockAndFeedback.tscn` (kills grant a short move/haste overclock + prime a style discharge; active Circuit Feedback pulse) | Circuit Feedback (6 pieces; haste-scaled cooldown) |
| gravemarch | Gravemarch Protocol | gravemarch_vessel (HP), gravemarch_carapace (ARMOR), gravemarch_stompers (MOVE), gravemarch_censer (POWER), gravemarch_clockjaw (HASTE), gravemarch_bonekey (LUCK) | **Ballast Frame**: +18 max HP, +2 armor, −6 move speed | **Sunderstep**: +2 % power; `effects/gravemarch/scenes/GravemarchSunderstep.tscn` (periodic close shockwave: damage, knockback, brief stun) | **Mass Arrest**: +1.5 armor; `GravemarchMassArrest.tscn` (damage bank → auto pull-and-slam; active Verdict spends 60 % of threshold) | Verdict (6 pieces, no active arrest, no cooldown, ≥60 % of bank threshold) |
| lattice | Lattice Index | lattice_pulsecoil (HP), lattice_shellplate (ARMOR), lattice_strideframe (MOVE), lattice_focusnode (POWER), lattice_tickspurs (HASTE), lattice_fingerprint (LUCK) | **Indexed Motion**: +10 move speed, +3 % power | **Afterstrike**: +2 % haste; `effects/lattice/scenes/LatticeAfterstrike.tscn` (delayed area strike near aim) | **Triangle Commit**: +4 % haste, +2 % luck; `LatticeEchoBuffer.tscn` (three living marks form a triangle attack; active Index Commit mirrors marks) | Index Commit (6 pieces + cooldown) |

Tier stat mods are flat (`SetTier.apply_to`); effect scenes receive `setup_set(player, sid, count, avg_rarity, strength)` and `set_set_scaling(...)` from `SetRunner` (`Inventory.get_set_rarity_average`, `Inventory.get_set_strength`).

---

## 3. Rarity

Sources: `core/systems/items/RarityMath.gd`, `data/items/ItemInstance.gd`, `data/items/BagInventory.gd`, `core/systems/items/ItemGenerator.gd`, `core/systems/items/ItemDropContext.gd`, `ui/components/InventorySlotView.gd:336-343`.

Rarity is an unbounded non-negative integer (`ItemInstance.rarity`, promoted by up to 64 loops in `ItemGenerator.roll_rarity`). There are **no named tiers** in code; the only per-tier data is the UI colour.

| rarity | colour (`InventorySlotView._rarity_color`) |
|---|---|
| ≤ −2 | (0.45, 0.00, 0.00) dark red — no generator produces negative rarity |
| −1 | (0.75, 0.10, 0.10) red — same |
| 0 | (0.12, 0.12, 0.12) near-black |
| 1 | (0.20, 0.90, 0.20) green |
| 2 | (0.25, 0.45, 1.00) blue |
| 3 | (0.70, 0.25, 0.95) purple |
| ≥ 4 | (1.00, 0.65, 0.15) orange |

**Potency (`RarityMath`)**

| constant / formula | value |
|---|---|
| `potency(r)` | `1 + 0.45·√r + 0.05·r` |
| `RATE_STAT_POTENCY_CAP` | 2.25 — move_speed and haste use `k = min(potency − 1, 2.25)` (`ItemInstance._recompute_flat_mods`) |
| `GAP_HALF_LIFE` | 1.5 ranks halve merge value |
| `merge_quality(data, roll)` | `0.75 + 0.50 · clamp(|roll| / max(|pct_min|, |pct_max|), 0, 1)` |
| `merge_mass(in_r, dest_r, q)` | `q · 2^((in_r − dest_r) / 1.5)` |
| `overflow_factor()` | `2^(−1/1.5) ≈ 0.63` — leftover meter after a rank-up is multiplied by this |
| `ItemInstance.rarity_effect_multiplier()` | `potency(rarity + clamp(upgrade_meter, 0, 0.999999))` — scripted accessory effects scale with this |
| flat mods | `rolled_mods = data.mods + data.rarity_base × (potency(rarity + meter) − 1)` (rate stats capped as above) |

**Merge / feed rules (`ItemInstance.merge_from`, `BagInventory`)**

| rule | value |
|---|---|
| Bag stack key | `"<item_id>|pos"` or `"<item_id>|neg"` — rarity deliberately ignored (`BagInventory._key`) |
| `can_merge` | same `data.id`, same polarity, neither locked, not self |
| Auto-swap | if incoming rarity > destination rarity, the rarity/meter/best_pct/progress payload swaps so the higher rank is always the mathematical destination; the destination object keeps its `manifestation_id` |
| Mass | `merge_mass(incoming.rarity, rarity, merge_quality(...))` + `merge_mass(incoming.rarity, rarity, incoming.upgrade_meter)` |
| `progress` | `+= max(1, incoming.progress)` |
| POS `best_pct` | `max(best, incoming)` |
| NEG `best_pct` | default `max(best, incoming)` (mildest survives); with `augment_corruption_engine` equipped `min(best, incoming)` (deepest survives) |
| Rank-up | while `upgrade_meter ≥ 1 − 1e-6`: `meter = (meter − 1) · overflow_factor`, `rarity += 1` |
| Fed pickups | `feed_roll(roll, incoming_rarity=0)` — ground pickups are rank-0 material |
| Manifestation absorb | automatic consolidation only merges when `can_absorb_manifestation_of` (incoming has no rule or the same rule); locked stacks never consolidate |
| `BagInventory.SLOT_COUNT` | 16 (+ `extra_slots`) |
| `_score` (best-of ordering) | `rarity·100000 + meter·1000 + |best_pct|·10` |

**Rarity generation (`ItemGenerator`, `ItemDropContext`, `Global.build_item_drop_context`)**

| step | formula |
|---|---|
| base | `randi_range(rarity_min, rarity_max)` |
| promotion chance | `0.08 + min(0.18, (segment−1)·0.015) + threat·0.12 + min(source_rank,4)·0.08 + (0.08 if elite) + LuckResolver.rarity_promotion_bonus(luck) + min(0.10, catchup_gap·0.02)`, clamped to 0.90; `catchup_gap = max(0, equipped_rarity_average − current)` |
| soft cap | `rarity_soft_cap = max(rarity_max + 1, floor(segment / 3) + source_rank)`; above it chance `×= overcap_chance` (`ItemDropContext` default 0.08) |
| `threat_level` in context | `ThreatDirector.resonance` (0–1), not `threat` |
| enemy drop band | `spec.drop_rarity_min/max + ThreatDirector.loot_rarity_bonus (+ spec.elite_rarity_bonus 1 if elite or split heir)` (`core/actors/enemy/modules/EnemyDrops.gd:194-205`) |

---

## 4. Polarity / Burden

Sources: `core/systems/items/ItemGenerator.gd:46-79`, `core/systems/items/LuckResolver.gd`, `autoload/global.gd:911-916` (`roll_percent`) and `:221` (`curse_drop_bias`), `core/systems/items/BurdenSnapshot.gd`, `core/systems/items/BurdenResolver.gd`, `core/actors/player/player.gd:527-602`, `data/items/Inventory.gd:5-12`.

**POS/NEG roll (`ItemGenerator.roll_signed_range(min_pct, max_pct, luck, rng)`)**

| step | formula |
|---|---|
| sign availability | `has_positive = max_pct > 0`, `has_negative = min_pct < 0`; if only one sign exists it is forced (all `curse_*` items have `pct_max = 0` → always NEG) |
| POS probability | `clamp(0.50 + effective(luck)·0.12, 0.20, 0.80)` (`LuckResolver.positive_probability`), then `clamp(p − Global.curse_drop_bias, 0.05, 0.95)` |
| quality | `clamp((rand + rand)/2 + LuckResolver.roll_quality_shift(luck), 0, 1)`, shift = `clamp(effective·0.15, −0.15, 0.15)` — quality 1 is always the player-best outcome |
| POS value | `lerp(max(0, min_pct), max_pct, quality)` |
| NEG value | `lerp(min_pct, min(0, max_pct), quality)` (quality 1 → mildest curse) |
| `Global.roll_percent` | same, clamped to ±0.9999 |
| `Global.curse_drop_bias` | starts 0.0, reset per run; raised by Sour Providence (`BIAS_STRENGTH 0.55`, severity-scaled) |

**Burden snapshot (`BurdenResolver.resolve(inventory, augment_ids)`)**

| constant | value | meaning |
|---|---|---|
| `Inventory.STAT_SLOT_COUNT` | 6 | slots 0–5 are statistical (HP, ARMOR, MOVE, POWER, HASTE, LUCK); 6 = OFFHAND, 7 = RING; `SLOT_COUNT = 8` |
| `BurdenSnapshot.QUALIFYING_BURDEN_RATIO` | 0.10 | `ratio = |active_pct| / max(|pct_min|, |severity|, 0.0001)` must be ≥ 0.10 to count for the Doctrine |
| `BurdenResolver.INVERSION_RETURN` | 0.55 | fraction of a suppressed curse's severity returned as its own stat |
| `doctrine_armor_per_item` (static) | 16.0 | flat armour per qualifying curse at L→∞ |
| `doctrine_hp_per_item` (static) | 0.09 | max-HP fraction per qualifying curse at L→∞ |
| `doctrine_armor_cap` (static) | 96.0 | total armour ceiling |
| `doctrine_hp_cap` (static) | 0.54 | total max-HP fraction ceiling |
| `asymptotic_rate(ceiling, L)` | `ceiling · L / (L + 1)` | L1 = ½ ceiling, L2 = ⅔, L3 = ¾ … |
| census | counts every NEG/POS item in all 8 slots (accessories included), ignores suppression | read by `is_balanced()` (neg_count == pos_count > 0) |
| suppression | with `augment_inversion_lens`: exactly the single most severe statistical-slot NEG item gets `active = 0`, `suppressed_slot`, `suppressed_severity` | runtime only; the stored roll is never rewritten |
| totals | over ACTIVE burden only: `active_count`, `total_active`, `severities` (descending), `qualifying_count` | a suppressed curse feeds neither Corruption nor the Doctrine |

**Stat pass in `player.gd recompute_run_stats` (lines 527–602)**

| slot | application of `pct = item.active_pct()` (suppressed → `pct = 0.55 × suppressed_severity`, positive) |
|---|---|
| 0 HP | `max_hp ×= (1 + pct)`, pct clamped ±0.95 |
| 1 ARMOR | `armor ×= (1 + pct)`, ±0.95 |
| 2 MOVE | `move_speed ×= (1 + pct)`, ±0.95 |
| 3 POWER | `power += pct`, ±0.95 |
| 4 HASTE | `haste += pct`, ±0.95 |
| 5 LUCK | `luck += pct`, ±0.9999 |

**The three NEG archetype augments (`player.gd:570-595`)**

| augment | formula | reads |
|---|---|---|
| Corruption Engine (`augment_corruption_engine`) | `power += min(0.30, burden.heaviest(2) × asymptotic_rate(0.24, L))` — cap **+0.30**, rate **0.24·L/(L+1)** per 100 % severity of the two most severe ACTIVE curses; also flips NEG merge to keep the deeper roll (`ItemInstance.merge_from`) | `BurdenSnapshot.heaviest(2)` |
| Doctrine of Burden (`augment_doctrine_of_burden`) | `armor += min(96, 16·L/(L+1) × qualifying_count)`; `max_hp ×= 1 + min(0.54, 0.09·L/(L+1) × qualifying_count)` (`BurdenResolver.doctrine_bonus`) | `BurdenSnapshot.qualifying_count` |
| Inversion Lens (`augment_inversion_lens`) | suppression in the slot loop (penalty replaced by `+0.55 × severity` on the same stat), plus `luck += asymptotic_rate(0.30, L) × suppressed_severity` — luck kicker ceiling **0.30** | `BurdenSnapshot.suppressed_slot / suppressed_severity` |

After these, `Global.apply_doctrine_final_stat_multipliers(s)` applies the major-choice doctrine `max_hp_mul`, and `Global.run_luck = s.luck` is written (the only write site besides run reset / dev overlay).

---

## 5. Augments

Source: `data/augments/*.tres` (loaded by `Global.load_augments_from_dir("res://data/augments")`), schema `core/systems/augments/AugmentData.gd`, instantiation `core/systems/augments/AugmentRunner.gd`, stats `Global.apply_permanent_augments_to_stats` (`autoload/global.gd:816-833`), levels `Global.get_augment_level / set_augment_level` (`:1038-1051`).

Level rules: `get_augment_level` returns `max(1, attempt_augment_levels[id])` (default 1); `set_augment_level` stores `max(1, level)`; **no maximum level exists in code**. Stat mods scale by `1 + mods_scale_per_level × (level − 1)` (`AugmentData.apply_to_stats_at_level`). Three permanent slots (`Global.permanent_augment_ids`, size 3).

| id | display name | stat mods (L1) | mods_scale_per_level | effect scene | one-line effect (from `details`) | which system reads it |
|---|---|---|---|---|---|---|
| augment_corruption_engine | Corruption Engine | — | 0 | — | Two most severe NEG items grant Power per 100 % severity (12 % L1 → 24 %, output cap +30 %); NEG merges keep the deeper roll | `player.gd:570-576`; `ItemInstance.merge_from:191-198`; `BuildIdentity.gd`; `ItemTooltip.gd`; `RunSheetHUD.gd` |
| augment_cult_of_personality | Cult of Personality | — | 0 | — | On kill: `0.10 + 0.05·(L−1) + extra_follower_chance(luck)` chance of +1 Follower | `core/actors/enemy/modules/EnemyLifecycle.gd:92-96`; `core/systems/enemy_world/EnemyCombatService.gd:111-115` |
| augment_doctrine_of_burden | Doctrine of Burden | — | 0 | — | Each qualifying NEG item (≥10 % of authored range) grants Armour and Max HP (see §4) | `player.gd:582-587`; `BurdenResolver.doctrine_bonus`; `BuildIdentity.gd`; `RunSheetHUD.gd` |
| augment_blink_hex | Blink Hex | — | 0 | `effects/augments/scenes/HexBlinkMarkEffect.tscn` | Blink 320 px, 6.0 s CD, mark 6.0 s (1 shot), bonus 2d8 + 12×Power, 10 % refund | `AugmentRunner` (effect scene) |
| augment_inversion_lens | Inversion Lens | — | 0 | — | Most severe NEG item suppressed; 55 % of its severity returns as the same stat; Luck kicker | `BurdenResolver.resolve:52`; `player.gd:593-595`; `BuildIdentity.gd` |
| augment_lucky_charm | Lucky Charm | luck +0.5 | 0.2 | — | +0.5 Luck (×1.2 per extra level) | `Global.apply_permanent_augments_to_stats` only |
| augment_magic_missile | Magic Missile | — | 0 | `MagicMissileEffect.tscn` | Auto-fires 2 missiles every 0.75 s (0.08 s spacing), seek 750 px, 0.35×Power | `AugmentRunner` |
| augment_reflect_shield | Reflect Shield | armor +8 | 0.2 | `ReflectedShieldEffect.tscn` | Parry window 0.14 s (perfect 0.06 s), CD 0.40 s / 0.10 s, reflect 0.95× dmg 1.05× speed, perfect zap chains 3 in 220 px at 0.35×Power, stun 0.12 s | `AugmentRunner` + stats |
| augment_spirit_slash | Spirit Slash | — | 0 | `SpiritSlashEffect.tscn` | Active: 2.5 s CD, 180 px, 3d6 + 10×Power, 1–3 Bleed (3 s), 12 % crit stun, d4≥3 refunds CD | `AugmentRunner` |
| augment_sprint_servos | Sprint Servos | move +100, haste +0.12 | 0.2 | — | +100 move speed, +12 % haste | stats only |
| augment_stamina_core | Stamina Core | max_hp +80, armor +10 | 0.15 | `StaminaCoreEffect.tscn` | Passive +80 HP/+10 armor; every 12 s (haste-scaled) 4.0 s active, 2.0 s invulnerable, 25 % lifesteal | `AugmentRunner` + stats |
| augment_summon_spiderlings | Summon Spiderlings | power +0.05 | 0.25 | `SpiderlingSummonEffect.tscn` | Active: 320 px cast, 1.25 s CD, 12 s lifetime, bite 6×Power, detonate 1d4 + 8×Power in 52 px | `AugmentRunner` + stats |
| augment_tesla_aura | Tesla Aura | haste +0.10 | 0.2 | `TeslaAuraEffect.tscn` | Pulse every 0.55 s, chain up to 4 targets in 180 px, 0.45×Power | `AugmentRunner` + stats |

`Global.follower_belief_power()` (`global.gd:802-806`) adds `min(0.15, 0.01·√followers)` Power on top of augments (25 → +5 %, 100 → +10 %, cap +15 %).

---

## 6. Manifestations

Sources: `data/manifestations/ManifestationCatalog.gd`, `ManifestationDef.gd`, `ManifestationNouns.gd`, `ManifestationPairCatalog.gd`, `ManifestationPairDef.gd`; runtime `core/systems/manifestations/ManifestationRunner.gd`, `ManifestationState.gd`; roll site `data/items/ItemInstance.gd:68-83`.

**Roll chance (`ManifestationCatalog.slot_chance(slot, polarity, luck)`)**

`chance = SLOT_CHANCE[slot] + (0.08 if NEG) + LuckResolver.effective(luck) × 0.12`, clamped to [0, 0.95]. `roll_for` returns `""` if `rng.randf() > chance`; otherwise a weighted pick from the slot pool with `weight × bond_multiplier`, where `bond_multiplier = 1 + 1.0 × matched_tags + (2.0 if matched ≥ 2)` (`BOND_PER_TAG 1.0`, `BOND_DUO_BONUS 2.0`) against `Global.equipped_manifestation_tags()` (distinct rules per noun).

| slot | `SLOT_CHANCE` |
|---|---|
| 0 HP | 0.22 |
| 1 ARMOR | 0.22 |
| 2 MOVE | 0.26 |
| 3 POWER | 0.35 |
| 4 HASTE | 0.35 |
| 5 LUCK | 0.30 |
| 6 OFFHAND | 0.60 |
| 7 RING | 0.70 |

Fabricated merge material never rolls (`from_roll(..., roll_manifestation=false)`); Cursed Vault forces one if `guarantee_manifestation`.

**Nouns (`ManifestationNouns.ENTRIES`, `ManifestationState.NOUNS`)**

| noun | label | colour | glyph | channels |
|---|---|---|---|---|
| ward | WARD | (1.00, 0.32, 0.30) | ⬡ | time_since_hit (COMPOSURE, full at 6.0 s) |
| momentum | MOMENTUM | (1.00, 0.62, 0.22) | ➶ | momentum (cap 1.0, decays 0.85/s while still), stability (cap 1.0, decays 1.60/s while moving) |
| fortune | FORTUNE | (1.00, 0.84, 0.32) | ✺ | misfortune (count, cap 25) |
| cadence | CADENCE | LAYER (0.78, 0.61, 1.00) | ⚔ | attack_index (count, no meter), time_since_attack (seconds) |
| shard | SHARDS | (0.72, 0.95, 1.00) | ✦ | shard (orbit), mark |

**Rules (`ManifestationCatalog._ensure_built`, 18)**

| id | display name | slots | tags (nouns) | weight | rule text | logic script (`effects/manifestations/logic/`) |
|---|---|---|---|---|---|---|
| pilgrims_momentum | Pilgrim's Momentum | MOVE, RING | momentum, cadence | 1.2 | Travelling without stopping builds Momentum. At full Momentum your next attack fires twice. | PilgrimsMomentum.gd |
| anchor_rite | Anchor Rite | MOVE, ARMOR, RING | momentum, cadence | 1.0 | Standing still builds Stability. At full Stability your attack covers ground it otherwise could not. Moving drains it. | AnchorRite.gd |
| sunder_wake | Sunder Wake | MOVE, OFFHAND, RING | momentum | 1.0 | Attacking spends all Momentum and tears a shockwave out of the ground where it lands. | SunderWake.gd |
| third_litany | Third Litany | POWER, HASTE, RING | cadence | 1.0 | Every third attack is empowered — only if you let the second one finish. | ThirdLitany.gd |
| stored_violence | Stored Violence | POWER, OFFHAND, RING | cadence | 1.0 | While not attacking, Violence accumulates; next attack releases all of it. | StoredViolence.gd |
| predestination_sigil | Predestination Sigil | POWER, HASTE, RING | shard | 0.9 | First hit on an elite Marks it; the Mark takes enormous extra damage, everything else less; killing it detonates the Mark. | PredestinationSigil.gd |
| fever_litany | Fever Litany | HASTE, POWER, RING | cadence | 1.0 | Quick-succession attacks stack Fever (Haste); lapse the chain and it all goes at once. | FeverLitany.gd |
| impact_scripture | Impact Scripture | HP, ARMOR, RING | momentum, ward | 1.0 | Taking a hit spends all Momentum and detonates it around you. | ImpactScripture.gd |
| martyr_circuit | Martyr Circuit | HP, ARMOR, RING | ward, cadence | 0.9 | Healthy, you attack slower. Wounded, you accelerate. Near death, your attacks echo. | MartyrCircuit.gd |
| retaliation_writ | Retaliation Writ | ARMOR, MOVE, RING | ward, momentum | 1.0 | You evade more often, and every evade answers with a retaliation nova. | RetaliationWrit.gd |
| scar_tissue | Scar Tissue | HP, ARMOR, RING | ward | 1.0 | You refuse most healing; every point refused becomes Armour that slowly bleeds away. | ScarTissue.gd |
| broken_providence | Broken Providence | LUCK, RING | fortune | 1.0 | Every failed Lucky Crit banks Misfortune; the next Lucky Crit spends all of it. | BrokenProvidence.gd |
| tithe_furnace | Tithe Furnace | LUCK, OFFHAND, RING | cadence, fortune | 0.9 | Every eighth attack burns a Follower to empower itself; refuses to spend below reconstruction cost. | TitheFurnace.gd |
| orbiting_testament | Orbiting Testament | OFFHAND, RING | shard, fortune | 1.1 | Lucky Crits forge a shard into orbit; shards shred whatever they pass through. | OrbitingTestament.gd |
| splinter_dividend | Splinter Dividend | OFFHAND, POWER, RING | shard | 1.0 | Elites shatter when they die, throwing fragments into your orbit. | SplinterDividend.gd |
| vector_halo | Vector Halo | OFFHAND, RING | shard, cadence | 1.0 | Every tenth attack sheds a shard; orbit holds more; dashing launches the halo. | VectorHalo.gd |
| heretical_cartography | Heretical Cartography | LUCK, MOVE, RING | fortune | 1.0 | Entering somewhere new rewards you; stacks; completing a secondary extends it. | HereticalCartography.gd |
| overtime_gospel | Overtime Gospel | HP, LUCK, OFFHAND, RING | fortune, ward | 0.8 | Once the Exit Rite is ready, every moment you refuse to leave makes you stronger — and hunted faster. | OvertimeGospel.gd |

**Pairs (`ManifestationPairCatalog`, `NOUN_THRESHOLD = 2` distinct rules of each noun lights the pair; pairs are never rolled)**

| id | display name | nouns | rule text | logic script (`effects/manifestations/pairs/`) |
|---|---|---|---|---|
| slipstream_foundry | Slipstream Foundry | momentum + shard | While moving, shards string out behind you, holding where you left them before snapping back. | SlipstreamFoundry.gd |
| marching_order | Marching Order | momentum + cadence | Distance advances your attack rhythm as if you had attacked; stopping forfeits the beat. | MarchingOrder.gd |
| red_line | Red Line | momentum + ward | While wounded, spending Momentum pays out speed and one ignored hit instead of damage. | RedLine.gd |
| pilgrims_toll | Pilgrim's Toll | fortune + momentum | First enemy touched after a long unbroken run is Marked outright. | PilgrimsToll.gd |
| loom | Loom | cadence + shard | Your empowered beat fires the whole orbit at your aim and deals no weapon damage of its own. | Loom.gd |
| reliquary_guard | Reliquary Guard | shard + ward | A hit that would land shatters a shard instead; an empty orbit is unguarded. | ReliquaryGuard.gd |
| bad_fortune_engine | Bad Fortune Engine | fortune + shard | Every failed Luck roll forges a shard instead of banking Misfortune; every success consumes two. | BadFortuneEngine.gd |
| death_rattle | Death Rattle | cadence + ward | While wounded, breaking rhythm no longer forfeits the beat — it costs health to hold it. | DeathRattle.gd |
| tithe_rhythm | Tithe Rhythm | cadence + fortune | Your empowered beat spends a Follower to fire a second time, returned if that shot kills. | TitheRhythm.gd |
| debt_collector | Debt Collector | fortune + ward | Below a third health every Luck roll succeeds, and every success takes a Follower. | DebtCollector.gd |

Pair scaling uses the mean `effective_rarity()` of the rules that formed it (`ManifestationRunner._mean_rarity_for`).

**Runner / state constants**

| constant | value | file |
|---|---|---|
| `POWER_THRESHOLDS` | `{3: "three_manifestations", 5: "five_manifestations"}` — distinct equipped rules crossing 3 / 5 emit `RunEvents.power_threshold_crossed` once each; ThreatDirector then freezes enemy HP/damage scaling for `power_contrast_lag_sec` (25 s) | `ManifestationRunner.gd:757` |
| `DUPLICATE_FALLOFF` | 0.5 — the Nth copy of the same rule contributes `0.5^N` of its multiplier | `ManifestationRunner.gd:615` |
| `HOOKS` | on_attack, on_lucky_crit, on_lucky_crit_failed, on_hit, on_kill, on_damage_taken, on_evaded, on_dash, on_healed, on_building_entered, on_secondary_completed, on_followers_changed, on_gate_ready | `ManifestationRunner.gd:15` |
| `MOMENTUM_BASE_FILL_DISTANCE` | 704 px of unbroken travel fills Momentum for any claimer | `ManifestationState.gd:45` |
| `MOMENTUM_DECAY_PER_SEC` / `STABILITY_DECAY_PER_SEC` | 0.85 / 1.60 | `ManifestationState.gd:30,46` |
| `WOUND_HEALTHY / WOUNDED / DYING` | 0.70 / 0.40 / 0.20 HP fraction | `:167-169` |
| `RETALIATION_COOLDOWN` | 0.12 s | `:173` |
| `CADENCE_RESOLVE_WINDOW` / `CADENCE_CHAIN_WINDOW` | 0.30 s / 0.42 s | `:179,183` |
| `EVASION_CLAMP` | 0.45 (runner clamps total bonus evasion; player clamps total evade to 0.60) | `:191`; `player.gd:1016` |
| `COMPOSURE_SECONDS` / `COMPOSURE_REDUCTION` | 6.0 s unhurt → next hit ×(1 − 0.45) | `:233-234` |
| `BASE_SHARD_CAP` / `BASE_SHARD_DAMAGE_MULT` | 4 / 0.55 × scaled attack damage | `:245-246` |
| shard orbit | radius 46 px (×0.86–1.14), spin 2.3 rad/s, hit radius 22 px, per-shard cooldown 0.32 s, sweep every 0.08 s | `:24-28` |
| misfortune cap | 25 | `CHANNELS.misfortune.cap` |
| `POPUP_STAGGER` | 16 px | `:748` |

---

## 7. Luck

Sources: `core/systems/items/LuckResolver.gd`; sites found by `grep run_luck|LuckResolver|lucky_crit_chance` (tests excluded).

`Global.run_luck` (`autoload/global.gd:216`) is written from `Stats.luck` at the end of `player.gd recompute_run_stats` (`:602`), reset to 0 per run (`:426`), and dev-tweaked by `ui/widgets/PerformanceOverlay.gd:845-849`. Base Luck sources: style (`data/styles/Ranged.tres luck_add 0.05`, `Magic.tres 0.08`), Lucky Charm (+0.5), LUCK-slot roll, sets (Lattice 6-piece +0.02), Inversion Lens kicker, `ManifestationState.bonus_luck()`.

| `LuckResolver` function | formula (`eff = luck / (|luck| + 0.50)`, `SOFTCAP 0.50`) | consumer(s) |
|---|---|---|
| `positive_probability(luck)` | `clamp(0.50 + eff·0.12, 0.20, 0.80)` | `ItemGenerator.roll_signed_range:63` (POS/NEG coin) |
| `roll_quality_shift(luck)` | `clamp(eff·0.15, −0.15, 0.15)` | `ItemGenerator.roll_signed_range:73` (roll quality) |
| `rarity_promotion_bonus(luck)` | `clamp(eff·0.18, −0.18, 0.18)` | `ItemGenerator.promotion_chance:14`; `WagerShrineObjective.odds_for:149` (`clamp(base_odds + bonus, 0.05, 0.97)`) |
| `drop_multiplier(luck)` | `clamp(1 + eff·0.35, 0.75, 1.35)` | `EnemyDrops._roll_item_drop:164` (item drop chance) and `try_drop_health_pickup:85` (health drop chance, base `health_drop_chance 0.03`) |
| `lucky_crit_chance(luck)` | `clamp(max(0,eff)·0.08, 0, 0.08)` | `player.gd:651` — whole attack ×1.5 damage, "LUCKY" popup, `RunEvents.player_lucky_crit` |
| `lucky_evasion_chance(luck)` | `clamp(max(0,eff)·0.06, 0, 0.06)` | `player.gd:1014` — hit ignored; total evade with Manifestation bonus clamped 0.60 |
| `extra_follower_chance(luck)` | `clamp(max(0,eff)·0.20, 0, 0.20)` | `EnemyLifecycle.gd:89,94` and `EnemyCombatService.gd:108,113` — +1 Follower per kill; also added to Cult of Personality chance |
| `buy_multiplier(luck)` | `1 − clamp(max(0,eff)·0.12, 0, 0.12)` | `Global.compute_buy_value:1970` |
| `sell_multiplier(luck)` | `1 + clamp(max(0,eff)·0.08, 0, 0.08)` | `Global.compute_sell_value:1976` (`value × 0.55 × mult`) |
| `vendor_stock_bonus(luck)` | `clamp(eff·0.20, −0.20, 0.20)` | `ui/screens/HubShop.gd:1428` — added to the vendor drop context's `threat_level` |
| `secondary_event_bonus(luck)` | `clamp(eff·0.12, −0.12, 0.12)` | `scenes/world/volumes/IndoorVolume.gd:268` — added to `small_loot_chance 0.22` / `large_loot_chance 1.0` |
| `effective(luck) × LUCK_CHANCE_SCALE 0.12` | — | `ManifestationCatalog.slot_chance:266` (Manifestation roll chance) |
| `augment_quality_bonus(luck)` | `clamp(eff·0.12, −0.12, 0.12)` | **no callers found** |

Other `run_luck` readers: `ItemInstance._roll_manifestation:77`, `ItemInstance.from_data:244`, `BagInventory.add_pickup:168`, `scenes/world/pickups/ItemPickup.gd:230` (all via `Global.roll_percent`); `Global.build_item_drop_context:552` (`context.player_luck`); `ui/widgets/RunSheetHUD.gd:355` (display). Manifestation scripts `HereticalCartography.gd`, `OvertimeGospel.gd`, `DebtCollector.gd` reason about it in comments (Luck reaches `LuckResolver` only through `Global.run_luck`).

---

## 8. Enemies

Sources: `core/actors/enemy/EnemySpec.gd` (schema + defaults), `core/actors/enemy/EnemySpec_*.tres`, `scenes/world/enemies/*.tscn`, `core/actors/enemy/enemy.gd` (`can_pool_as_ambient` :697-724, `make_elite` :882-905, `_tick_active_modules` :396-410), `core/systems/enemy_world/EnemyRepresentationPolicy.gd:46-52`, `core/systems/enemy_world/EnemyProxySimulation.gd:6-14,171-178`, `core/systems/enemy_world/EnemyWorld.gd:782-817` (`_ai_kind_from_actor`, `_flags_from_actor`), `autoload/EnemyIndex.gd:8-13`, `core/actors/player/player.gd:17-18,983-992` (contact damage), `core/actors/enemy/modules/*.gd`.

`EnemySpec.AI` enum: `CHASE=0, ORBIT=1, RANGED=2, CHARGE=3, BOMBER=4, SUMMONER=5, SPLITTER=6, TACTICAL=7, LEECH=8, HERALD=9, SNIPER=10`.

**Spec defaults** (`EnemySpec.gd`; every value below not listed in a `.tres` is one of these): `ai CHASE`, `max_hp 10`, `speed 75`, `knockback_decay 2200`, followers `1–1` (+3 elite), orbit `radius 150 / turn 2.0`, ranged `preferred_range 240, tolerance 60, shoot_every 1.6, projectile_speed 320, projectile_damage 5, lifetime 3, strafe 0.8`, charge `trigger 260, windup 0.5, speed 520, duration 0.25, cooldown 2.8`, bomber `trigger 70, radius 100, damage 12, explode_on_death false`, summoner `every 4.5, count 1–2, radius 160`, splitter `count 2–3, max_generation 2, second 4–4, base_scale 2.0, scale/gen 0.5, hp/gen 0.45, speed/gen 1.55, elite +1 gen, elite scale ×2`, leech `every 0.75, amount 1`, tactical `retreat_hp 0.35, cover 220 px`, herald `pulse 2.8 s, radius 220, ally speed ×1.35 for 1.8 s, drains 1 Follower`, sniper `range 900, windup 0.9, cooldown 3.0, damage 14, beam 2200×26, move ×0.15 in windup, track 2.4 rad/s`, drops `chance 0.25, rarity 0–0, elite_rarity_bonus 1, amount 1`, elite `hp ×1.6, speed ×1.15, spawn_chance_cap 1.0, ai_override −1 (keep)`.

**Contact damage is player-side**: every enemy body overlapping the player's hurtbox deals `player.contact_damage 10 × swarm_mul × ThreatDirector.enemy_damage_mul` every `contact_tick 0.5 s`, `swarm_mul = min(2.25, 1 + (touching − 1) × 0.35)` (`player.gd:983-992`). Projectiles (`EnemyShooter.gd:375,393`) multiply `projectile_damage` by `enemy_damage_mul`; the shooter module runs for RANGED, TACTICAL and HERALD.

**Proxy eligibility** (`EnemyRepresentationPolicy.is_proxy_eligible`): `world.get_ai_kind(handle) == 0 (CHASE)` **and** `(flags & (ELITE|CRITICAL|OBJECTIVE|TUTORIAL|NEVER_RETIRE|SPECIAL)) == 0`. `ai_kind` comes from the actor's `_get_active_ai()` (so an elite override to TACTICAL/CHARGE also disqualifies), flags from `is_elite`, boss groups (CRITICAL|NEVER_RETIRE), `objective_required`, `tutorial_actor`/`opening_scripted` (TUTORIAL), `never_cull`, and any `special_spawn_kind` meta (SPECIAL — summons, splits, beats, interior, boss adds). `EnemyProxySimulation` only advances handles that are DATA_ONLY, CHASE and carry none of the same flags.

**Pool eligibility** (`EnemyActor.can_pool_as_ambient`): needs a scene path, no `special_spawn_kind`, not boss/miniboss/objective/tutorial/never_cull, `simulation_lod_enabled`, and base `spec.ai ∈ {CHASE, SPLITTER, LEECH}` (elite status ignored).

| spec id (`.tres`) | scene | name | AI | HP | speed | Followers (min–max, +elite) | attack / special | drop chance | drop rarity | elite HP×/spd× | elite AI override | `elite_spawn_chance_cap` | proxy-eligible | poolable |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| enemy_grunt (`EnemySpec_Grunt`) | EnemyGrunt.tscn | Grunt (default) | CHASE | 10 | 75 | 1–1 (+3) | contact | 0.25 | 0–0 | 1.6 / 1.15 | TACTICAL (7) | 1.0 | **yes** (non-elite) | yes |
| enemy_runner | EnemyRunner.tscn | Runner | CHASE | 8 | 135 | 1–2 (+3) | contact; as elite → CHARGE (windup 0.45, speed 620, dur 0.22, cd 2.6) | 0.12 | 0–1 | 1.35 / 1.25 | CHARGE (3) | 1.0 | **yes** (non-elite) | yes |
| enemy_brute | EnemyBrute.tscn | Brute | CHASE | 55 | 55 | 2–3 (+3) | contact | 0.25 | 0–1 | 1.6 / 1.15 | keep | 1.0 | **yes** (non-elite) | yes |
| enemy_orbiter | EnemyOrbiter.tscn | Orbiter | ORBIT | 14 | 82 | 2–3 (+3) | contact; orbit radius 190, turn 2.6 | 0.16 | 0–1 | 1.5 / 1.12 | keep | 1.0 | no | no |
| enemy_spitter | EnemySpitter.tscn | Spitter | RANGED | 16 | 70 | 2–3 (+3) | projectile 5 dmg every 1.4 s, range 260 (+contact) | 0.25 | 0–1 | 1.6 / 1.15 | TACTICAL | 1.0 | no | no |
| enemy_charger | EnemyCharger.tscn | Charger | CHARGE | 22 | 92 | 3–4 (+3) | contact; charge trigger 280, windup 0.55, speed 650, dur 0.28, cd 2.8 | 0.20 | 1–2 | 1.6 / 1.1 | keep | 1.0 | no | no |
| enemy_bomber | EnemyBomber.tscn | Bomber | BOMBER | 12 | 110 | 2–4 (+3) | explodes at 80 px: 12 dmg in 105 px radius; also on death | 0.18 | 1–2 | 1.6 / 1.15 | keep | 1.0 | no | no |
| enemy_leech | EnemyLeech.tscn | Leech | LEECH | 18 | 95 | 3–5 (+3) | contact; drains 1 Follower every 0.75 s while attached | 0.24 | 1–2 | 1.6 / 1.1 | TACTICAL | 1.0 | no | yes |
| enemy_herald | EnemyHerald.tscn | Herald | HERALD | 28 | 78 | 5–8 (+4) | projectile 3 dmg every 2.2 s, range 285; pulse every 2.8 s in 220 px: allies ×1.35 speed 1.8 s, player −1 Follower | 0.35 | 2–3 | 1.7 / 1.1 | TACTICAL | 1.0 | no | no |
| enemy_summoner | EnemySummoner.tscn | Summoner | SUMMONER | 10 | 75 | 2–3 (+3) | summons 1–3 minions every 4.5 s in 160 px (`EnemySummoner.gd`: max 6 alive per summoner, lifetime 10 s) | 0.30 | 0–2 | 1.6 / 1.15 | keep | 1.0 | no | no |
| enemy_summoned_minion | EnemySummonedMinion.tscn | Summoned Minion | CHASE | 5 | 160 | 0 | contact | 0.0 | — | 1.6 / 1.15 | keep | 1.0 | no (`special_spawn_kind = "summon"` → SPECIAL) | no |
| enemy_sniper | EnemySniper.tscn | Sniper | SNIPER | 40 | 120 | 1–2 (+3) | line shot 10 dmg, range 2200, windup 0.9, cd 2.7, beam 2400×34, move ×0.25 in windup, track 0.45 rad/s | 0.20 | 1–2 | 1.6 / 1.15 | TACTICAL | 1.0 | no | no |
| enemy_splitter (`EnemySpec_SplitterSlime`) | EnemySplitter.tscn | Splitter | SPLITTER | 60 | 44 | 0–1 (+2) | contact; splits into 2, then 4 (gen 2), HP ×0.45/gen, speed ×1.55/gen, elite inherits (+1 gen, ×2 scale) | 0.10 | 0–1 | 1.8 / 1.1 | keep | **0.003** | no | yes |
| boss_arcanist | (BossArena) | Arcanist | RANGED | 150 | 84 | 10–14 (+3) | range 340, `shoot_every 999` (boss script drives attacks) | 1.0 (2–3 items) | 1–2 | 1.6 / 1.15 | keep | 1.0 | no (boss → CRITICAL) | no |
| boss_bulldozer | (BossArena) | Bulldozer | CHARGE | 180 | 72 | 10–14 (+3) | charge trigger 320, windup 0.55, speed 780, dur 0.36, cd 2.2 | 1.0 (2–3 items) | 1–2 | 1.6 / 1.15 | keep | 1.0 | no | no |
| enemy_containment_construct | (opening sequence) | Lattice Construct | CHASE | 18 | 68 | 0 | contact | 0.0 | — | — | keep | 1.0 | no when tagged opening/tutorial (TUTORIAL flag) | no |
| enemy_opening_officer | (opening sequence) | Containment Officer | CHASE | 22 | 76 | 0 | contact | 0.0 | — | — | keep | 1.0 | no when tagged opening/tutorial | no |

Elite promotion (`make_elite`): HP ×`elite_hp_mult`, speed ×`elite_speed_mult`, `max_slides = 8`, forced scheduler tier 0, sprite tint `elite_tint` (default (1.0, 0.85, 0.25)), Splitter scale ×2. Elites are excluded from stale culling and simulation demotion (`EnemySimulationScheduler._is_protected`).

**Population caps (`autoload/EnemyIndex.gd`)**

| export | default | meaning |
|---|---|---|
| `cell_size` | 64.0 | spatial hash cell |
| `special_population_cap` | 72 | total alive "special" (any `special_spawn_kind`) |
| `summoned_population_cap` | 36 | kind `summon` |
| `split_population_cap` | 48 | kind `split` |
| `boss_add_population_cap` | 24 | kind `boss_add` |
| `beat_population_cap` | 24 | kind `beat` (EncounterDirector members) |
| (other kinds, e.g. `interior`) | fall back to `special_population_cap` | `_special_kind_cap` |

**Ambient spawn table (`data/enemies/spawn/SpawnTable_Default.tres`; `EnemySpawnTable.max_alive_total` default 180, not overridden)**

| scene | weight | start_time (s) | max_alive | elite_chance |
|---|---|---|---|---|
| EnemyGrunt | 6.0 | 0 | 80 | 0.005 (count 1–2 per pick) |
| EnemyRunner | 2.6 | 0 | 40 | 0.006 |
| EnemyOrbiter | 2.0 | 30 | 30 | 0.010 |
| EnemySpitter | 1.8 | 60 | 28 | 0.012 |
| EnemyCharger | 1.2 | 90 | 18 | 0.018 |
| EnemyBomber | 1.1 | 120 | 16 | 0.020 |
| EnemyLeech | 0.7 | 150 | 8 | 0.030 |
| EnemyHerald | 0.55 | 210 | 6 | 0.035 |
| EnemySummoner | 0.6 | 180 | 7 | 0.033 |
| EnemySniper | 0.28 | 90 | 2 | 0.200 |
| EnemySplitter | 0.32 | 210 | 4 | 0.001 |

**Segment 1 tutorial stages (`core/systems/spawner/Segment1SpawnProfile.gd`)**

| stage | interval | cap | batch | roster | grace | threat/elite scaling |
|---|---|---|---|---|---|---|
| BEFORE_SYNTHESIS | 999 | 0 | 0 | — | 0 | no |
| INITIAL_CONTAINMENT | 4.6 | 4 | 1 | Grunt | 2.0 | no |
| ARCHIVE | 3.8 | 6 | 1 | Grunt, Runner | 1.25 | no |
| COURTYARD | 3.25 | 8 | 1 | + Orbiter | 1.5 | no |
| SERVICE | 2.8 | 11 | 1 | + Spitter, Charger | 1.5 | no |
| OUTER_APPROACH | 2.15 | 15 | 2 | + Bomber | 1.0 | yes |
| EXIT_RITE | 1.35 | 20 | 2 | same | 0.25 | yes |

---

## 9. Threat & pressure knobs

### 9.1 `autoload/ThreatDirector.gd` exports

| export | default | meaning |
|---|---|---|
| `carry_per_segment` | 0.14 | baseline difficulty per segment beyond 1 (`carry = (seg−1)·0.14`) |
| `tut_heat_at_0 / _60 / _90 / _100` | 0.30 / 0.85 / 0.35 / 1.00 | segment-1 heat curve knots (resonance 0 / 0.6 / 0.9 / 1.0) |
| `heat_at_0 / _20 / _70 / _90 / _100` | 0.06 / 0.10 / 0.85 / 0.35 / 1.00 | segments 2+ heat curve knots |
| `dominance_window_sec` | 8.0 | kill-rate window |
| `dominance_target_kps` | 2.3 | kills/s at which dominance is neutral |
| `dominance_gain` | 0.05 | multiplier per kps above target |
| `dominance_min_mul / max_mul` | 0.92 / 1.08 | clamp on `dominance_mul` |
| `dominance_apply_after_resonance` | 0.30 | dominance ignored below this resonance |
| `gate_unseal_resonance` | 0.999 | resonance at which `gate_unsealed` flips |
| `REWARD_DECAY_POWER` | 0.6 | Overtime belief decay `1/(1+ot)^0.6` |
| `REWARD_DECAY_FLOOR` | 0.35 | minimum kill-reward multiplier in Overtime |
| `overtime_time_rate` | 0.008 | overtime per second after unseal |
| `overtime_kill_rate` | 0.035 | overtime per kill beyond the buffer (× dominance_mul) |
| `overtime_kill_buffer` | 55 | kills after unseal before kill overtime starts |
| `ot_elite_start / ot_elite_tau` | 0.00 / 1.8 | elite stage: `(1 − e^(−(ot−start)/tau)) · elite_bonus_from_overtime` |
| `ot_damage_start / _pow / _scale` | 1.60 / 1.22 / 0.34 | damage stage: `(ot−start)^pow · scale` added to damage mul |
| `ot_spawn_start / _pow / _scale` | 5.00 / 1.15 / 0.30 | spawn stage: divides spawn interval by `1 + (ot−start)^pow·scale` |
| `ot_hp_start / _pow / _scale` | 2.00 / 1.10 / 0.22 | HP stage added to HP mul |
| `evac_target_sec` | 60.0 | HUD countdown length |
| `evac_time_base_sec` | 95.0 | seconds of unseal time for pressure 1.0 |
| `evac_kill_weight` | 0.004 | pressure per excess kill |
| `hp_from_carry / hp_from_heat / hp_mul_cap` | 0.22 / 0.85 / 30.0 | `enemy_hp_mul = 1 + carry·0.22 + heat·0.85 + ot_hp_add` |
| `dmg_from_carry / dmg_from_heat / dmg_mul_cap` | 0.12 / 0.08 / 30.0 | `enemy_damage_mul = 1 + carry·0.12 + heat·0.08 + ot_dmg_add` |
| `spd_from_carry / spd_from_heat / spd_mul_cap` | 0.06 / 0.04 / 2.0 | `enemy_speed_mul = 1 + carry·0.06 + heat·0.04` |
| `spawn_mul_at_heat0 / _heat1` | 0.95 / 0.55 | base spawn-interval multiplier lerped by heat |
| `spawn_mul_min / spawn_mul_max` | 0.12 / 1.10 | clamp on `spawn_interval_mul` |
| `elite_bonus_from_heat` | 0.08 | `elite_bonus += heat·0.08` |
| `elite_bonus_from_overtime` | 0.65 | overtime elite stage ceiling |
| `elite_bonus_cap` | 0.95 | clamp on `elite_bonus` |
| `loot_bonus_from_segment / _heat / _overtime / loot_bonus_cap` | 0.25 / 1.20 / 2.50 / 6.0 | `loot_rarity_bonus = floor(clamp((seg−1)·0.25 + heat·1.2 + ln(1+ot)·2.5, 0, 6))` |
| `rite_spawn_factor` | 0.6 | spawn factor multiplier while the Exit Rite is channelled |
| `rite_elite_add` | 0.15 | elite bonus added while channelled |
| `power_contrast_lag_sec` | 25.0 | seconds enemy HP/damage multipliers are held after a power threshold |

Derived (`_recompute`): `heat = clamp(curve(resonance) × dominance_mul, 0, 1)` then phase-modified (§10); `threat (HUD) = carry·22 + heat·55 + ln(1+ot)·35` (× doctrine `threat_gain_mul` + `attempt_doctrine_threat_debt`); `apply_doctrine_pressure` multiplies carry/heat by `threat_gain_mul` and adds `debt/55` to heat.

### 9.2 `autoload/EnemySimulationScheduler.gd` exports

| export | default | meaning |
|---|---|---|
| `full_budget` | 32 | actors in full simulation tier |
| `mid_budget` | 32 | actors in mid tier |
| `assignment_interval` | 0.20 s | tier refresh cadence |
| `mid_group_count / far_group_count` | 3 / 7 | round-robin slices for mid/far ticking |
| `physics_pressure_ms` | 8.0 | flow-field load-shedding threshold |
| `use_spatial_bands` | true | distance caps fidelity |
| `full_distance_enter / exit` | 1200 / 1400 px | full-tier band with hysteresis |
| `mid_distance_enter / exit` | 1800 / 2100 px | mid-tier band |
| `rank_incumbent_bias` | 0.90 | incumbents ranked as if 0.9× closer (squared for full) |
| `adaptive_budgets` | true | pressure shrinks budgets |
| `budget_pressure_ms` | 14.0 | level-1 pressure threshold |
| `pressure_full_budget / pressure_mid_budget` | 12 / 24 | level-1 budgets |
| `pressure_engage_sec / pressure_release_sec / emergency_release_sec` | 0.5 / 2.0 / 5.0 | hysteresis timers |
| `pressure_release_distance_scale` | 0.75 | smart-actor physics release distance scale at level 1 |
| `emergency_pressure_ms` | 20.0 | level-2 threshold |
| `emergency_full_budget / emergency_mid_budget` | 8 / 16 | level-2 budgets |
| `emergency_release_distance_scale` | 0.6 | level-2 release scale |
| `normal_smart_release / reacquire` | 2600 / 2300 px | smart-archetype body-physics boundary |
| `pressure_smart_release / reacquire` | 1600 / 1400 px | level 1 |
| `emergency_smart_release / reacquire` | 1450 / 1250 px | level 2 |
| `noncontact_release_min_distance` | 640 px | never release ORBIT/RANGED/SUMMONER/TACTICAL/HERALD bodies closer than this |
| `severe_pressure_ms / severe_engage_sec` | 40.0 / 0.15 | fast path straight to level 2 |
| `PRESSURE_SMOOTHING_SEC` (const) | 0.25 | physics-ms smoothing |

### 9.3 `core/systems/enemy_world/EnemyRepresentationPolicy.gd` (plain vars, no exports)

| var / const | value | meaning |
|---|---|---|
| `HARD_BUDGET_CEILING` | 96 | absolute cap on materialized actors |
| `materialized_budget` | 64 | target materialized count |
| `activation_distance` | 480 px | proxies promote inside this |
| `deactivation_distance` | 640 px | materialized ambient demote beyond this |
| `max_promotions_per_step / max_demotions_per_step` | 4 / 4 | per-evaluate limits |
| `backlog_burst_multiplier` | 4 | demotion burst when over budget (up to 16/step) |
| `CHASE_AI_KIND` | 0 | only kind eligible for proxying |

`EnemyRepresentationManager.gd`: `enabled := false`, `decision_interval := 0.20` (script defaults). `EnemyProxySimulation.gd`: update Hz normal/pressure/emergency = 10 / 6 / 3, slice counts 6 / 8 / 12, `max_slices_per_advance 24`.

### 9.4 `core/systems/spawner/spawner.gd` exports

| export | default | meaning |
|---|---|---|
| `spawn_every / spawn_every_min / spawn_every_decay_per_min` | 0.90 / 0.22 / 0.04 s | tick interval, floor, decay per minute (× `ThreatDirector.spawn_interval_mul`, extra floor `0.35 × spawn_every_min`) |
| `spawn_radius / spawn_jitter` | 500 / 80 px | ring spawn position; 78 % chance to use a spawn socket in [max(260, r−2j), r+2.5j] |
| `max_alive` | 220 | fallback cap when no table (table default 180) |
| `batch_base / batch_per_min / batch_cap` | 2 / 0.45 / 8 | per-tick batch |
| `elite_min_time / elite_base_chance / elite_chance_per_min / elite_chance_cap` | 20 s / 0.00 / 0.012 / 0.85 | `chance = clamp(entry.elite + base + minutes·0.012 + ThreatDirector.elite_bonus, 0, 0.85)`, then `min(spec.elite_spawn_chance_cap)` |
| `ambient_pool_limit_per_scene / pool_warm_per_scene` | 32 / 6 | PoolManager limits; `POOL_WARM_FRAME_BUDGET_USEC 2500` |
| `max_concurrent_elites` | 24 | no promotions once `EnemyIndex.elite_alive_count()` reaches this |
| `max_spawn_batch_per_tick` | 4 | construction budget per tick (debt carried, cap `batch_cap×2`) |
| `boss_suppress_radius / boss_spawn_interval_mul / boss_max_alive_mul / boss_batch_mul` | 1050 px / 3.25 / 0.35 / 0.55 | near a `boss_like` node |
| `cull_enabled / cull_threshold_ratio / cull_interval / cull_max_per_tick / cull_refill_grace / cull_keep_chunks / cull_distance_px_fallback` | true / 0.90 / 0.75 s / 8 / 0.90 s / 2 / 3600 px | distance culling |
| `stale_cleanup_interval / stale_min_distance_px / stale_stationary_seconds / stale_max_per_tick / stale_motion_epsilon_px` | 0.80 s / 1700 px / 9.0 s / 10 / 22 px | stale culling (elites exempt) |
| `FORCE_SPAWN_PER_FRAME` (const) | 12 | dev force-spawn drain |

### 9.5 `core/systems/encounters/EncounterBeats.gd` CATALOG

| beat id | label | mode | distance | min_phase | cooldown (s) | members |
|---|---|---|---|---|---|---|
| charger_wedge | CHARGER WEDGE | flank | 900 | disturbance | 90 | 6 × Charger (1 elite at apex) |
| shield_wall | SHIELD WALL | ahead | 760 | disturbance | 120 | 4 × Brute + 3 × Spitter |
| sniper_crossfire | CROSSFIRE | around | 1400 | disturbance | 150 | 2 × Sniper at (700, ±1212.4) |
| summoner_nest | NEST | off_route | 1100 | disturbance | 180 | 1 × Summoner + 2 × Herald |
| hunter | HUNTER | off_route | 1000 | disturbance | 100 | 1 × elite Runner |
| bomber_carpet | BOMBER CARPET | ahead | 640 | ascension | 120 | 6 × Bomber |
| leech_ring | LEECH RING | around | 520 | ascension | 140 | 8 × Leech on a 520 px ring |

`PHASE_ORDER = [recon, disturbance, ascension, collapse]`. Members spawn via `spawner.spawn_beat_member` as `special_spawn_kind "beat"` (cap 24).

**`EncounterDirector.gd` exports**

| export | default | meaning |
|---|---|---|
| `enabled` | true | |
| `first_beat_delay` | 45 s | |
| `interval_min / interval_max` | 60 / 90 s | cadence between beats |
| `max_concurrent` | 1 | |
| `min_placed_fraction` | 0.5 | beat aborts if fewer members find ground |
| `rite_specialist_beats` | [sniper_crossfire, charger_wedge] | sent once on rite channel rising edge |
| `escalation_beat_delay` | 10 s | next beat within this after a phase escalation |

Never schedules during a tutorial stage or once `gate_unsealed`; never repeats `_last_beat_id`.

### 9.6 `core/systems/world/CursedVault.gd` exports

| export | default |
|---|---|
| `approach_radius` | 320 px (announce) |
| `open_radius` | 64 px |
| `open_time` | 3.0 s (progress drains at 0.5× when outside) |
| `reward_rarity_min / max` | 4 / 5 (drop context source `vault`, rank 1) |
| `guarantee_manifestation` | true |
| `cost_beats` | [hunter, charger_wedge] |

Placed by `SegmentProcBuilder._spawn_cursed_vault` from segment 2 at the reward chunk farthest from start.

### 9.7 `autoload/HitFeel.gd` exports

| export | default |
|---|---|
| `hit_stop_enabled / camera_punch_enabled` | true / true |
| `stop_scale` | 0.05 (Engine.time_scale during a stop) |
| `stop_ms` | crit 45, elite 30, kill 60, melee 35 (longest wins) |
| `min_stop_interval_ms` | 120 |
| `punch_px` | melee 9.0, ranged 3.5, magic 6.0, kill 6.0, hurt 12.0 |
| `punch_decay` | 16.0 (px per 1/60 s, wall-clock) |
| `punch_max_px` | 18.0 |

Both respect `accessibility/reduced_motion`.

### 9.8 `core/systems/world/ExitRite.gd`

| export | default | meaning |
|---|---|---|
| `radius` | 168 px | channel circle |
| `hold_time` | 20.0 s | × `Global.attempt_exit_hold_mul` (default 1.0, clamped 0.25–2.0) at `_ready` |
| `lapse_drain_rate` | 0.45 | fraction of fill rate drained while outside |
| `lapse_grace` | 1.5 s | before draining starts |
| `death_progress_kept` | 0.6 | fraction kept on death |
| `channel_regen_per_sec` | 2.6 HP/s | mending while inside |
| `channel_regen_max_hp_pct` | 0.012 | + max HP × this per second |
| `locked / narrative_mode / hide_location_while_locked / revealed` | true / false / false / true | |
| `backlash_push / backlash_invuln` | 150 px / 0.4 s | locked-rite rejection (1.5 s debounce) |

`BURST_STAGES` (hold fraction → `spawner.spawn_burst(n × rite_burst_count_mul)`): (0.10, 2), (0.26, 3), (0.42, 4), (0.58, 5), (0.72, 6), (0.85, 8), (0.94, 10).

`AUTOMATIC_PULSES` (fired at each of the three archive seals): radius/force/stun/heal/invuln = (420, 650, 0.15, 0.15, 0), (500, 850, 0.35, 0.25, 0), (620, 1100, 0.60, 0.35, 5.0). Climax pulse on completion = last pulse with radius ×1.5 and stun ≥ 1.0. `MANUAL_PULSE` (safeguard, `interact` key): (420, 700, 0.20, 0.10, 0). Safeguard capacity 3 (doctrine rule `rite_safeguard_capacity`), sources: wardstones and secondaries (`SegmentProcBuilder.register_rite_safeguard_source`).

---

## 10. Segment phases

Source: `autoload/ThreatDirector.gd:438-459` (`_recompute`), `:287-294` (`set_segment_phase`); `core/systems/world/SegmentProcBuilder.gd:123,155-160,189-190,444-445,481-508`; `core/systems/world/Level1Builder.gd:1495-1510`.

| phase | heat adjustment | `phase_spawn_factor` (multiplies spawn interval) | `phase_elite_add` |
|---|---|---|---|
| recon | `heat ×= 0.72` | 1.15 | 0 |
| disturbance | `heat = max(heat, 0.32)` | 0.78 | +0.03 |
| ascension | `heat = max(heat, 0.48)` | 0.68 | +0.05 |
| collapse | `heat = max(heat, 0.85)` | 0.55 | +0.12 |
| (+ rite channelling) | — | × `rite_spawn_factor 0.6` | + `rite_elite_add 0.15` |

What moves the phase:

| trigger | phase | file |
|---|---|---|
| Segment start / `reset_run_state` | recon | `SegmentProcBuilder._ready`, `ThreatDirector._on_segment_changed` |
| Primary objective activated | disturbance (+ `spawn_burst(5)`) | `SegmentProcBuilder._on_primary_activated` |
| Primary objective completed | ascension (+0.18 resonance, `spawn_burst(7)`); collapse if resonance ≥ 0.999 | `_on_primary_completed` |
| Resonance ≥ 0.999 (tick or `grant_resonance`) or ≥ 1.0 in `_process` | collapse | `_process`, `grant_resonance` |
| Segment 1 spawn stage COURTYARD / SERVICE | disturbance | `Level1Builder.STAGE_PHASE` |
| Segment 1 OUTER_APPROACH | ascension | same |
| Segment 1 EXIT_RITE | collapse | same |
| Segment 1 earlier stages | recon | same (default) |

`EncounterDirector` reads `ThreatDirector.segment_phase` to gate beats and fires a freshly-unlocked beat within `escalation_beat_delay` on escalation.

---

## 11. Player baseline

Sources: `data/Stats.gd`, `data/player_base_stats.tres`, `data/styles/*.tres`, `core/actors/player/player.gd:14-75` (exports), `core/actors/player/CombatStyleTuning.gd`, `core/actors/player/PlayerDashState.gd`.

| stat | `Stats.gd` default | `player_base_stats.tres` override |
|---|---|---|
| max_hp | 100.0 | — |
| armor | 0.0 | — |
| move_speed | 200.0 | **100.0** |
| power | 0.0 | — |
| haste | 0.0 | — |
| luck | 0.0 | — |

Style adds (`data/styles/`): Melee hp +15, armor +4, speed −5, power +0.06, haste −0.02; Ranged speed +10, power +0.08, haste +0.05, luck +0.05; Magic hp −10, power +0.10, haste +0.10, luck +0.08.

| `player.gd` export | default |
|---|---|
| `speed` (overwritten by stats) / `max_hp` | 300 / 100 |
| `contact_damage / contact_tick` | 10 / 0.5 s (damage the player takes per touching-enemy tick) |
| `base_weapon_damage` | 12.0 |
| `melee_cooldown / ranged_cooldown / magic_cooldown` | 0.30 / 0.22 / 0.40 s |
| `melee_regen_flat_per_sec / melee_regen_bonus_hp_pct_per_sec / melee_regen_delay_after_damage` | 0.35 / 0.004 / 1.25 s |
| `melee/ranged/magic_lifesteal_pct` | 0.020 / 0.008 / 0.006 |
| `melee/ranged/magic_lifesteal_cap_max_hp_per_sec` | 0.060 / 0.030 / 0.025 |
| `death_follower_cost` | 10 (fallback; `Global.compute_respawn_cost` normally wins) |
| `respawn_invuln_time / respawn_phase_time / respawn_speed_mul` | 2.0 s / 2.0 s / 1.35 |

`CombatStyleTuning`: `MELEE_DAMAGE_MULT 1.25`, `MAGIC_DAMAGE_MULT 1.55`, `RANGED_DAMAGE_MULT 1.0`. Attack damage = `base_weapon_damage × style_mult × power_mul × (1.5 if lucky crit)`.

`PlayerDashState`: `DISTANCE 160 px`, `DURATION 0.20 s` (speed 800 px/s, not scaled by move speed), `COOLDOWN 1.6 s` (not scaled by haste), `IFRAME_GRACE 0.08` (i-frames 0.28 s), `BUFFER 0.12 s`, `REPORT_EPSILON 0.05`.

Stat order in `recompute_run_stats`: base → race → style → permanent augments → attempt modifiers → belief power → inventory `sum_mods` → sets → item effects → manifestations → burden/slot multipliers → NEG archetypes → doctrine `max_hp_mul` → `run_luck`.

---

## 12. Followers & Resonance

Sources: `autoload/global.gd:329-354` (`followers`, `transaction_followers`), `:802-806`, `:1062-1084`, `:1912-1929`, `:1936-1976`; kill paths `core/actors/enemy/modules/EnemyLifecycle.gd:81-105`, `core/systems/enemy_world/EnemyCombatService.gd:95-129`; other sites from `grep transaction_followers`.

**Follower gains**

| source | amount | file |
|---|---|---|
| Enemy kill (`combat_influence`) | `randi(spec.follower_reward_min..max)` + `elite_follower_bonus` if elite; +1 with `extra_follower_chance(luck)`; +1 with Cult chance; × `ThreatDirector.overtime_reward_multiplier()` (min 1) | `EnemyLifecycle.gd`, `EnemyCombatService.gd` |
| Boss arena clear | +25 (`bonus_followers_on_clear`) | `scenes/world/events/BossArena.gd:39` |
| Miniboss arena clear | +8 | `scenes/world/events/MiniBossArena.gd:40` |
| Segment-1 assistant commitment / Bren | tops up to 1 Follower | `Level1Builder.gd:1092,1464` |
| Tithe Rhythm pair | returns the spent Follower on a kill | `effects/manifestations/pairs/TitheRhythm.gd` |
| Dev grant | 200 (`MainMenu.gd:272`), overlay `dev_grant` | UI |

**Follower spends / losses**

| sink | amount | file |
|---|---|---|
| Reconstruction (death) | `max(ceil((10 + (seg−1)·2) · 1.7^deaths_this_segment), ceil(followers · 0.20))` | `Global.compute_respawn_cost:1912-1922` |
| Vendor buy | `compute_item_value × buy_multiplier(luck)` where value = `((26 + 18r + 2.5r²) + progress_value) × lerp(0.90, 1.40, |pct|) + stat_value + scripted_value_weight`, × 1.15 for set pieces; sell pays `floor(value × 0.55 × sell_multiplier)` | `global.gd:1936-1976`, `HubShop.gd:1335` |
| Vendor refresh | `clamp(3 · 1.75^n, 3, 999)` | `HubShop.gd:75-100,1357` |
| Wager Shrine | tiers OFFERING 8 (rarity 3–5, odds 0.85), PLEDGE 22 (5–7, 0.62), COVENANT 55 (7–10, 0.40); `seconds_per_tier 2.2` | `WagerShrineObjective.gd:26-28,121` |
| Manufactured Witness doctrine | −100 once per segment, +25 threat debt, survive at 50 % HP | `global.gd:1062-1084` |
| Leech | −1 every 0.75 s while attached | `EnemyLeech.gd:59` |
| Herald pulse | −1 per 2.8 s pulse if player within 220 px | `EnemyHerald.gd:88` |
| Tithe Bones curse | 22 per full max-HP of damage taken | `TitheBonesCurse.gd` |
| Tithe Furnace / Tithe Rhythm / Debt Collector | 1 per trigger (Furnace refuses below reconstruction cost) | manifestation scripts |

`followers` setter floors at 0; `transaction_followers` emits `followers_transaction(old, change, new, reason, context, show_feedback, allow_aggregate)`. Belief power: `min(0.15, 0.01·√followers)`.

**Resonance (segments 2+, `SegmentProcBuilder.gd:7-30,155-195`)**

| export / rule | value |
|---|---|
| `resonance_per_kill / per_elite_kill` | 0.0010 / 0.0040 (buffered) |
| `resonance_per_item_rarity` | 0.0015 × rarity on `pickup_fly_to_equip` (buffered) |
| `resonance_per_sec` | 0.00342 ambient — **only after the primary objective completes**; × `resonance_early_boost_mul 1.20` fading over `resonance_early_boost_seconds 30` |
| `resonance_bonus_cap_per_sec` | 0.0030 — buffered kill/item resonance drains at most this fast |
| `primary_completion_resonance` | 0.18 immediate |
| Wardstone attuned | +0.06 immediate (+1 rite safeguard) |
| Secondary objective | +0.05 immediate (+1 safeguard, doctrine secondary rolls) |
| Miniboss clear | +0.18 (`MiniBossArena.grant_resonance_on_clear`) |
| Boss clear | +1.0 |
| `resonance_tick_interval` | 0.25 s |
| `gate_marker_reveal_resonance` | 0.75 |
| Gate unlock | primary done ∧ resonance ≥ 0.999 ∧ boss/miniboss conditions; public bar held at ≤0.998 until conditions met |

**Resonance (segment 1, `Level1Builder.gd:28-42,128`)**: `resonance_per_sec 0.00025`, `per_kill 0.002`, `per_elite_kill 0.008`, `per_item_rarity 0.0015`, milestones synthesis 0.10, first confrontation 0.12, wardstone 1 0.17, assistant 0.12, security clear 0.12, wardstone 2 0.17, final checkpoint 0.13, secondary 0.02.

`ThreatDirector.gate_unseal_resonance = 0.999` flips `gate_unsealed` from `RunEvents.resonance_changed`; Overtime, EVAC pressure and the kill-reward decay start from that moment.

---

## How to regenerate

Re-read these files (all paths relative to the project root) and rebuild the tables above:

- Items / rarity / polarity: `data/items/defs/**/*.tres`, `data/items/ItemData.gd`, `data/items/ItemInstance.gd`, `data/items/BagInventory.gd`, `data/items/Inventory.gd`, `core/systems/items/RarityMath.gd`, `core/systems/items/ItemGenerator.gd`, `core/systems/items/ItemDropContext.gd`, `core/systems/items/LuckResolver.gd`, `core/systems/items/BurdenSnapshot.gd`, `core/systems/items/BurdenResolver.gd`, `core/systems/items/ItemEffectRunner.gd`, `effects/items/logic/curses/*.gd`, `autoload/global.gd` (`ITEMS_DIR`, `load_items_from_dir`, `pick_weighted_item_id`, `build_item_drop_context`, `roll_percent`, `curse_drop_bias`, `compute_*_value`, `compute_respawn_cost`, `follower_belief_power`, `transaction_followers`), `ui/components/InventorySlotView.gd` (`_rarity_color`).
- Sets: `data/sets/**/*.tres`, `data/sets/SetData.gd`, `data/sets/SetTier.gd`, `data/sets/SetRunner.gd`.
- Augments: `data/augments/*.tres`, `core/systems/augments/AugmentData.gd`, `core/systems/augments/AugmentRunner.gd`, `core/actors/player/player.gd` (`recompute_run_stats`), `core/actors/enemy/modules/EnemyLifecycle.gd`, `core/systems/enemy_world/EnemyCombatService.gd`.
- Manifestations: `data/manifestations/*.gd`, `core/systems/manifestations/ManifestationRunner.gd`, `core/systems/manifestations/ManifestationState.gd`, `effects/manifestations/logic/*.gd`, `effects/manifestations/pairs/*.gd`.
- Enemies: `core/actors/enemy/EnemySpec.gd`, `core/actors/enemy/EnemySpec_*.tres`, `scenes/world/enemies/*.tscn`, `core/actors/enemy/enemy.gd`, `core/actors/enemy/modules/*.gd`, `data/enemies/spawn/SpawnTable_Default.tres`, `core/systems/spawner/EnemySpawnEntry.gd`, `core/systems/spawner/EnemySpawnTable.gd`, `core/systems/spawner/Segment1SpawnProfile.gd`, `autoload/EnemyIndex.gd`, `core/systems/enemy_world/EnemyRepresentationPolicy.gd`, `core/systems/enemy_world/EnemyRepresentationManager.gd`, `core/systems/enemy_world/EnemyProxySimulation.gd`, `core/systems/enemy_world/EnemyWorld.gd`, `core/systems/enemy_world/EnemyWorldTypes.gd`, `data/enemies/EnemyDossierCatalog.gd`.
- Threat / pressure: `autoload/ThreatDirector.gd`, `autoload/EnemySimulationScheduler.gd`, `core/systems/spawner/spawner.gd`, `core/systems/encounters/EncounterBeats.gd`, `core/systems/encounters/EncounterDirector.gd`, `core/systems/world/CursedVault.gd`, `autoload/HitFeel.gd`, `core/systems/world/ExitRite.gd`, `core/systems/world/SegmentProcBuilder.gd`, `core/systems/world/Level1Builder.gd`.
- Player: `data/Stats.gd`, `data/StatDelta.gd`, `data/player_base_stats.tres`, `data/styles/*.tres`, `core/actors/player/player.gd`, `core/actors/player/CombatStyleTuning.gd`, `core/actors/player/PlayerDashState.gd`.
- Followers / Resonance sites: `grep -rn "transaction_followers\|grant_resonance\|_add_resonance\|gate_unseal_resonance" --include=*.gd` plus `ui/screens/HubShop.gd`, `core/systems/world/objectives/WagerShrineObjective.gd`, `scenes/world/events/BossArena.gd`, `scenes/world/events/MiniBossArena.gd`, `scenes/world/volumes/IndoorVolume.gd`.

## Known ambiguities (from the 2026-08-28 extraction)

- `EnemyBrute/Runner/Spitter.tscn` set node-level `drop_*` overrides, but `EnemyInit.gd:94-102` copies the spec's drop fields onto the node, so the scene overrides appear dead — spec values are documented as truth.
- `EnemyRepresentationManager.enabled` defaults to `false` in script; the game scene (`EnemyProxyRoot`) enables it at runtime. `ExitRite.hold_time` is scaled by `Global.attempt_exit_hold_mul` at runtime.
- All curse items carry positive flat `mods` (e.g. Ashen Ballast +34 armour) beside their NEG roll; recorded as authored, intent unknown.
- Rarity has no named tiers — only UI colours, including negative-rarity colours no generator can reach.
- Grunt's spec `display_name` is the default "Grunt" while `EnemyDossierCatalog` calls it "Containment Officer"; spawn table `max_alive_total` (180) differs from the spawner fallback `max_alive` (220).
- `LuckResolver.augment_quality_bonus` has no callers.
- The Sniper damage path (`EnemySniper.gd:321-351`) was not checked against the threat damage multiplier.

