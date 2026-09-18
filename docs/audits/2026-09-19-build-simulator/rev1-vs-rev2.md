# Simulator comparison: revision 1 (campaign 2) vs revision 2 (campaign 3)

296 builds present in both runs (same seed, same job list, same scenario). Medians per tier and Core; per-build changes are the same build under both rule sets.

| Tier | Core | n | Enemy HP/s | HP lost | Deaths (mean) | Min HP % | Native share | Tree share | Set share |
|---|---|---:|---|---|---|---|---|---|---|
| seg2 | melee | 19 | 1502 -> 1521 (+1%) | 120 -> 134 (+11%) | 0.37 -> 0.47 | 37 -> 18 (-52%) | 25 -> 25 (+2%) | 0 -> 0 | 75 -> 75 (-1%) |
| seg2 | ranged | 19 | 1015 -> 1128 (+11%) | 132 -> 136 (+3%) | 0.53 -> 0.79 | 8 -> 9 (+23%) | 38 -> 36 (-7%) | 42 -> 37 (-10%) | 3 -> 4 (+18%) |
| seg2 | magic | 19 | 1375 -> 1410 (+3%) | 125 -> 127 (+2%) | 0.84 -> 0.79 | 5 -> 7 (+31%) | 34 -> 34 (+1%) | 55 -> 53 (-4%) | 2 -> 3 (+46%) |
| seg2 | all | 57 | 1331 -> 1325 (-0%) | 131 -> 134 (+2%) | 0.58 -> 0.68 | 10 -> 9 (-9%) | 30 -> 32 (+6%) | 23 -> 25 (+9%) | 6 -> 6 (-9%) |
| seg4 | melee | 19 | 2403 -> 2895 (+20%) | 56 -> 80 (+44%) | 0.00 -> 0.00 | 77 -> 62 (-20%) | 19 -> 23 (+26%) | 0 -> 0 | 81 -> 77 (-6%) |
| seg4 | ranged | 19 | 1905 -> 1923 (+1%) | 129 -> 169 (+31%) | 0.47 -> 0.37 | 21 -> 14 (-36%) | 35 -> 31 (-11%) | 38 -> 40 (+6%) | 7 -> 6 (-10%) |
| seg4 | magic | 19 | 2600 -> 2768 (+6%) | 119 -> 151 (+27%) | 0.68 -> 0.74 | 14 -> 5 (-63%) | 18 -> 18 (+2%) | 75 -> 72 (-4%) | 1 -> 1 (-33%) |
| seg4 | all | 57 | 2150 -> 2258 (+5%) | 117 -> 148 (+27%) | 0.39 -> 0.37 | 29 -> 20 (-32%) | 24 -> 23 (-1%) | 38 -> 36 (-4%) | 7 -> 6 (-10%) |
| seg6 | melee | 24 | 4796 -> 4989 (+4%) | 7 -> 11 (+58%) | 0.00 -> 0.00 | 96 -> 96 (-1%) | 14 -> 19 (+39%) | 2 -> 2 (+2%) | 79 -> 74 (-6%) |
| seg6 | ranged | 22 | 2692 -> 2967 (+10%) | 131 -> 178 (+36%) | 0.45 -> 0.18 | 20 -> 26 (+33%) | 43 -> 41 (-4%) | 43 -> 43 (+0%) | 4 -> 4 (-1%) |
| seg6 | magic | 22 | 5207 -> 5555 (+7%) | 111 -> 139 (+26%) | 0.59 -> 0.36 | 20 -> 38 (+89%) | 12 -> 10 (-16%) | 86 -> 85 (-1%) | 2 -> 2 (-1%) |
| seg6 | all | 68 | 3805 -> 4178 (+10%) | 98 -> 128 (+31%) | 0.34 -> 0.18 | 41 -> 50 (+21%) | 19 -> 20 (+7%) | 40 -> 40 (+2%) | 4 -> 4 (+4%) |
| seg9 | melee | 22 | 5307 -> 6416 (+21%) | 94 -> 87 (-7%) | 0.05 -> 0.00 | 54 -> 77 (+44%) | 18 -> 25 (+35%) | 12 -> 11 (-10%) | 72 -> 67 (-7%) |
| seg9 | ranged | 26 | 4161 -> 4794 (+15%) | 137 -> 164 (+20%) | 0.35 -> 0.00 | 31 -> 53 (+68%) | 15 -> 14 (-6%) | 62 -> 62 (+0%) | 1 -> 1 (-28%) |
| seg9 | magic | 16 | 5770 -> 6583 (+14%) | 84 -> 66 (-22%) | 0.62 -> 0.25 | 8 -> 24 (+220%) | 7 -> 8 (+15%) | 90 -> 89 (-1%) | 0 -> 0 (-16%) |
| seg9 | all | 64 | 4963 -> 5899 (+19%) | 104 -> 114 (+10%) | 0.31 -> 0.06 | 37 -> 64 (+74%) | 12 -> 14 (+17%) | 59 -> 59 (-1%) | 2 -> 2 (-1%) |
| seg12 | melee | 18 | 6671 -> 6920 (+4%) | 57 -> 39 (-32%) | 0.06 -> 0.00 | 84 -> 95 (+13%) | 44 -> 51 (+15%) | 25 -> 22 (-11%) | 25 -> 24 (-3%) |
| seg12 | ranged | 16 | 6184 -> 6709 (+8%) | 134 -> 113 (-16%) | 0.75 -> 0.06 | 9 -> 65 (+644%) | 25 -> 23 (-7%) | 55 -> 59 (+7%) | 5 -> 4 (-28%) |
| seg12 | magic | 16 | 7460 -> 8024 (+8%) | 62 -> 59 (-5%) | 0.25 -> 0.06 | 41 -> 75 (+84%) | 6 -> 8 (+44%) | 86 -> 87 (+1%) | 2 -> 1 (-33%) |
| seg12 | all | 50 | 6569 -> 7057 (+7%) | 73 -> 66 (-10%) | 0.34 -> 0.04 | 56 -> 82 (+45%) | 17 -> 17 (-3%) | 55 -> 59 (+6%) | 4 -> 4 (-19%) |

