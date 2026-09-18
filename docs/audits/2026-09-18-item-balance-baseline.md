# Item and encounter baseline: 2026-09-18 (balance revision 1, before any tuning)

Exported by `tools/tests/ItemBalanceProbe.tscn` (`PROBE_OUT=docs/audits/2026-09-18-item-balance-baseline.json`) from the current production formulas on the human race, ranged style, neutral positive rolls, no Manifestations, augments, doctrine or Ascension rules, segment 5. Tuning hash: `empty` (no tuning profile exists yet). These are laboratory ranks, not natural rank-to-segment mappings. Nothing was changed to produce them; they are the baseline the balance plan's later tasks compare against.

## Constant-EHP fixture through the real damage path

HP 200, armour 50, one other damage-taken multiplier 0.80, one ordinary 50 raw hit with evasion, invulnerability and healing disabled: observed HP loss **26.6667**, constant EHP **375.0**. Formula: HP * (1 + max(armor,0)/100) / product(other damage-taken multipliers); evasion, invulnerability and healing reported separately.

## Primary-hit damage by style at Power-item ranks (conduit_lens, neutral roll)

Base weapon damage 12; style multipliers melee 1.25, ranged 1.00, magic 1.55; luck 0, so no crit. Only the ranged R6 value is a landed hit (measured 15.6965 against the formula 15.6965, match: True); melee and magic are formula values.

| Power item rank | Power | Melee | Ranged | Magic |
|---:|---:|---:|---:|---:|
| 0 | 0.28 | 19.2 | 15.36 | 23.81 |
| 1 | 0.29 | 19.35 | 15.48 | 23.99 |
| 6 | 0.308 | 19.62 | 15.7 | 24.33 |
| 15 | 0.3299 | 19.95 | 15.96 | 24.73 |
| 30 | 0.3593 | 20.39 | 16.31 | 25.28 |

## Item flat contributions by rank (total from the item, before the roll)

Cells list the non-zero stats of `rolled_mods`; the value columns are `compute_item_value` at luck 0.

| Item | Slot | Set | R0 | R1 | R6 | R15 | R30 | R6.5 | Value R1 / R6 / R15 / R30 |
|---|---:|---|---|---|---|---|---|---|---|
| acc_firestone | 6 | - | haste 0.01, power 0.02 | haste 0.01, power 0.025 | haste 0.01, power 0.034 | haste 0.01, power 0.0449 | haste 0.01, power 0.0596 | haste 0.01, power 0.0347 | 62 / 222 / 794 / 2556 |
| acc_oakheart | 6 | - | armor 40, max_hp 20, move_speed -10 | armor 47.5, max_hp 25, move_speed -10 | armor 61.03, max_hp 34.02, move_speed -10 | armor 77.39, max_hp 44.93, move_speed -10 | armor 99.47, max_hp 59.65, move_speed -10 | armor 62.08, max_hp 34.72, move_speed -10 | 197 / 395 / 1012 / 2835 |
| conduit_actuators | 4 | conduit | 0 | haste 0.01 | haste 0.028 | haste 0.045 | haste 0.045 | haste 0.0294 | 49 / 233 / 891 / 2917 |
| conduit_charm | 5 | conduit | 0 | luck 0.005 | luck 0.014 | luck 0.0249 | luck 0.0396 | luck 0.0147 | 48 / 233 / 890 / 2917 |
| conduit_greaves | 2 | conduit | 0 | move_speed 5 | move_speed 14.02 | move_speed 22.5 | move_speed 22.5 | move_speed 14.72 | 50 / 237 / 898 / 2924 |
| conduit_heart | 0 | conduit | 0 | max_hp 10 | max_hp 28.05 | max_hp 49.86 | max_hp 79.3 | max_hp 29.45 | 53 / 246 / 914 / 2956 |
| conduit_lens | 3 | conduit | 0 | power 0.01 | power 0.028 | power 0.0499 | power 0.0793 | power 0.0294 | 49 / 234 / 892 / 2920 |
| conduit_plating | 1 | conduit | 0 | armor 1 | armor 2.804 | armor 4.986 | armor 7.929 | armor 2.945 | 51 / 240 / 903 / 2937 |
| curse_ashen_ballast | 1 | - | armor 34 | armor 37.5 | armor 43.82 | armor 51.45 | armor 61.75 | armor 44.31 | 136 / 311 / 901 / 2689 |
| curse_hollow_reliquary | 3 | - | power 0.22 | power 0.245 | power 0.2901 | power 0.3446 | power 0.4182 | power 0.2936 | 57 / 219 / 793 / 2559 |
| curse_jinxed_coin | 5 | - | luck 0.3 | luck 0.33 | luck 0.3841 | luck 0.4496 | luck 0.5379 | luck 0.3883 | 57 / 219 / 793 / 2559 |
| curse_leadfoot_vigil | 2 | - | move_speed 30 | move_speed 33 | move_speed 38.41 | move_speed 43.5 | move_speed 43.5 | move_speed 38.83 | 53 / 215 / 788 / 2550 |
| curse_slow_heart | 0 | - | max_hp 40 | max_hp 44.5 | max_hp 52.62 | max_hp 62.44 | max_hp 75.68 | max_hp 53.25 | 80 / 243 / 819 / 2586 |
| curse_sour_providence | 5 | - | luck 0.22 | luck 0.245 | luck 0.2901 | luck 0.3446 | luck 0.4182 | luck 0.2936 | 71 / 233 / 806 / 2571 |
| curse_starving_crown | 0 | - | max_hp 55 | max_hp 61 | max_hp 71.83 | max_hp 84.91 | max_hp 102.6 | max_hp 72.67 | 69 / 234 / 811 / 2581 |
| curse_tithe_bones | 1 | - | armor 26 | armor 29 | armor 34.41 | armor 40.96 | armor 49.79 | armor 34.83 | 132 / 306 / 893 / 2677 |
| gravemarch_bonekey | 5 | gravemarch | luck 0.015 | luck 0.02 | luck 0.029 | luck 0.0399 | luck 0.0546 | luck 0.0297 | 49 / 233 / 891 / 2917 |
| gravemarch_carapace | 1 | gravemarch | armor 1.5 | armor 1.675 | armor 1.991 | armor 2.373 | armor 2.888 | armor 2.015 | 53 / 238 / 895 / 2923 |
| gravemarch_censer | 3 | gravemarch | power 0.04 | power 0.0475 | power 0.061 | power 0.0774 | power 0.0995 | power 0.0621 | 51 / 236 / 894 / 2921 |
| gravemarch_clockjaw | 4 | gravemarch | haste -0.01 | haste -0.0075 | haste -0.003 | haste 0.0012 | haste 0.0012 | haste -0.0026 | 49 / 232 / 889 / 2915 |
| gravemarch_stompers | 2 | gravemarch | move_speed -4 | move_speed -3.5 | move_speed -2.598 | move_speed -1.75 | move_speed -1.75 | move_speed -2.528 | 50 / 233 / 889 / 2915 |
| gravemarch_vessel | 0 | gravemarch | max_hp 14 | max_hp 15.5 | max_hp 18.21 | max_hp 21.48 | max_hp 25.89 | max_hp 18.42 | 56 / 241 / 900 / 2928 |
| lattice_fingerprint | 5 | lattice | luck 0.02 | luck 0.025 | luck 0.034 | luck 0.0449 | luck 0.0596 | luck 0.0347 | 49 / 234 / 891 / 2918 |
| lattice_focusnode | 3 | lattice | power 0.03 | power 0.035 | power 0.044 | power 0.0549 | power 0.0696 | power 0.0447 | 51 / 235 / 892 / 2919 |
| lattice_pulsecoil | 0 | lattice | max_hp 8 | max_hp 9 | max_hp 10.8 | max_hp 12.99 | max_hp 15.93 | max_hp 10.94 | 53 / 237 / 895 / 2923 |
| lattice_shellplate | 1 | lattice | armor 1 | armor 1.125 | armor 1.351 | armor 1.623 | armor 1.991 | armor 1.368 | 51 / 236 / 893 / 2920 |
| lattice_strideframe | 2 | lattice | move_speed 8 | move_speed 9 | move_speed 10.8 | move_speed 12.5 | move_speed 12.5 | move_speed 10.94 | 52 / 236 / 894 / 2920 |
| lattice_tickspurs | 4 | lattice | haste 0.02 | haste 0.025 | haste 0.034 | haste 0.0425 | haste 0.0425 | haste 0.0347 | 50 / 234 / 891 / 2917 |
| ring_crusher | 7 | - | move_speed 35 | move_speed 39 | move_speed 46.22 | move_speed 53 | move_speed 53 | move_speed 46.78 | 80 / 242 / 815 / 2577 |
| ring_regeneration | 7 | - | max_hp 10 | max_hp 12.5 | max_hp 17.01 | max_hp 22.46 | max_hp 29.82 | max_hp 17.36 | 71 / 233 / 807 / 2572 |

