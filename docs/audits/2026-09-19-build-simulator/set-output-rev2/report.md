# Set-output probe: same authored builds under each set, balance revision 2 (items + accessories + sets), 2026-09-19

56 authored builds (presets, authored builds and routes at their own tiers), each fought once per set with the same seed, gear rank, accessories and crowd streams. Set share is the fraction of enemy HP removed whose origin is the set's own payload; native, tree and status damage make up the rest. One scripted scenario; see the simulator caveats.

## Set share of enemy HP removed (median over builds)

| Tier | Core | n | conduit | gravemarch | lattice |
|---|---|---:|---:|---:|---:|
| seg2 | melee | 3 | 2% | 78% | 92% |
| seg2 | ranged | 3 | 1% | 39% | 6% |
| seg2 | magic | 3 | 1% | 48% | 4% |
| seg4 | melee | 3 | 2% | 79% | 91% |
| seg4 | ranged | 3 | 1% | 34% | 6% |
| seg4 | magic | 3 | 1% | 28% | 3% |
| seg6 | melee | 8 | 1% | 80% | 90% |
| seg6 | ranged | 6 | 1% | 37% | 4% |
| seg6 | magic | 6 | 0% | 12% | 2% |
| seg9 | melee | 6 | 0% | 26% | 61% |
| seg9 | ranged | 10 | 1% | 39% | 6% |
| seg12 | melee | 2 | 0% | 21% | 55% |

## Output and survivability by set (median over builds)

| Tier | Core | n | conduit: HP/s / HP lost / deaths | gravemarch: HP/s / HP lost / deaths | lattice: HP/s / HP lost / deaths |
|---|---|---:|---|---|---|
| seg2 | melee | 3 | 309 / 151 / 0.67 | 1394 / 176 / 0.67 | 3462 / 152 / 0.67 |
| seg2 | ranged | 3 | 578 / 138 / 0.67 | 996 / 171 / 1.00 | 1254 / 137 / 0.67 |
| seg2 | magic | 3 | 491 / 110 / 1.00 | 1001 / 134 / 1.00 | 1324 / 109 / 1.00 |
| seg4 | melee | 3 | 398 / 140 / 0.33 | 1724 / 124 / 0.00 | 3897 / 131 / 0.00 |
| seg4 | ranged | 3 | 1233 / 173 / 1.00 | 1697 / 43 / 0.00 | 1917 / 149 / 0.33 |
| seg4 | magic | 3 | 1147 / 169 / 1.00 | 1909 / 197 / 0.67 | 4168 / 164 / 0.67 |
| seg6 | melee | 8 | 622 / 22 / 0.00 | 2729 / 53 / 0.00 | 5797 / 52 / 0.00 |
| seg6 | ranged | 6 | 1478 / 189 / 0.17 | 2122 / 182 / 0.00 | 2495 / 187 / 0.17 |
| seg6 | magic | 6 | 3845 / 96 / 0.00 | 5160 / 137 / 0.00 | 4960 / 125 / 0.00 |
| seg9 | melee | 6 | 6325 / 136 / 0.00 | 6729 / 128 / 0.00 | 7367 / 112 / 0.00 |
| seg9 | ranged | 10 | 1704 / 166 / 0.00 | 2835 / 161 / 0.00 | 2932 / 160 / 0.00 |
| seg12 | melee | 2 | 7601 / 88 / 0.00 | 7936 / 65 / 0.00 | 8293 / 50 / 0.00 |

## Same build, set to set (HP/s; the set is the only difference)

