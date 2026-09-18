# Item stat progression (balance revision 2)

Item stats grow along explicit, ID-keyed profiles in
`data/items/item_scaling_v2.json`, evaluated by `core/systems/items/ItemScaling.gd`.
The profile gives an item's TOTAL flat contribution as a function of its
effective rank `r = max(0, rarity) + clamp(upgrade_meter, 0, 0.999999)`; the
existing roll is applied once afterward by the stat pipeline, so nothing
scales twice. The same evaluator produces runtime stats
(`ItemInstance._recompute_flat_mods`), the tooltip's stats and its "next rank"
line, comparison previews (they read `rolled_mods`) and, through the values
those carry, shop prices.

Channels, per stat, exactly one per item:

- `anchors`: values at ranks 0 / 1 / 6 / 15 / 30, linear between anchors,
  clamped below the first, the last segment's slope continued above 30.
- `rates` (movement, haste): `lerp(r0, r1, r)` below rank 1, then
  `r1 + (limit - r1) * (1 - exp(-(r - 1) / tau))`, an asymptote rather than
  the old rank-13 plateau.
- `flat`: added at every rank (Oakheart's -10 movement, Firestone's +0.01 haste).
- `effect` (accessories): the scripted-effect scale Task 3 will consume through
  `ItemScaling.accessory_factor`; evaluated now, read by no effect yet.

The numbers are the balance plan's V1 specification
(`docs/superpowers/plans/2026-09-17-item-set-exit-balance.md`, sections
3.2-3.5). R0 and R1 keep their pre-revision values; growth accelerates
through the R6-R30 region that the September captures showed as flat.
Curses keep their polarity, authored roll ranges and negative-effect
behaviour; only their positive flat package grows.

Validation happens once at startup (`Global._ready`, right after the item
database loads): unknown stats, a stat in two channels, missing or
non-finite anchors, a non-positive tau, or a bad file version reject the
whole file with an error, and every item then keeps the legacy formula
(`mods + rarity_base * (potency(r) - 1)`, rate stats capped), which is also
what an item without a profile uses. `ItemScalingV2Test` asserts that every
runtime item except `item_test` has a profile.

Saves are not migrated: rank, meter, roll, polarity, lock and Manifestation
are the truth, and derived stats are recomputed from them on every load for
the equipped set, the bag, the stash and the vendor shelf
(`ItemScaling.rebuild`) with no feeding and no rerolling. A save made under
revision 1 therefore adopts revision 2 on load while keeping its progress
exact; `SaveData.CURRENT_SAVE_VERSION` is unchanged because no persisted
field changed meaning. Rebuilding never writes to an `ItemData`: each
instance gets a fresh `StatDelta`.

Captures made while the profiles are live declare `balance_revision` 2,
`tuning_stages` `["items"]` and the profile file's SHA-256 as `tuning_hash`;
captures without a valid profile stay at revision 1 (see
`docs/BALANCE_RECORDER.md`). The laboratory baselines are
`docs/audits/2026-09-18-item-balance-baseline.md` (revision 1) and
`docs/audits/2026-09-19-item-balance-v2.md` (revision 2), both produced by
`ItemBalanceProbe` and rendered with `tools/sim/item_baseline_report.py`.

## Accessory effects (Task 3)

