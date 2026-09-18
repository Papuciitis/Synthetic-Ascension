# Item and encounter baseline: 2026-09-19, item curves and accessory effects live (balance revision 2, tuning stages ['items'])

Exported by `tools/tests/ItemBalanceProbe.tscn` from the production formulas on the human race, ranged style, neutral positive rolls, no Manifestations, augments, doctrine or Ascension rules, segment 5. Tuning hash: `7bbd5d5448b9a95e3bdc300acc64fa7b47652e33366c34b0371ae1df6f0e8ded`. Laboratory ranks, not natural rank-to-segment mappings.

## Constant-EHP fixture through the real damage path

HP 200, armour 50, one other damage-taken multiplier 0.80, one ordinary 50 raw hit with evasion, invulnerability and healing disabled: observed HP loss **26.6667**, constant EHP **375.0**.

## Primary-hit damage by style at Power-item ranks (conduit_lens, neutral roll)

Base weapon damage 12; style multipliers melee 1.25, ranged 1.00, magic 1.55; luck 0, so no crit. Only the ranged R6 value is a landed hit (measured 19.5600 against the formula 19.5600, match: True); melee and magic are formula values.

| Power item rank | Power | Melee | Ranged | Magic |
|---:|---:|---:|---:|---:|
| 0 | 0.28 | 19.2 | 15.36 | 23.81 |
| 1 | 0.29 | 19.35 | 15.48 | 23.99 |
| 6 | 0.63 | 24.45 | 19.56 | 30.32 |
| 15 | 1.28 | 34.2 | 27.36 | 42.41 |
| 30 | 2.48 | 52.2 | 41.76 | 64.73 |

## Item flat contributions by rank (total from the item, before the roll)

| Item | Slot | Set | R0 | R1 | R6 | R15 | R30 | R6.5 | Value R1 / R6 / R15 / R30 |
|---|---:|---|---|---|---|---|---|---|---|
| acc_firestone | 6 | - | haste 0.01, power 0.02 | haste 0.01, power 0.025 | haste 0.01, power 0.08 | haste 0.01, power 0.2 | haste 0.01, power 0.42 | haste 0.01, power 0.0867 | 62 / 225 / 803 / 2578 |
| acc_oakheart | 6 | - | armor 6, max_hp 10, move_speed -10 | armor 8, max_hp 12, move_speed -10 | armor 12, max_hp 30, move_speed -10 | armor 20, max_hp 70, move_speed -10 | armor 32, max_hp 140, move_speed -10 | armor 12.44, max_hp 32.22, move_speed -10 | 93 / 271 / 880 / 2703 |
| conduit_actuators | 4 | conduit | 0 | haste 0.01 | haste 0.1421, max_hp 8 | haste 0.2881, max_hp 24 | haste 0.3946, max_hp 60 | haste 0.1529, max_hp 8.889 | 49 / 244 / 918 / 2968 |
| conduit_charm | 5 | conduit | 0 | luck 0.005 | luck 0.08, max_hp 8 | luck 0.2, max_hp 24 | luck 0.4, max_hp 60 | luck 0.0867, max_hp 8.889 | 48 / 240 / 911 / 2966 |
| conduit_greaves | 2 | conduit | 0 | move_speed 5 | max_hp 8, move_speed 18.63 | max_hp 24, move_speed 32.54 | max_hp 60, move_speed 41.43 | max_hp 8.889, move_speed 19.71 | 50 / 243 / 914 / 2962 |
| conduit_heart | 0 | conduit | 0 | max_hp 10 | max_hp 70 | max_hp 180 | max_hp 380 | max_hp 76.11 | 53 / 268 / 982 / 3111 |
| conduit_lens | 3 | conduit | 0 | power 0.01 | power 0.35 | power 1 | power 2.2 | power 0.3861 | 49 / 256 / 958 / 3066 |
| conduit_plating | 1 | conduit | 0 | armor 1 | armor 14 | armor 35 | armor 70 | armor 15.17 | 51 / 272 / 989 / 3116 |
| curse_ashen_ballast | 1 | - | armor 34 | armor 37.5 | armor 48 | armor 80 | armor 140 | armor 49.78 | 136 / 322 / 973 / 2884 |
| curse_hollow_reliquary | 3 | - | power 0.22 | power 0.245 | power 0.5 | power 1.25 | power 2.8 | power 0.5417 | 57 / 232 / 848 / 2702 |
| curse_jinxed_coin | 5 | - | luck 0.3 | luck 0.33 | luck 0.5, max_hp 8 | luck 0.9, max_hp 24 | luck 1.6, max_hp 60 | luck 0.5222, max_hp 8.889 | 57 / 228 / 824 / 2633 |
| curse_leadfoot_vigil | 2 | - | move_speed 30 | move_speed 33 | max_hp 8, move_speed 43.9 | max_hp 24, move_speed 55.04 | max_hp 60, move_speed 62.15 | max_hp 8.889, move_speed 44.77 | 53 / 221 / 803 / 2583 |
| curse_slow_heart | 0 | - | max_hp 40 | max_hp 44.5 | max_hp 95 | max_hp 205 | max_hp 430 | max_hp 101.1 | 80 / 262 / 883 / 2746 |
| curse_sour_providence | 5 | - | luck 0.22 | luck 0.245 | luck 0.4, max_hp 8 | luck 0.8, max_hp 24 | luck 1.4, max_hp 60 | luck 0.4222, max_hp 8.889 | 71 / 241 / 837 / 2642 |
| curse_starving_crown | 0 | - | max_hp 55 | max_hp 61 | max_hp 105 | max_hp 220 | max_hp 450 | max_hp 111.4 | 69 / 249 / 872 / 2737 |
| curse_tithe_bones | 1 | - | armor 26 | armor 29 | armor 40 | armor 68 | armor 118 | armor 41.56 | 132 / 320 / 961 / 2847 |
| gravemarch_bonekey | 5 | gravemarch | luck 0.015 | luck 0.02 | luck 0.07, max_hp 8 | luck 0.18, max_hp 24 | luck 0.36, max_hp 60 | luck 0.0761, max_hp 8.889 | 49 / 240 / 910 / 2964 |
| gravemarch_carapace | 1 | gravemarch | armor 1.5 | armor 1.675 | armor 18 | armor 46 | armor 92 | armor 19.56 | 53 / 284 / 1021 / 3179 |
| gravemarch_censer | 3 | gravemarch | power 0.04 | power 0.0475 | power 0.38 | power 1.1 | power 2.4 | power 0.42 | 51 / 258 / 964 / 3080 |
| gravemarch_clockjaw | 4 | gravemarch | haste -0.01 | haste -0.0075 | haste 0.0668, max_hp 8 | haste 0.1489, max_hp 24 | haste 0.2088, max_hp 60 | haste 0.0729, max_hp 8.889 | 49 / 240 / 910 / 2958 |
| gravemarch_stompers | 2 | gravemarch | move_speed -4 | move_speed -3.5 | max_hp 8, move_speed 1.782 | max_hp 24, move_speed 7.173 | max_hp 60, move_speed 10.62 | max_hp 8.889, move_speed 2.199 | 50 / 237 / 904 / 2950 |
| gravemarch_vessel | 0 | gravemarch | max_hp 14 | max_hp 15.5 | max_hp 85 | max_hp 230 | max_hp 490 | max_hp 93.06 | 56 / 276 / 1008 / 3168 |
| lattice_fingerprint | 5 | lattice | luck 0.02 | luck 0.025 | luck 0.1, max_hp 8 | luck 0.24, max_hp 24 | luck 0.48, max_hp 60 | luck 0.1078, max_hp 8.889 | 49 / 241 / 913 / 2970 |
| lattice_focusnode | 3 | lattice | power 0.03 | power 0.035 | power 0.3 | power 0.9 | power 2 | power 0.3333 | 51 / 253 / 951 / 3053 |
| lattice_pulsecoil | 0 | lattice | max_hp 8 | max_hp 9 | max_hp 55 | max_hp 150 | max_hp 310 | max_hp 60.28 | 53 / 260 / 966 / 3075 |
| lattice_shellplate | 1 | lattice | armor 1 | armor 1.125 | armor 10 | armor 26 | armor 52 | armor 10.89 | 51 / 261 / 963 / 3064 |
| lattice_strideframe | 2 | lattice | move_speed 8 | move_speed 9 | max_hp 8, move_speed 17.52 | max_hp 24, move_speed 26.21 | max_hp 60, move_speed 31.77 | max_hp 8.889, move_speed 18.19 | 52 / 243 / 912 / 2958 |
| lattice_tickspurs | 4 | lattice | haste 0.02 | haste 0.025 | haste 0.1136, max_hp 8 | haste 0.2115, max_hp 24 | haste 0.2828, max_hp 60 | haste 0.1208, max_hp 8.889 | 50 / 243 / 913 / 2962 |
| ring_crusher | 7 | - | move_speed 35 | move_speed 39 | max_hp 12, move_speed 49.56 | max_hp 36, move_speed 60.35 | max_hp 85, move_speed 67.23 | max_hp 13.33, move_speed 50.4 | 80 / 248 / 834 / 2620 |
| ring_regeneration | 7 | - | max_hp 10 | max_hp 12.5 | max_hp 24 | max_hp 55 | max_hp 110 | max_hp 25.72 | 71 / 236 / 821 / 2608 |