## Sets with all six core members worn at one rank

Mean rank is the integer average `get_set_rarity_average` uses today (banked meters ignored); strength is `RarityMath.potency(mean)`; tier bonuses are flat and do not grow with rank.

| Set | Tier bonuses (flat) | R1 mean / strength / effects | R6 mean / strength / effects | R15 mean / strength / effects | R30 mean / strength / effects |
|---|---|---|---|---|---|
| conduit | 2: haste 0.06, move_speed 15; 4: none; 6: none | 1 / 1.5 / 2 | 6 / 2.402 / 2 | 15 / 3.493 / 2 | 30 / 4.965 / 2 |
| gravemarch | 2: armor 2, max_hp 18, move_speed -6; 4: power 0.02; 6: armor 1.5 | 1 / 1.5 / 2 | 6 / 2.402 / 2 | 15 / 3.493 / 2 | 30 / 4.965 / 2 |
| lattice | 2: move_speed 10, power 0.03; 4: haste 0.02; 6: haste 0.04, luck 0.02 | 1 / 1.5 / 2 | 6 / 2.402 / 2 | 15 / 3.493 / 2 | 30 / 4.965 / 2 |

## Attribution coverage observed by the recorder during the probe

Origins observed: native:ranged. Attributed share 1 of 15.6965 enemy HP removed; set origins observed: none. No set attack was fired by this probe; set root coverage is measured only in play or the controlled set-output probe.

## Notes

- Neutral positive rolls; no Manifestations, augments, doctrine or Ascension rules.
- Item flat values are ItemInstance.rolled_mods after _recompute_flat_mods (mods + rarity_base * (potency - 1)); the roll is applied later in the stat pipeline.
- Primary-hit damage is base_weapon_damage * style multiplier * (1 + Power) with luck 0 (no crit); only the ranged value is a landed hit, melee and magic are formula values.
- Set rows wear the set's six core items at the same rank; set effects run but no set attack was fired, so set origins are absent from attribution by construction.
- Health reconciliation during the probe: 0 unexplained checks (the fixture's direct HP sets are resynced by samples).
- A newly captured human baseline of real play with this recorder is still owed before tuning; this probe is the laboratory half of the baseline only.