## Player stats worn (median over builds, per tier)

| Tier | Max HP | Armour | Power | Move speed |
|---|---|---|---|---|
| seg2 | 146 -> 134 | 7.2 -> 7.2 | 0.35 -> 0.35 | 130 -> 130 |
| seg4 | 159 -> 180 | 57.2 -> 16.3 | 0.35 -> 0.47 | 135 -> 138 |
| seg6 | 170 -> 246 | 64.4 -> 24.0 | 0.35 -> 0.66 | 133 -> 139 |
| seg9 | 176 -> 338 | 72.3 -> 37.3 | 0.36 -> 0.99 | 147 -> 156 |
| seg12 | 182 -> 466 | 81.0 -> 51.5 | 0.38 -> 1.39 | 149 -> 162 |

## Authored builds, same build under both rule sets

| Build | Tier | Enemy HP/s | HP lost | Deaths |
|---|---|---|---|---|
| Execution early | seg2 | 1376 -> 1376 (-0%) | 51 -> 51 | 0 -> 0 |
| Execution developed | seg4 | 1235 -> 1573 (+27%) | 30 -> 23 | 0 -> 0 |
| Execution pure | seg6 | 5644 -> 5230 (-7%) | 14 -> 22 | 0 -> 0 |
| Momentum early | seg2 | 1331 -> 1300 (-2%) | 51 -> 51 | 0 -> 0 |
| Momentum developed | seg4 | 3693 -> 3630 (-2%) | 0 -> 0 | 0 -> 0 |
| Momentum pure | seg6 | 2319 -> 2619 (+13%) | 0 -> 0 | 0 -> 0 |
| Bastion early | seg2 | 309 -> 309 (+0%) | 155 -> 155 | 1 -> 1 |
| Bastion developed | seg4 | 3772 -> 3798 (+1%) | 94 -> 91 | 0 -> 0 |
| Bastion pure | seg6 | 1258 -> 1311 (+4%) | 90 -> 69 | 0 -> 0 |
| Precision early | seg2 | 1003 -> 968 (-4%) | 167 -> 162 | 0 -> 1 |
| Precision developed | seg4 | 993 -> 1153 (+16%) | 130 -> 178 | 0 -> 0 |
| Precision pure | seg6 | 2380 -> 2473 (+4%) | 144 -> 163 | 1 -> 0 |
| Barrage early | seg2 | 589 -> 568 (-4%) | 103 -> 148 | 0 -> 0 |
| Barrage developed | seg4 | 1083 -> 1101 (+2%) | 109 -> 32 | 0 -> 0 |
| Barrage pure | seg6 | 2245 -> 2572 (+15%) | 142 -> 218 | 1 -> 0 |
| Ordnance early | seg2 | 834 -> 832 (-0%) | 135 -> 132 | 0 -> 1 |
| Ordnance developed | seg4 | 3012 -> 4430 (+47%) | 165 -> 208 | 1 -> 1 |
| Ordnance pure | seg6 | 2866 -> 3028 (+6%) | 168 -> 242 | 1 -> 1 |
| Invocation early | seg2 | 921 -> 922 (+0%) | 134 -> 134 | 1 -> 1 |
| Invocation developed | seg4 | 738 -> 892 (+21%) | 119 -> 148 | 1 -> 1 |
| Invocation pure | seg6 | 1660 -> 1777 (+7%) | 111 -> 173 | 1 -> 0 |
| Distortion early | seg2 | 472 -> 489 (+4%) | 125 -> 45 | 1 -> 0 |
| Distortion developed | seg4 | 1181 -> 1280 (+8%) | 139 -> 151 | 0 -> 0 |
| Distortion pure | seg6 | 4791 -> 4849 (+1%) | 84 -> 97 | 0 -> 0 |
| Dominion early | seg2 | 2755 -> 2590 (-6%) | 109 -> 109 | 1 -> 1 |
| Dominion developed | seg4 | 2062 -> 2357 (+14%) | 137 -> 170 | 1 -> 1 |
| Dominion pure | seg6 | 5200 -> 5792 (+11%) | 86 -> 105 | 0 -> 0 |
| Hybrid: Running guns | seg6 | 5727 -> 5258 (-8%) | 0 -> 0 | 0 -> 0 |
| Hybrid: Corpse artillery | seg9 | 6934 -> 7017 (+1%) | 79 -> 91 | 0 -> 0 |
| Hybrid: Death Debt | seg9 | 4429 -> 5600 (+26%) | 92 -> 6 | 0 -> 0 |
| Hybrid: Stormwire | seg9 | 4966 -> 5846 (+18%) | 167 -> 241 | 1 -> 0 |
| Hybrid: Spell-loaded rail | seg9 | 826 -> 1336 (+62%) | 148 -> 174 | 1 -> 0 |
| Hybrid: Runes and mines | seg9 | 3453 -> 4391 (+27%) | 145 -> 173 | 1 -> 0 |
| Hybrid: Kill Feed, ranged side | seg9 | 1149 -> 1589 (+38%) | 141 -> 168 | 1 -> 0 |
| Hybrid: Death Debt, melee side | seg9 | 4960 -> 6503 (+31%) | 102 -> 106 | 0 -> 0 |
| Hybrid: Wildfire, ranged side | seg9 | 2220 -> 2965 (+34%) | 98 -> 110 | 0 -> 0 |
| Ascendant: Three-Core avalanche | seg12 | 7161 -> 6946 (-3%) | 73 -> 36 | 0 -> 0 |
| Authored: Blood domino | seg6 | 5957 -> 5823 (-2%) | 79 -> 112 | 0 -> 0 |
| Authored: Endless Lunge | seg6 | 6516 -> 6412 (-2%) | 0 -> 0 | 0 -> 0 |
| Authored: Bomb suit | seg6 | 5960 -> 6070 (+2%) | 51 -> 72 | 0 -> 0 |
| Authored: Kill Line | seg6 | 711 -> 761 (+7%) | 162 -> 173 | 0 -> 0 |
| Authored: Bullet Hell | seg6 | 1840 -> 2073 (+13%) | 169 -> 179 | 1 -> 0 |
| Authored: Carpet Bomb | seg6 | 4138 -> 3797 (-8%) | 150 -> 180 | 1 -> 0 |
| Authored: Sigil Web | seg6 | 1920 -> 2020 (+5%) | 110 -> 139 | 0 -> 0 |
| Authored: Loaded Coin | seg6 | 2901 -> 4156 (+43%) | 119 -> 159 | 0 -> 0 |
| Authored: Mass Grave | seg6 | 6508 -> 5827 (-10%) | 5 -> 109 | 0 -> 0 |
| Authored: Running guns | seg6 | 2647 -> 3062 (+16%) | 0 -> 0 | 0 -> 0 |
| Authored: Corpse artillery | seg9 | 5654 -> 5977 (+6%) | 163 -> 143 | 1 -> 0 |
| Authored: Death Debt | seg9 | 4217 -> 5079 (+20%) | 184 -> 189 | 0 -> 0 |
| Authored: Stormwire | seg9 | 3640 -> 4673 (+28%) | 118 -> 167 | 0 -> 0 |
| Authored: Spell-loaded rail | seg9 | 961 -> 973 (+1%) | 101 -> 115 | 0 -> 0 |
| Authored: Runes and mines | seg9 | 3185 -> 4849 (+52%) | 159 -> 172 | 0 -> 0 |
| Authored: Three-Core avalanche | seg12 | 6585 -> 6578 (-0%) | 73 -> 66 | 0 -> 0 |
| Route: Kill Feed, ranged side | seg9 | 2444 -> 2976 (+22%) | 106 -> 108 | 0 -> 0 |
| Route: Death Debt, melee side | seg9 | 7223 -> 7552 (+5%) | 159 -> 97 | 0 -> 0 |
| Route: Wildfire, ranged side | seg9 | 1070 -> 1580 (+48%) | 85 -> 112 | 0 -> 0 |

