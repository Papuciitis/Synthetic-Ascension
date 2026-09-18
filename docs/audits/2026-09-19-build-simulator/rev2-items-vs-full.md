# Simulator comparison: revision 2 items only (campaign 3) vs revision 2 complete (campaign 4)

296 builds present in both runs (same seed, same job list, same scenario). Medians per tier and Core; per-build changes are the same build under both rule sets.


**Read this with the simulator change in mind.** Campaign 3 ran before the
held-Q fix (Guard, Deadshot and Designate were re-pressed every sixth
frame, so Guard was permanently up and Deadshot fired 80 times a fight);
campaign 4 has the fix plus balance revision 2's accessories (Task 3),
continuous set channels (Task 4), the merge/price law (Task 5) and
Conduit's proxy-kill prime. Splitting the 296 builds by whether they own a
held Q (`BAQ`, `PRQ`, `ORQ`):

| Tier | Builds without a held Q: output, HP lost, deaths | Builds with one: output, HP lost |
|---|---|---|
| seg2 | 1300 -> 1237 (-5%), 134 -> 138 (+3%), 0.74 -> 0.91 | 1339 -> 1319 (-1%), 121 -> 151 (+25%) |
| seg4 | 2849 -> 3448 (+21%), 148 -> 168 (+13%), 0.50 -> 0.77 | 1923 -> 1931 (0%), 145 -> 173 (+19%) |
| seg6 | 5239 -> 5488 (+5%), 109 -> 111 (+1%), 0.23 -> 0.26 | 3582 -> 3664 (+2%), 132 -> 204 (+54%) |
| seg9 | 6288 -> 6290 (0%), 107 -> 141 (+31%), 0.15 -> 0.19 | 5567 -> 5745 (+3%), 117 -> 196 (+67%) |
| seg12 | 8094 -> 7702 (-5%), 61 -> 60 (-1%), 0.08 -> 0.15 | 6916 -> 6718 (-3%), 71 -> 120 (+68%) |

So the large HP-lost rises in the table below are the simulator now
holding Guard for two seconds instead of forever. Among builds without a
held Q, the balance changes read as: output up at seg4-seg6 (set channels
and a working Conduit), survivability down 3-13% with Oakheart wearers at
+16-18% HP lost (its deliberate early cut, Task 3) and Firestone wearers at
+9-10%; Regeneration healing rose (16 -> 22 with Oakheart). Seg2 deaths
per fight rose from 0.74 to 0.91, which is the tier to watch in play.

