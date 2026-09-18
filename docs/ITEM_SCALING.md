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

Not in this revision: accessory scripted effects still scale with
`rarity_effect_multiplier` (Task 3), set bonuses are still flat and read the
integer mean rank (Task 4), merge mass and prices are unchanged (Task 5).
Prices do move slightly because `compute_item_value` reads the flat stats.