## Largest per-build changes

| Build | Tier | Gear set | Enemy HP/s | HP lost |
|---|---|---|---|---|
| random magic seg2 #12 | seg2 | conduit | 1365 -> 1120 (-18%) | 122 -> 122 |
| random ranged seg2 #10 | seg2 | gravemarch | 1366 -> 1129 (-17%) | 116 -> 123 |
| random magic seg4 #1 | seg4 | conduit | 567 -> 469 (-17%) | 119 -> 168 |
| random ranged seg9 #11 | seg9 | lattice | 5500 -> 4747 (-14%) | 143 -> 160 |
| random magic seg2 #14 | seg2 | gravemarch | 1804 -> 1570 (-13%) | 123 -> 145 |
| random magic seg4 #5 | seg4 | gravemarch | 3520 -> 3111 (-12%) | 111 -> 41 |
| random magic seg2 #9 | seg2 | gravemarch | 1089 -> 963 (-12%) | 134 -> 134 |
| random ranged seg2 #9 | seg2 | lattice | 1789 -> 1600 (-11%) | 132 -> 132 |
| Hybrid: Spell-loaded rail | seg9 | conduit | 826 -> 1336 (+62%) | 148 -> 174 |
| random melee seg12 #13 | seg12 | conduit | 3828 -> 6535 (+71%) | 84 -> 78 |
| random ranged seg12 #4 | seg12 | conduit | 3184 -> 5524 (+73%) | 192 -> 309 |
| random magic seg12 #5 | seg12 | conduit | 3110 -> 5457 (+75%) | 86 -> 73 |
| random melee seg9 #10 | seg9 | conduit | 3712 -> 6537 (+76%) | 146 -> 177 |
| random melee seg12 #0 | seg12 | conduit | 3514 -> 6598 (+88%) | 0 -> 0 |
| random melee seg6 #15 | seg6 | conduit | 1978 -> 3998 (+102%) | 0 -> 0 |
| random melee seg12 #7 | seg12 | conduit | 3126 -> 6790 (+117%) | 0 -> 0 |