| Tier | Core | n | Enemy HP/s | HP lost | Deaths (mean) | Min HP % | Native share | Tree share | Set share |
|---|---|---:|---|---|---|---|---|---|---|
| seg2 | melee | 19 | 1521 -> 1318 (-13%) | 134 -> 152 (+13%) | 0.47 -> 0.74 | 18 -> 6 (-67%) | 25 -> 29 (+14%) | 0 -> 0 | 75 -> 69 (-7%) |
| seg2 | ranged | 19 | 1128 -> 1115 (-1%) | 136 -> 138 (+2%) | 0.79 -> 0.95 | 9 -> 6 (-33%) | 36 -> 40 (+10%) | 37 -> 43 (+14%) | 4 -> 5 (+32%) |
| seg2 | magic | 19 | 1410 -> 1503 (+7%) | 127 -> 134 (+5%) | 0.79 -> 0.95 | 7 -> 10 (+38%) | 34 -> 41 (+19%) | 53 -> 37 (-29%) | 3 -> 2 (-17%) |
| seg2 | all | 57 | 1325 -> 1290 (-3%) | 134 -> 140 (+5%) | 0.68 -> 0.88 | 9 -> 7 (-21%) | 32 -> 39 (+23%) | 25 -> 21 (-17%) | 6 -> 24 (+340%) |
| seg4 | melee | 19 | 2895 -> 2935 (+1%) | 80 -> 162 (+102%) | 0.00 -> 0.21 | 62 -> 19 (-69%) | 23 -> 26 (+13%) | 0 -> 1 | 77 -> 66 (-14%) |
| seg4 | ranged | 19 | 1923 -> 2017 (+5%) | 169 -> 174 (+4%) | 0.37 -> 0.95 | 14 -> 4 (-67%) | 31 -> 33 (+9%) | 40 -> 41 (+2%) | 6 -> 5 (-13%) |
| seg4 | magic | 19 | 2768 -> 3748 (+35%) | 151 -> 168 (+11%) | 0.74 -> 0.95 | 5 -> 5 (-9%) | 18 -> 30 (+66%) | 72 -> 64 (-12%) | 1 -> 1 (-37%) |
| seg4 | all | 57 | 2258 -> 2672 (+18%) | 148 -> 171 (+15%) | 0.37 -> 0.70 | 20 -> 7 (-67%) | 23 -> 31 (+34%) | 36 -> 37 (+2%) | 6 -> 12 (+112%) |
| seg6 | melee | 24 | 4989 -> 4725 (-5%) | 11 -> 13 (+18%) | 0.00 -> 0.00 | 96 -> 95 (-1%) | 19 -> 21 (+9%) | 2 -> 3 (+61%) | 74 -> 67 (-9%) |
| seg6 | ranged | 22 | 2967 -> 3636 (+23%) | 178 -> 212 (+20%) | 0.18 -> 0.45 | 26 -> 10 (-63%) | 41 -> 34 (-16%) | 43 -> 46 (+7%) | 4 -> 4 (-8%) |
| seg6 | magic | 22 | 5555 -> 5935 (+7%) | 139 -> 174 (+25%) | 0.36 -> 0.36 | 38 -> 28 (-25%) | 10 -> 23 (+130%) | 85 -> 77 (-9%) | 2 -> 2 (-20%) |
| seg6 | all | 68 | 4178 -> 4654 (+11%) | 128 -> 177 (+38%) | 0.18 -> 0.26 | 50 -> 31 (-38%) | 20 -> 25 (+23%) | 40 -> 44 (+10%) | 4 -> 7 (+46%) |
| seg9 | melee | 22 | 6416 -> 5982 (-7%) | 87 -> 155 (+77%) | 0.00 -> 0.00 | 77 -> 60 (-22%) | 25 -> 31 (+27%) | 11 -> 12 (+16%) | 67 -> 55 (-18%) |
| seg9 | ranged | 26 | 4794 -> 5211 (+9%) | 164 -> 231 (+41%) | 0.00 -> 0.00 | 53 -> 34 (-36%) | 14 -> 18 (+27%) | 62 -> 66 (+8%) | 1 -> 1 (-16%) |
| seg9 | magic | 16 | 6583 -> 6898 (+5%) | 66 -> 82 (+25%) | 0.25 -> 0.38 | 24 -> 16 (-32%) | 8 -> 16 (+91%) | 89 -> 82 (-8%) | 0 -> 0 (-2%) |
| seg9 | all | 64 | 5899 -> 5984 (+1%) | 114 -> 173 (+51%) | 0.06 -> 0.09 | 64 -> 44 (-31%) | 14 -> 18 (+28%) | 59 -> 61 (+5%) | 2 -> 5 (+121%) |
| seg12 | melee | 18 | 6920 -> 6847 (-1%) | 39 -> 81 (+105%) | 0.00 -> 0.00 | 95 -> 89 (-6%) | 51 -> 50 (-2%) | 22 -> 19 (-14%) | 24 -> 22 (-8%) |
| seg12 | ranged | 16 | 6709 -> 6332 (-6%) | 113 -> 174 (+54%) | 0.06 -> 0.12 | 65 -> 61 (-6%) | 23 -> 21 (-11%) | 59 -> 65 (+10%) | 4 -> 3 (-19%) |
| seg12 | magic | 16 | 8024 -> 7749 (-3%) | 59 -> 65 (+10%) | 0.06 -> 0.12 | 75 -> 63 (-17%) | 8 -> 11 (+42%) | 87 -> 83 (-4%) | 1 -> 1 (-44%) |
| seg12 | all | 50 | 7057 -> 6976 (-1%) | 66 -> 96 (+45%) | 0.04 -> 0.08 | 82 -> 73 (-11%) | 17 -> 21 (+24%) | 59 -> 63 (+7%) | 4 -> 10 (+183%) |

## Player stats worn (median over builds, per tier)

| Tier | Max HP | Armour | Power | Move speed |
|---|---|---|---|---|
| seg2 | 134 -> 134 | 7.2 -> 7.2 | 0.35 -> 0.35 | 130 -> 130 |
| seg4 | 180 -> 180 | 16.3 -> 16.3 | 0.47 -> 0.47 | 138 -> 139 |
| seg6 | 246 -> 246 | 24.0 -> 25.2 | 0.66 -> 0.67 | 139 -> 140 |
| seg9 | 338 -> 338 | 37.3 -> 39.0 | 0.99 -> 1.02 | 156 -> 159 |
| seg12 | 466 -> 472 | 51.5 -> 54.4 | 1.39 -> 1.42 | 162 -> 165 |

## Authored builds, same build under both rule sets