## Sets with all six core members worn at one rank

| Set | Tier bonuses (flat) | R1 mean / strength / effects | R6 mean / strength / effects | R15 mean / strength / effects | R30 mean / strength / effects |
|---|---|---|---|---|---|
| conduit | 2: haste 0.06, move_speed 15; 4: none; 6: none | 1 / 1.5 / 2 | 6 / 2.402 / 2 | 15 / 3.493 / 2 | 30 / 4.965 / 2 |
| gravemarch | 2: armor 2, max_hp 18, move_speed -6; 4: power 0.02; 6: armor 1.5 | 1 / 1.5 / 2 | 6 / 2.402 / 2 | 15 / 3.493 / 2 | 30 / 4.965 / 2 |
| lattice | 2: move_speed 10, power 0.03; 4: haste 0.02; 6: haste 0.04, luck 0.02 | 1 / 1.5 / 2 | 6 / 2.402 / 2 | 15 / 3.493 / 2 | 30 / 4.965 / 2 |

## Attribution coverage observed by the recorder during the probe

Origins observed: native:ranged. Attributed share 1 of 19.5600 enemy HP removed; set origins observed: none.

## Notes

- Neutral positive rolls; no Manifestations, augments, doctrine or Ascension rules.
- Item flat values are ItemInstance.rolled_mods after _recompute_flat_mods (ItemScaling profiles at balance revision 2, the legacy potency formula for items without a profile); the roll is applied later in the stat pipeline. effect_multiplier is the legacy potency scale; effect_factor is the accessory effect scale the scripted effects read at revision 2.
- Primary-hit damage is base_weapon_damage * style multiplier * (1 + Power) with luck 0 (no crit); only the ranged value is a landed hit, melee and magic are formula values.
- Set rows wear the set's six core items at the same rank; set effects run but no set attack was fired, so set origins are absent from attribution by construction.
