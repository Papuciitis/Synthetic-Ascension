# Set-output probe: same authored builds under each set after the Conduit proxy-kill fix (items + accessories + sets), 2026-09-19

56 authored builds (presets, authored builds and routes at their own tiers), each fought once per set with the same seed, gear rank, accessories and crowd streams. Set share is the fraction of enemy HP removed whose origin is the set's own payload; native, tree and status damage make up the rest. One scripted scenario; see the simulator caveats.

## Set share of enemy HP removed (median over builds)

| Tier | Core | n | conduit | gravemarch | lattice |
|---|---|---:|---:|---:|---:|
| seg2 | melee | 3 | 36% | 79% | 92% |
| seg2 | ranged | 3 | 1% | 38% | 6% |
| seg2 | magic | 3 | 0% | 48% | 7% |
| seg4 | melee | 3 | 24% | 79% | 91% |
| seg4 | ranged | 3 | 1% | 32% | 5% |
| seg4 | magic | 3 | 0% | 25% | 2% |
| seg6 | melee | 8 | 34% | 81% | 89% |
| seg6 | ranged | 6 | 1% | 37% | 6% |
| seg6 | magic | 6 | 0% | 12% | 2% |
| seg9 | melee | 6 | 14% | 25% | 65% |
| seg9 | ranged | 10 | 1% | 38% | 5% |
| seg12 | melee | 2 | 15% | 18% | 56% |

## Output and survivability by set (median over builds)

| Tier | Core | n | conduit: HP/s / HP lost / deaths | gravemarch: HP/s / HP lost / deaths | lattice: HP/s / HP lost / deaths |
|---|---|---:|---|---|---|
| seg2 | melee | 3 | 462 / 152 / 0.67 | 1407 / 179 / 0.67 | 3351 / 152 / 0.67 |
| seg2 | ranged | 3 | 704 / 140 / 1.00 | 1010 / 163 / 1.00 | 1305 / 137 / 1.00 |
| seg2 | magic | 3 | 1188 / 110 / 1.00 | 964 / 134 / 1.00 | 1371 / 109 / 1.00 |
| seg4 | melee | 3 | 595 / 11 / 0.00 | 1724 / 124 / 0.00 | 3456 / 132 / 0.00 |
| seg4 | ranged | 3 | 1283 / 172 / 0.33 | 1702 / 203 / 0.33 | 1959 / 167 / 0.33 |
| seg4 | magic | 3 | 3258 / 150 / 0.33 | 1995 / 126 / 0.33 | 4001 / 164 / 0.67 |
| seg6 | melee | 8 | 993 / 63 / 0.00 | 2721 / 62 / 0.00 | 5751 / 49 / 0.00 |
| seg6 | ranged | 6 | 1609 / 201 / 0.00 | 2157 / 187 / 0.00 | 2631 / 196 / 0.00 |
| seg6 | magic | 6 | 5102 / 64 / 0.00 | 4378 / 130 / 0.00 | 4933 / 104 / 0.00 |
| seg9 | melee | 6 | 6295 / 126 / 0.00 | 6635 / 109 / 0.00 | 6723 / 117 / 0.00 |
| seg9 | ranged | 10 | 1837 / 170 / 0.00 | 2827 / 153 / 0.00 | 2997 / 168 / 0.00 |
| seg12 | melee | 2 | 8078 / 97 / 0.00 | 7833 / 54 / 0.00 | 7776 / 58 / 0.00 |

## Same build, set to set (HP/s; the set is the only difference)