| Build | Tier | Enemy HP/s | HP lost | Deaths |
|---|---|---|---|---|
| Execution early | seg2 | 1376 -> 1176 (-15%) | 51 -> 51 | 0 -> 0 |
| Execution developed | seg4 | 1573 -> 2935 (+87%) | 23 -> 46 | 0 -> 0 |
| Execution pure | seg6 | 5230 -> 5488 (+5%) | 22 -> 26 | 0 -> 0 |
| Momentum early | seg2 | 1300 -> 1088 (-16%) | 51 -> 51 | 0 -> 0 |
| Momentum developed | seg4 | 3630 -> 3267 (-10%) | 0 -> 0 | 0 -> 0 |
| Momentum pure | seg6 | 2619 -> 2127 (-19%) | 0 -> 0 | 0 -> 0 |
| Bastion early | seg2 | 309 -> 450 (+46%) | 155 -> 159 | 1 -> 1 |
| Bastion developed | seg4 | 3798 -> 3228 (-15%) | 91 -> 181 | 0 -> 0 |
| Bastion pure | seg6 | 1311 -> 1505 (+15%) | 69 -> 163 | 0 -> 0 |
| Precision early | seg2 | 968 -> 887 (-8%) | 162 -> 167 | 1 -> 1 |
| Precision developed | seg4 | 1153 -> 1442 (+25%) | 178 -> 208 | 0 -> 1 |
| Precision pure | seg6 | 2473 -> 2782 (+12%) | 163 -> 224 | 0 -> 1 |
| Barrage early | seg2 | 568 -> 684 (+20%) | 148 -> 154 | 0 -> 1 |
| Barrage developed | seg4 | 1101 -> 1278 (+16%) | 32 -> 163 | 0 -> 1 |
| Barrage pure | seg6 | 2572 -> 2373 (-8%) | 218 -> 229 | 0 -> 1 |
| Ordnance early | seg2 | 832 -> 1025 (+23%) | 132 -> 49 | 1 -> 0 |
| Ordnance developed | seg4 | 4430 -> 4727 (+7%) | 208 -> 212 | 1 -> 1 |
| Ordnance pure | seg6 | 3028 -> 4567 (+51%) | 242 -> 241 | 1 -> 1 |
| Invocation early | seg2 | 922 -> 828 (-10%) | 134 -> 134 | 1 -> 1 |
| Invocation developed | seg4 | 892 -> 1429 (+60%) | 148 -> 148 | 1 -> 1 |
| Invocation pure | seg6 | 1777 -> 1436 (-19%) | 173 -> 183 | 0 -> 0 |
| Distortion early | seg2 | 489 -> 1290 (+164%) | 45 -> 127 | 0 -> 1 |
| Distortion developed | seg4 | 1280 -> 3927 (+207%) | 151 -> 206 | 0 -> 1 |
| Distortion pure | seg6 | 4849 -> 4280 (-12%) | 97 -> 202 | 0 -> 0 |
| Dominion early | seg2 | 2590 -> 2612 (+1%) | 109 -> 109 | 1 -> 1 |
| Dominion developed | seg4 | 2357 -> 4730 (+101%) | 170 -> 187 | 1 -> 1 |
| Dominion pure | seg6 | 5792 -> 6214 (+7%) | 105 -> 8 | 0 -> 0 |
| Hybrid: Running guns | seg6 | 5258 -> 5743 (+9%) | 0 -> 0 | 0 -> 0 |
| Hybrid: Corpse artillery | seg9 | 7017 -> 6492 (-7%) | 91 -> 142 | 0 -> 0 |
| Hybrid: Death Debt | seg9 | 5600 -> 5542 (-1%) | 6 -> 140 | 0 -> 0 |
| Hybrid: Stormwire | seg9 | 5846 -> 5979 (+2%) | 241 -> 279 | 0 -> 0 |
| Hybrid: Spell-loaded rail | seg9 | 1336 -> 1707 (+28%) | 174 -> 265 | 0 -> 0 |
| Hybrid: Runes and mines | seg9 | 4391 -> 5089 (+16%) | 173 -> 217 | 0 -> 0 |
| Hybrid: Kill Feed, ranged side | seg9 | 1589 -> 1770 (+11%) | 168 -> 235 | 0 -> 0 |
| Hybrid: Death Debt, melee side | seg9 | 6503 -> 5975 (-8%) | 106 -> 215 | 0 -> 0 |
| Hybrid: Wildfire, ranged side | seg9 | 2965 -> 2421 (-18%) | 110 -> 154 | 0 -> 0 |
| Ascendant: Three-Core avalanche | seg12 | 6946 -> 6997 (+1%) | 36 -> 62 | 0 -> 0 |
| Authored: Blood domino | seg6 | 5823 -> 6159 (+6%) | 112 -> 196 | 0 -> 0 |
| Authored: Endless Lunge | seg6 | 6412 -> 5665 (-12%) | 0 -> 0 | 0 -> 0 |
| Authored: Bomb suit | seg6 | 6070 -> 5984 (-1%) | 72 -> 161 | 0 -> 0 |
| Authored: Kill Line | seg6 | 761 -> 1241 (+63%) | 173 -> 247 | 0 -> 0 |
| Authored: Bullet Hell | seg6 | 2073 -> 1680 (-19%) | 179 -> 182 | 0 -> 0 |
| Authored: Carpet Bomb | seg6 | 3797 -> 4851 (+28%) | 180 -> 233 | 0 -> 1 |
| Authored: Sigil Web | seg6 | 2020 -> 1620 (-20%) | 139 -> 173 | 0 -> 0 |
| Authored: Loaded Coin | seg6 | 4156 -> 4196 (+1%) | 159 -> 186 | 0 -> 0 |
| Authored: Mass Grave | seg6 | 5827 -> 5927 (+2%) | 109 -> 211 | 0 -> 0 |
| Authored: Running guns | seg6 | 3062 -> 2415 (-21%) | 0 -> 0 | 0 -> 0 |
| Authored: Corpse artillery | seg9 | 5977 -> 5240 (-12%) | 143 -> 224 | 0 -> 0 |
| Authored: Death Debt | seg9 | 5079 -> 6360 (+25%) | 189 -> 184 | 0 -> 0 |
| Authored: Stormwire | seg9 | 4673 -> 4374 (-6%) | 167 -> 244 | 0 -> 0 |
| Authored: Spell-loaded rail | seg9 | 973 -> 1781 (+83%) | 115 -> 207 | 0 -> 0 |
| Authored: Runes and mines | seg9 | 4849 -> 4910 (+1%) | 172 -> 278 | 0 -> 0 |
| Authored: Three-Core avalanche | seg12 | 6578 -> 6649 (+1%) | 66 -> 75 | 0 -> 0 |
| Route: Kill Feed, ranged side | seg9 | 2976 -> 2438 (-18%) | 108 -> 164 | 0 -> 0 |
| Route: Death Debt, melee side | seg9 | 7552 -> 7200 (-5%) | 97 -> 163 | 0 -> 0 |
| Route: Wildfire, ranged side | seg9 | 1580 -> 1783 (+13%) | 112 -> 180 | 0 -> 0 |