| Build | Core | Tier | conduit | gravemarch | lattice | Spread (max/min) |
|---|---|---|---:|---:|---:|---:|
| Distortion early | magic | seg2 | 491 (1%) | 1001 (48%) | 1324 (4%) | 2.70x |
| Dominion early | magic | seg2 | 1389 (0%) | 1559 (25%) | 2473 (2%) | 1.78x |
| Invocation early | magic | seg2 | 353 (2%) | 957 (57%) | 1298 (7%) | 3.68x |
| Distortion developed | magic | seg4 | 1147 (1%) | 1909 (28%) | 4168 (3%) | 3.63x |
| Dominion developed | magic | seg4 | 2381 (0%) | 3073 (17%) | 4690 (1%) | 1.97x |
| Invocation developed | magic | seg4 | 856 (1%) | 1438 (44%) | 1567 (6%) | 1.83x |
| Authored: Loaded Coin | magic | seg6 | 4106 (0%) | 5286 (11%) | 5116 (2%) | 1.29x |
| Authored: Mass Grave | magic | seg6 | 6799 (0%) | 7546 (3%) | 7191 (0%) | 1.11x |
| Authored: Sigil Web | magic | seg6 | 632 (1%) | 1577 (50%) | 1767 (7%) | 2.79x |
| Distortion pure | magic | seg6 | 3584 (0%) | 5033 (14%) | 4804 (2%) | 1.40x |
| Dominion pure | magic | seg6 | 6600 (0%) | 5983 (3%) | 6891 (0%) | 1.15x |
| Invocation pure | magic | seg6 | 710 (1%) | 1686 (55%) | 1628 (9%) | 2.37x |
| Ascendant: Three-Core avalanche | melee | seg12 | 7731 (0%) | 8179 (18%) | 8371 (51%) | 1.08x |
| Authored: Three-Core avalanche | melee | seg12 | 7471 (0%) | 7692 (24%) | 8215 (58%) | 1.10x |
| Bastion early | melee | seg2 | 309 (2%) | 1394 (78%) | 3524 (92%) | 11.42x |
| Execution early | melee | seg2 | 345 (2%) | 1389 (73%) | 3073 (90%) | 8.89x |
| Momentum early | melee | seg2 | 281 (2%) | 1571 (83%) | 3462 (93%) | 12.33x |
| Bastion developed | melee | seg4 | 398 (2%) | 1700 (79%) | 3365 (91%) | 8.45x |
| Execution developed | melee | seg4 | 3421 (0%) | 4061 (27%) | 4808 (67%) | 1.41x |
| Momentum developed | melee | seg4 | 320 (2%) | 1724 (81%) | 3897 (93%) | 12.17x |
| Authored: Blood domino | melee | seg6 | 4845 (0%) | 5507 (27%) | 6288 (66%) | 1.30x |
| Authored: Bomb suit | melee | seg6 | 452 (2%) | 2678 (84%) | 6301 (89%) | 13.94x |
| Authored: Endless Lunge | melee | seg6 | 352 (2%) | 2472 (86%) | 6023 (95%) | 17.13x |
| Authored: Running guns | melee | seg6 | 589 (1%) | 2781 (78%) | 5271 (90%) | 8.95x |
| Bastion pure | melee | seg6 | 1346 (1%) | 2516 (82%) | 5448 (86%) | 4.05x |
| Execution pure | melee | seg6 | 4725 (0%) | 5029 (24%) | 5570 (63%) | 1.18x |
| Hybrid: Running guns | melee | seg6 | 656 (1%) | 2923 (78%) | 6174 (91%) | 9.41x |
| Momentum pure | melee | seg6 | 352 (2%) | 2382 (86%) | 4637 (94%) | 13.16x |
| Authored: Corpse artillery | melee | seg9 | 2781 (0%) | 6100 (40%) | 7372 (66%) | 2.65x |
| Authored: Death Debt | melee | seg9 | 6284 (0%) | 6721 (24%) | 6673 (62%) | 1.07x |
| Hybrid: Corpse artillery | melee | seg9 | 5423 (0%) | 7144 (25%) | 7906 (60%) | 1.46x |
| Hybrid: Death Debt | melee | seg9 | 6366 (0%) | 6558 (27%) | 7450 (56%) | 1.17x |
| Hybrid: Death Debt, melee side | melee | seg9 | 6850 (0%) | 6737 (24%) | 7063 (62%) | 1.05x |
| Route: Death Debt, melee side | melee | seg9 | 6968 (0%) | 6993 (28%) | 7362 (54%) | 1.06x |
| Barrage early | ranged | seg2 | 578 (1%) | 983 (39%) | 1254 (6%) | 2.17x |
| Ordnance early | ranged | seg2 | 846 (1%) | 1334 (35%) | 1562 (5%) | 1.85x |
| Precision early | ranged | seg2 | 542 (1%) | 996 (45%) | 1131 (8%) | 2.09x |
| Barrage developed | ranged | seg4 | 1233 (1%) | 1697 (34%) | 1917 (6%) | 1.55x |
| Ordnance developed | ranged | seg4 | 4124 (0%) | 3845 (15%) | 3586 (3%) | 1.15x |
| Precision developed | ranged | seg4 | 925 (1%) | 1554 (41%) | 1835 (7%) | 1.98x |
| Authored: Bullet Hell | ranged | seg6 | 1177 (1%) | 1910 (38%) | 2201 (7%) | 1.87x |
| Authored: Carpet Bomb | ranged | seg6 | 4039 (0%) | 4555 (17%) | 4283 (4%) | 1.13x |
| Authored: Kill Line | ranged | seg6 | 1121 (1%) | 1807 (42%) | 2212 (5%) | 1.97x |
| Barrage pure | ranged | seg6 | 1255 (1%) | 2037 (37%) | 2331 (6%) | 1.86x |
| Ordnance pure | ranged | seg6 | 3845 (0%) | 4825 (18%) | 4853 (3%) | 1.26x |
| Precision pure | ranged | seg6 | 1702 (0%) | 2207 (40%) | 2660 (4%) | 1.56x |
| Authored: Runes and mines | ranged | seg9 | 5453 (0%) | 4969 (23%) | 5378 (4%) | 1.10x |
| Authored: Spell-loaded rail | ranged | seg9 | 1450 (1%) | 2820 (39%) | 2543 (8%) | 1.95x |
| Authored: Stormwire | ranged | seg9 | 4449 (0%) | 6204 (17%) | 5318 (5%) | 1.39x |
| Hybrid: Kill Feed, ranged side | ranged | seg9 | 1708 (1%) | 2844 (39%) | 2956 (6%) | 1.73x |
| Hybrid: Runes and mines | ranged | seg9 | 5040 (0%) | 4908 (19%) | 4493 (3%) | 1.12x |
| Hybrid: Spell-loaded rail | ranged | seg9 | 1700 (1%) | 2615 (41%) | 2592 (7%) | 1.54x |
| Hybrid: Stormwire | ranged | seg9 | 4384 (0%) | 5663 (21%) | 5959 (3%) | 1.36x |
| Hybrid: Wildfire, ranged side | ranged | seg9 | 1624 (1%) | 2826 (41%) | 2908 (6%) | 1.79x |
| Route: Kill Feed, ranged side | ranged | seg9 | 1574 (1%) | 2613 (41%) | 2832 (7%) | 1.80x |
| Route: Wildfire, ranged side | ranged | seg9 | 1619 (1%) | 2740 (39%) | 2856 (5%) | 1.76x |

Median spread between the best and worst set for the same build: 1.79x; builds whose output changes by 2x or more with the set alone: 19 of 56.

## Set payload origins (total enemy HP removed across all builds)

| Origin | HP removed |
|---|---:|
| set:lattice:6 | 778509 |
| set:gravemarch:6 | 500553 |
| set:conduit:6 | 3656 |