| Build | Core | Tier | conduit | gravemarch | lattice | Spread (max/min) |
|---|---|---|---:|---:|---:|---:|
| Distortion early | magic | seg2 | 1188 (0%) | 964 (48%) | 1371 (10%) | 1.42x |
| Dominion early | magic | seg2 | 2802 (0%) | 1623 (24%) | 2502 (2%) | 1.73x |
| Invocation early | magic | seg2 | 1058 (1%) | 940 (57%) | 1278 (7%) | 1.36x |
| Distortion developed | magic | seg4 | 3258 (0%) | 1995 (25%) | 4001 (2%) | 2.01x |
| Dominion developed | magic | seg4 | 4796 (0%) | 3073 (16%) | 4992 (1%) | 1.62x |
| Invocation developed | magic | seg4 | 1515 (0%) | 1477 (44%) | 1577 (7%) | 1.07x |
| Authored: Loaded Coin | magic | seg6 | 5433 (0%) | 4319 (13%) | 5095 (2%) | 1.26x |
| Authored: Mass Grave | magic | seg6 | 7429 (0%) | 6722 (4%) | 7167 (0%) | 1.11x |
| Authored: Sigil Web | magic | seg6 | 1448 (1%) | 1641 (50%) | 1614 (10%) | 1.13x |
| Distortion pure | magic | seg6 | 4770 (0%) | 4436 (11%) | 4771 (2%) | 1.08x |
| Dominion pure | magic | seg6 | 6557 (0%) | 6338 (5%) | 6200 (0%) | 1.06x |
| Invocation pure | magic | seg6 | 1359 (1%) | 1645 (58%) | 1705 (8%) | 1.25x |
| Ascendant: Three-Core avalanche | melee | seg12 | 8330 (14%) | 7830 (15%) | 8362 (52%) | 1.07x |
| Authored: Three-Core avalanche | melee | seg12 | 7826 (17%) | 7836 (21%) | 7191 (60%) | 1.09x |
| Bastion early | melee | seg2 | 462 (38%) | 1407 (79%) | 3351 (92%) | 7.25x |
| Execution early | melee | seg2 | 500 (32%) | 1368 (73%) | 3073 (90%) | 6.14x |
| Momentum early | melee | seg2 | 419 (36%) | 1419 (80%) | 3462 (93%) | 8.26x |
| Bastion developed | melee | seg4 | 595 (39%) | 1701 (79%) | 3374 (91%) | 5.67x |
| Execution developed | melee | seg4 | 2676 (15%) | 4710 (21%) | 5056 (65%) | 1.89x |
| Momentum developed | melee | seg4 | 410 (24%) | 1724 (81%) | 3456 (92%) | 8.43x |
| Authored: Blood domino | melee | seg6 | 4847 (10%) | 5410 (21%) | 5903 (71%) | 1.22x |
| Authored: Bomb suit | melee | seg6 | 648 (35%) | 2554 (83%) | 6361 (88%) | 9.81x |
| Authored: Endless Lunge | melee | seg6 | 571 (43%) | 2629 (87%) | 6145 (95%) | 10.75x |
| Authored: Running guns | melee | seg6 | 988 (35%) | 2813 (77%) | 4967 (90%) | 5.03x |
| Bastion pure | melee | seg6 | 1696 (23%) | 2489 (83%) | 5600 (85%) | 3.30x |
| Execution pure | melee | seg6 | 5105 (11%) | 5158 (21%) | 5576 (62%) | 1.09x |
| Hybrid: Running guns | melee | seg6 | 998 (36%) | 2922 (79%) | 6160 (92%) | 6.17x |
| Momentum pure | melee | seg6 | 519 (34%) | 2382 (86%) | 5136 (95%) | 9.90x |
| Authored: Corpse artillery | melee | seg9 | 6138 (15%) | 6108 (34%) | 6730 (66%) | 1.10x |
| Authored: Death Debt | melee | seg9 | 6452 (14%) | 6495 (20%) | 6170 (57%) | 1.05x |
| Hybrid: Corpse artillery | melee | seg9 | 5634 (14%) | 6649 (24%) | 7730 (64%) | 1.37x |
| Hybrid: Death Debt | melee | seg9 | 6604 (14%) | 6621 (30%) | 7124 (68%) | 1.08x |
| Hybrid: Death Debt, melee side | melee | seg9 | 5839 (13%) | 6891 (24%) | 6630 (73%) | 1.18x |
| Route: Death Debt, melee side | melee | seg9 | 7246 (12%) | 7156 (25%) | 6716 (57%) | 1.08x |
| Barrage early | ranged | seg2 | 704 (1%) | 1010 (38%) | 1251 (5%) | 1.78x |
| Ordnance early | ranged | seg2 | 1072 (1%) | 1341 (34%) | 1495 (6%) | 1.39x |
| Precision early | ranged | seg2 | 618 (1%) | 964 (45%) | 1305 (8%) | 2.11x |
| Barrage developed | ranged | seg4 | 1283 (1%) | 1702 (32%) | 1959 (5%) | 1.53x |
| Ordnance developed | ranged | seg4 | 3468 (0%) | 4442 (15%) | 3403 (4%) | 1.31x |
| Precision developed | ranged | seg4 | 1006 (1%) | 1695 (41%) | 1812 (5%) | 1.80x |
| Authored: Bullet Hell | ranged | seg6 | 1370 (1%) | 2076 (39%) | 2267 (6%) | 1.65x |
| Authored: Carpet Bomb | ranged | seg6 | 3903 (0%) | 5248 (13%) | 4914 (2%) | 1.34x |
| Authored: Kill Line | ranged | seg6 | 1382 (1%) | 1792 (44%) | 2209 (6%) | 1.60x |
| Barrage pure | ranged | seg6 | 1388 (1%) | 2033 (39%) | 2496 (6%) | 1.80x |
| Ordnance pure | ranged | seg6 | 3767 (0%) | 5292 (15%) | 4188 (4%) | 1.41x |
| Precision pure | ranged | seg6 | 1830 (0%) | 2239 (36%) | 2766 (5%) | 1.51x |
| Authored: Runes and mines | ranged | seg9 | 5301 (0%) | 4993 (21%) | 4961 (2%) | 1.07x |
| Authored: Spell-loaded rail | ranged | seg9 | 1491 (1%) | 2491 (45%) | 2455 (7%) | 1.67x |
| Authored: Stormwire | ranged | seg9 | 4375 (0%) | 5180 (20%) | 4039 (6%) | 1.28x |
| Hybrid: Kill Feed, ranged side | ranged | seg9 | 1818 (1%) | 2981 (37%) | 3096 (5%) | 1.70x |
| Hybrid: Runes and mines | ranged | seg9 | 5196 (0%) | 5229 (15%) | 5115 (3%) | 1.02x |
| Hybrid: Spell-loaded rail | ranged | seg9 | 1740 (1%) | 2673 (42%) | 2613 (7%) | 1.54x |
| Hybrid: Stormwire | ranged | seg9 | 5089 (0%) | 5641 (21%) | 5383 (4%) | 1.11x |
| Hybrid: Wildfire, ranged side | ranged | seg9 | 1739 (1%) | 2640 (43%) | 2899 (6%) | 1.67x |
| Route: Kill Feed, ranged side | ranged | seg9 | 1674 (1%) | 2606 (40%) | 2811 (6%) | 1.68x |
| Route: Wildfire, ranged side | ranged | seg9 | 1855 (1%) | 2668 (40%) | 2639 (5%) | 1.44x |

Median spread between the best and worst set for the same build: 1.48x; builds whose output changes by 2x or more with the set alone: 13 of 56.

## Set payload origins (total enemy HP removed across all builds)

| Origin | HP removed |
|---|---:|
| set:lattice:6 | 774301 |
| set:gravemarch:6 | 482223 |
| set:conduit:6 | 95482 |