## Largest per-build changes

| Build | Tier | Gear set | Enemy HP/s | HP lost |
|---|---|---|---|---|
| random melee seg9 #3 | seg9 | gravemarch | 5791 -> 4275 (-26%) | 93 -> 170 |
| random melee seg6 #9 | seg6 | gravemarch | 3582 -> 2731 (-24%) | 0 -> 0 |
| random melee seg4 #14 | seg4 | gravemarch | 2895 -> 2250 (-22%) | 0 -> 0 |
| random ranged seg4 #1 | seg4 | lattice | 2791 -> 2196 (-21%) | 169 -> 174 |
| Authored: Running guns | seg6 | gravemarch | 3062 -> 2415 (-21%) | 0 -> 0 |
| random melee seg9 #9 | seg9 | gravemarch | 4559 -> 3619 (-21%) | 116 -> 183 |
| random magic seg12 #9 | seg12 | conduit | 9705 -> 7747 (-20%) | 86 -> 128 |
| random ranged seg9 #9 | seg9 | gravemarch | 6918 -> 5524 (-20%) | 183 -> 251 |
| random magic seg2 #0 | seg2 | conduit | 1670 -> 3780 (+126%) | 137 -> 140 |
| random ranged seg6 #6 | seg6 | gravemarch | 1986 -> 4628 (+133%) | 232 -> 258 |
| random magic seg2 #4 | seg2 | conduit | 1410 -> 3336 (+137%) | 125 -> 130 |
| random magic seg4 #12 | seg4 | conduit | 1756 -> 4252 (+142%) | 120 -> 59 |
| Distortion early | seg2 | conduit | 489 -> 1290 (+164%) | 45 -> 127 |
| random magic seg4 #1 | seg4 | conduit | 469 -> 1251 (+167%) | 168 -> 168 |
| Distortion developed | seg4 | conduit | 1280 -> 3927 (+207%) | 151 -> 206 |
| random magic seg2 #12 | seg2 | conduit | 1120 -> 3447 (+208%) | 122 -> 132 |