The four scripted accessories read `ItemScaling.accessory_factor` (the
profile's `effect` block) instead of the old potency multiplier:

- Oakheart: separate reduction `(0.04 + max(roll, 0) * 0.10) * E(r)`, E = 1 at
  R0 rising toward 1.4, clamped to 15%; a neutral R1 is 8 armour and a 4%
  shield (combined `100/108 * 0.96`), a deliberate early cut while
  armour-slot growth rises.
- Regeneration Ring: every second `(1.5 + 0.015 * max HP) * A(r) * max(0.10,
  1 + roll)` times a uniform 0.4..1.6 roll (mean 1), never more than 5% of
  max HP per tick, never on a dead player; A runs 0.9 / 1.0 / 1.2 / 1.5 /
  1.9 at R0 / 1 / 6 / 15 / 30 with a slow tail. Tests inject the roll
  through `roll_override`.
- Crusher's Ring: a positive roll is amplified by 1 at R0, 1.5 at R1 and
  toward 2.0 with rank; negative rolls keep their treatment; movement and
  secondary HP come from the stat profile.
- Firestone: burn per tick `0.045 * B(r) * (1 + max(roll, 0) * 0.6)` of the
  originating hit (which already carries Power, and is not multiplied by it
  again on either the pooled or the node path); magic only, Power `(0.06 +
  0.525 * roll) * B` and Haste rising smoothly from 0.02 through 0.03 at R1
  toward 0.05; B runs 2/3 / 1 / 1.2 / 1.5 / 1.8 with a slow tail.

`ItemEffectRunnerTest` pins these on the real runner, hit profile, status
service and a real magic impact.

## Measured effect of revision 2 (simulator, same seed and scenario)

`docs/audits/2026-09-19-build-simulator/rev1-vs-rev2.md` compares 296
identical builds under revision 1 and revision 2 item stats (before Task 3):
at seg9 and seg12 the deaths per fight fell from 0.31 and 0.34 to 0.06 and
0.04 and the median minimum HP rose from 37% and 56% to 64% and 82%, with
enemy HP removed up 7-19%; seg2 (rank 1, unchanged numbers) moved within
noise except for Oakheart's early cut (melee seg2 HP lost +11%). One
scripted scenario; see the simulator caveats.

Not in this revision: merge mass and prices are unchanged (Task 5). Prices
move slightly because `compute_item_value` reads the flat stats.

## Set scaling (Task 4)

Set bonuses read one profile of the set's **mean effective rank**
(`Inventory.get_set_rarity_average`: each of the six statistical slots'
rank plus its banked upgrade meter, accessories excluded), through
`SetScaling.profile(mean_rank)`, and every effect reads named channels
(`SetEffectBase.channel(name)`) instead of the old single potency:

| channel | drives | curve |
|---|---|---|
| `stat` | positive tier bonuses: HP, armour, Power, Luck | anchors 1 / 1 / 1.5 / 2.5 / 4 at R0 / 1 / 6 / 15 / 30, last slope continued |
| `damage` | every set payload's damage | anchors 1 / 1.5 / 2.025 / 2.85 / 4.2, last slope continued |
| `rate` | movement and Haste from tiers, the Overclock gains | 1 through R1, then `1 + 0.5 (1 - e^-(r-1)/12)`, never above 1.5 |
| `control` | radius, knockback, stun | the old potency at `min(r, 15)` |
| `density` | projectile and hit counts, inside their authored clamps | the old potency at `min(r, 15)` |
| `frequency` | rank-based trigger thresholds (the Mass Arrest bank) | the old potency at `min(r, 15)`; minimum cooldowns and action locks stay |

Drawbacks (Gravemarch's movement) stay fixed. Each channel is applied once
per tier and once per effect; `damage` is never combined with potency. So at
mean R15 Gravemarch's 2-piece is +45 HP and its 2+6-piece armour 8.75; the
R15 slam lands exactly 2.85 times the R0 slam; Lattice's Index Commit and
the ranged Verdict reach their authored maximum counts (3 x 7 bullets, 3 + 3
x 4 impacts, 22 shrapnel) at R15 and never grow past them; the bank
threshold stops falling at R15 and never under 60, and the slam's own
credited damage cannot start a second Verdict inside the 2.25 s internal
cooldown. A fractional feed updates the live effects in place (same nodes,
bank and cooldown untouched). `SetScalingV2Test` pins all of this through
the real inventory feed, `SetRunner`, `weapon_fired`, `damage_dealt` and
`enemy_killed` paths; `SetRunnerTest` still passes unchanged at R0.

The Run Sheet tier text names the R0 numbers and says they grow; the item
tooltip's "Set strength" comparison shows the `damage` channel before and
after the candidate piece.

Captures from this build carry `tuning_stages` `["items", "sets"]`.
