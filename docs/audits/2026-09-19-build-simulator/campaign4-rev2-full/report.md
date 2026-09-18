# Build simulator report: balance revision 2 complete (items, accessories, sets, economy), campaign 4, same seed as campaigns 2 and 3

296 builds (0 failed to install), 600 frames each at 60 simulated fps against a 60-body mixed crowd refilled every half second. Player inputs are scripted: a native strike every fourth frame at a random living target, Q whenever it is off recovery, V whenever it charged naturally, a dash every 90 frames. Incoming damage is scripted through the real player damage path: contact ticks from enemies within reach (10 x swarm x enemy damage multiplier every half second), spitter volleys and one sniper shot on their intervals. Every purchase used the real ledger rules; every hit resolved on the real combat services; attribution comes from the balance recorder. Numbers are for this scenario only.

## Sources and tiers

| Source | Builds |
|---|---:|
| authored | 16 |
| preset | 37 |
| random | 240 |
| route | 3 |

| Tier | Segment | Budget | Gear rank | Enemy HP x | Enemy damage x | Builds |
|---|---:|---:|---:|---:|---:|---:|
| seg2 | 2 | 3000 | 1 | 1.63 | 1.07 | 57 |
| seg4 | 4 | 8000 | 3 | 1.69 | 1.11 | 57 |
| seg6 | 6 | 16000 | 6 | 1.75 | 1.14 | 68 |
| seg9 | 9 | 32000 | 10 | 1.84 | 1.19 | 64 |
| seg12 | 12 | 64000 | 15 | 1.93 | 1.24 | 50 |

## Outcome distributions per tier (p10 / p50 / p90)

| Tier | Core | n | Enemy HP/s | Kills/s | HP lost | Deaths (mean) | Min HP % | Followers/min | Q casts | V casts | HP/s per 1k spent |
|---|---|---:|---|---|---|---:|---|---|---|---|---|
| seg2 | melee | 19 | 450.3 / 1318.1 / 3334.3 | 2.80 / 9.50 / 25.50 | 51 / 152 / 170 | 0.74 | 1 / 6 / 68 | 420 / 1110 / 3420 | 0 / 0 / 1 | 0 / 0 / 0 | 158.7 / 596.9 / 1176.2 |
| seg2 | ranged | 19 | 683.7 / 1114.7 / 1432.0 | 3.90 / 7.40 / 11.40 | 119 / 138 / 167 | 0.95 | 2 / 6 / 14 | 498 / 960 / 1422 | 0 / 1 / 1 | 0 / 0 / 0 | 246.1 / 412.2 / 886.6 |
| seg2 | magic | 19 | 923.5 / 1503.0 / 4566.6 | 5.80 / 10.60 / 31.50 | 109 / 134 / 158 | 0.95 | 2 / 10 / 18 | 804 / 1512 / 4176 | 0 / 0 / 1 | 0 / 0 / 0 | 319.1 / 828.3 / 1524.5 |
| seg2 | all | 57 | 609.0 / 1290.5 / 3336.2 | 4.20 / 9.80 / 26.80 | 110 / 140 / 167 | 0.88 | 2 / 7 / 18 | 498 / 1182 / 3456 | 0 / 0 / 1 | 0 / 0 / 0 | 246.1 / 461.8 / 1232.0 |
| seg4 | melee | 19 | 784.4 / 2934.8 / 4844.3 | 4.80 / 23.30 / 34.20 | 0 / 162 / 205 | 0.21 | 4 / 19 / 100 | 708 / 3084 / 4596 | 0 / 1 / 1 | 0 / 0 / 0 | 98.1 / 472.8 / 611.4 |
| seg4 | ranged | 19 | 1277.6 / 2017.3 / 4726.7 | 9.50 / 16.00 / 35.60 | 152 / 174 / 212 | 0.95 | 0 / 4 / 11 | 1200 / 2064 / 4530 | 0 / 1 / 1 | 0 / 0 / 0 | 204.3 / 258.6 / 603.7 |
| seg4 | magic | 19 | 1428.5 / 3747.7 / 6460.8 | 9.80 / 26.50 / 42.50 | 59 / 168 / 219 | 0.95 | 1 / 5 / 11 | 1272 / 3600 / 5730 | 0 / 1 / 1 | 0 / 0 / 0 | 221.8 / 468.5 / 844.6 |
| seg4 | all | 57 | 1250.6 / 2671.6 / 4844.3 | 8.80 / 18.70 / 37.10 | 11 / 171 / 208 | 0.70 | 1 / 7 / 95 | 1092 / 2526 / 5112 | 0 / 1 / 1 | 0 / 0 / 0 | 156.3 / 333.9 / 742.5 |
| seg6 | melee | 24 | 1504.6 / 4229.8 / 6358.9 | 9.90 / 30.40 / 43.40 | 0 / 0 / 206 | 0.00 | 21 / 90 / 100 | 1308 / 4002 / 5670 | 0 / 1 / 1 | 0 / 0 / 2 | 99.6 / 264.4 / 460.3 |
| seg6 | ranged | 22 | 2013.1 / 3607.8 / 4851.4 | 15.50 / 24.80 / 35.30 | 167 / 212 / 258 | 0.45 | 3 / 10 / 45 | 1998 / 3102 / 4848 | 1 / 1 / 2 | 0 / 0 / 1 | 127.3 / 225.5 / 329.3 |
| seg6 | magic | 22 | 4196.1 / 5926.5 / 7064.5 | 31.20 / 40.20 / 45.20 | 17 / 173 / 220 | 0.36 | 0 / 26 / 76 | 4080 / 5340 / 6066 | 0 / 1 / 1 | 0 / 0 / 2 | 289.2 / 371.5 / 456.4 |
| seg6 | all | 68 | 1619.5 / 4627.5 / 6358.9 | 11.90 / 32.20 / 43.60 | 0 / 175 / 233 | 0.26 | 3 / 30 / 100 | 1530 / 4206 / 5946 | 0 / 1 / 1 | 0 / 0 / 2 | 117.4 / 297.7 / 443.9 |
| seg9 | melee | 22 | 3791.4 / 5975.0 / 7200.0 | 27.00 / 41.10 / 44.10 | 0 / 155 / 215 | 0.00 | 52 / 60 / 100 | 3516 / 5400 / 6072 | 0 / 1 / 1 | 0 / 1 / 2 | 118.5 / 205.1 / 319.5 |
| seg9 | ranged | 26 | 1780.5 / 5088.9 / 6299.5 | 12.30 / 34.40 / 41.50 | 164 / 228 / 279 | 0.00 | 13 / 33 / 51 | 1596 / 4716 / 5640 | 0 / 1 / 2 | 0 / 1 / 2 | 98.3 / 174.6 / 272.8 |
| seg9 | magic | 16 | 5883.7 / 6878.9 / 7965.5 | 41.80 / 43.80 / 45.30 | 20 / 81 / 203 | 0.38 | 0 / 13 / 84 | 5574 / 5856 / 6120 | 0 / 1 / 2 | 0 / 0 / 2 | 183.9 / 215.0 / 248.9 |
| seg9 | all | 64 | 3290.8 / 5979.5 / 7293.9 | 22.20 / 40.70 / 44.30 | 46 / 170 / 269 | 0.09 | 11 / 43 / 74 | 2982 / 5400 / 6072 | 0 / 1 / 2 | 0 / 1 / 2 | 115.3 / 195.8 / 290.3 |
| seg12 | melee | 18 | 5032.0 / 6817.3 / 7384.7 | 34.90 / 44.00 / 45.30 | 0 / 75 / 156 | 0.00 | 66 / 89 / 100 | 4590 / 5826 / 6432 | 0 / 1 / 1 | 1 / 2 / 2 | 78.8 / 105.0 / 115.4 |
| seg12 | ranged | 16 | 5764.1 / 6271.7 / 7393.3 | 38.00 / 41.70 / 43.80 | 87 / 172 / 321 | 0.12 | 0 / 61 / 76 | 5046 / 5616 / 5934 | 0 / 1 / 2 | 2 / 2 / 2 | 90.2 / 98.2 / 115.5 |
| seg12 | magic | 16 | 6270.8 / 7746.7 / 9486.7 | 41.00 / 44.60 / 45.30 | 19 / 60 / 122 | 0.12 | 0 / 61 / 95 | 5382 / 5868 / 6390 | 0 / 1 / 2 | 2 / 2 / 2 | 98.2 / 121.0 / 148.2 |
| seg12 | all | 50 | 5786.6 / 6955.9 / 8337.6 | 38.00 / 43.50 / 45.20 | 0 / 96 / 200 | 0.08 | 0 / 72 / 95 | 5046 / 5808 / 6294 | 0 / 1 / 2 | 2 / 2 / 2 | 90.4 / 108.0 / 130.3 |

## Where the damage comes from (share of enemy HP removed)

| Tier | Core | Native | Tree (ascension) | Sets | Status | Witness | Mixed/unknown |
|---|---|---:|---:|---:|---:|---:|---:|
| seg2 | melee | 20% | 1% | 79% | 0% | 0% | 0% |
| seg2 | ranged | 46% | 38% | 12% | 1% | 0% | 3% |
| seg2 | magic | 47% | 45% | 7% | 0% | 0% | 0% |
| seg4 | melee | 24% | 2% | 74% | 0% | 0% | 0% |
| seg4 | ranged | 35% | 52% | 9% | 0% | 1% | 3% |
| seg4 | magic | 32% | 64% | 4% | 0% | 0% | 0% |
| seg6 | melee | 22% | 8% | 68% | 0% | 2% | 0% |
| seg6 | ranged | 35% | 54% | 6% | 1% | 1% | 3% |
| seg6 | magic | 21% | 77% | 2% | 0% | 0% | 0% |
| seg9 | melee | 31% | 17% | 51% | 0% | 1% | 0% |
| seg9 | ranged | 18% | 68% | 6% | 1% | 3% | 5% |
| seg9 | magic | 15% | 83% | 2% | 0% | 0% | 0% |
| seg12 | melee | 46% | 22% | 30% | 0% | 2% | 1% |
| seg12 | ranged | 20% | 65% | 6% | 1% | 3% | 4% |
| seg12 | magic | 11% | 85% | 4% | 0% | 1% | 0% |

## Node pick rates in random walks (affordable = guided unlock within the tier budget)

Random walks buy uniformly among buyable nodes weighted only by kind, so a pick rate is a structural fact (how often the node is buyable and how long it stays buyable), not a player preference. High rates mark nodes the rules push everyone through; low rates mark nodes the rules rarely expose.

| Nearly always bought when affordable | Kind | Pick rate | Damage lift |
|---|---|---:|---:|

| Rarely bought when affordable | Kind | Pick rate | Guided unlock | Status |
|---|---|---:|---:|---|

## Nodes that never attributed damage while owned

A silent node is not necessarily dead: defensive, movement, economy and enabling nodes never emit a payload of their own. Read this with the kind and the lift columns; a damage-kind node (mutation of an attack, fusion, revelation) that stays silent across many builds is the finding.

| Node | Kind | Discipline | Owned in builds | Damage lift | HP-lost lift | Status |
|---|---|---|---:|---:|---:|---|
| IN02 | local | IN | 92 | 1.06 | 1.07 | implemented |
| EX02 | local | EX | 90 | 0.99 | 0.95 | implemented |
| PR01 | local | PR | 90 | 0.95 | 0.99 | implemented |
| EX01 | local | EX | 87 | 1.26 | 0.87 | implemented |
| DO05 | local | DO | 87 | 0.95 | 1.29 | implemented |
| BA01 | local | BA | 85 | 0.95 | 0.93 | implemented |
| BA02 | local | BA | 84 | 1.18 | 0.89 | implemented |
| DO12 | local | DO | 83 | 1.07 | 1.09 | implemented |
| MO01 | local | MO | 82 | 1.01 | 0.96 | implemented |
| PR02 | local | PR | 82 | 0.99 | 1.02 | implemented |
| MO02 | local | MO | 81 | 0.96 | 1.00 | implemented |
| PR03 | local | PR | 70 | 1.00 | 0.88 | implemented |
| MO04 | local | MO | 67 | 0.95 | 0.99 | implemented |
| EX04 | local | EX | 64 | 1.06 | 0.95 | implemented |
| IN03 | local | IN | 63 | 0.96 | 0.94 | implemented |
| MOQ | active | MO | 62 | 0.96 | 0.46 | implemented |
| BA05 | local | BA | 62 | 1.25 | 1.69 | implemented |
| OR03 | local | OR | 62 | 1.00 | 1.11 | implemented |
| DTQ | active | DT | 62 | 0.81 | 0.93 | implemented |
| MO03 | local | MO | 61 | 0.85 | 1.05 | implemented |
| DO02 | local | DO | 59 | 1.11 | 0.83 | implemented |
| DO09 | local | DO | 59 | 1.15 | 1.03 | implemented |
| PR05 | local | PR | 58 | 0.95 | 1.06 | implemented |
| DT10 | local | DT | 58 | 0.96 | 0.77 | implemented |
| BA10 | local | BA | 57 | 0.95 | 0.91 | n/a |
| IN05 | local | IN | 57 | 1.05 | 0.69 | implemented |
| BA03 | local | BA | 55 | 0.84 | 0.84 | implemented |
| INQ | active | IN | 55 | 1.00 | 1.01 | implemented |
| OR05 | local | OR | 54 | 0.98 | 0.91 | implemented |
| MO05 | local | MO | 52 | 0.95 | 0.99 | implemented |
| OR06 | local | OR | 52 | 0.91 | 0.98 | implemented |
| MO07 | local | MO | 51 | 0.94 | 0.63 | implemented |
| BA07 | local | BA | 51 | 0.71 | 1.09 | implemented |
| PR06 | local | PR | 51 | 1.11 | 1.11 | implemented |
| IN04 | local | IN | 51 | 0.91 | 1.39 | implemented |
| DT04 | local | DT | 51 | 0.94 | 1.20 | implemented |
| DO06 | local | DO | 51 | 1.10 | 1.09 | implemented |
| BR03 | local | BR | 50 | 0.93 | 1.00 | implemented |
| DT05 | local | DT | 50 | 0.94 | 0.95 | implemented |
| MO08 | local | MO | 49 | 1.23 | 0.91 | implemented |
| OR10 | local | OR | 49 | 0.93 | 0.92 | implemented |
| PR04 | local | PR | 47 | 0.97 | 0.91 | implemented |
| OR09 | local | OR | 47 | 0.88 | 1.11 | implemented |
| MO06 | local | MO | 46 | 1.00 | 1.05 | implemented |
| EX10 | local | EX | 44 | 1.32 | 0.53 | implemented |
| OR12 | local | OR | 43 | 1.06 | 1.10 | implemented |
| BA08 | local | BA | 42 | 0.99 | 0.99 | implemented |
| BA11 | local | BA | 42 | 1.06 | 0.99 | implemented |
| OR07 | local | OR | 41 | 0.98 | 1.19 | implemented |
| IN10 | local | IN | 41 | 1.06 | 0.72 | implemented |
| DT09 | local | DT | 41 | 1.02 | 0.87 | implemented |
| BA09 | local | BA | 40 | 1.06 | 0.73 | implemented |
| BA12 | local | BA | 40 | 0.94 | 0.99 | implemented |
| DT07 | local | DT | 40 | 1.12 | 0.65 | implemented |
| OR11 | local | OR | 39 | 1.00 | 1.19 | implemented |
| MO10 | local | MO | 38 | 0.92 | 0.90 | implemented |
| MO09 | local | MO | 37 | 0.95 | 0.86 | implemented |
| PR10 | local | PR | 37 | 1.06 | 1.04 | implemented |
| BR07 | local | BR | 37 | 0.91 | 1.01 | implemented |
| EX08 | local | EX | 36 | 1.14 | 0.97 | implemented |

## Nodes by mean share of a build's damage while owned

| Node | Kind | Owned in | Mean share | Damage lift | Cost |
|---|---|---:|---:|---:|---:|
| OR04 | local | 61 | 22.9% | 1.14 | 400 |
| DOF1 | fork | 24 | 22.7% | 1.02 | 800 |
| EX05 | local | 47 | 20.6% | 1.53 | 400 |
| MM2 | fusion | 6 | 15.9% | - | 1800 |
| DO01 | local | 96 | 15.6% | 1.09 | 200 |
| DOK2 | keystone | 25 | 14.3% | 1.14 | 1200 |
| IN09 | local | 38 | 14.0% | 0.95 | 800 |
| DO04 | local | 44 | 12.7% | 1.05 | 400 |
| DT08 | local | 33 | 12.3% | 1.04 | 800 |
| OR01 | local | 89 | 10.8% | 1.07 | 200 |
| PR07 | local | 42 | 10.3% | 1.03 | 400 |
| DTE2 | evolution | 8 | 9.2% | 1.11 | 0 |
| EX06 | local | 59 | 8.6% | 0.95 | 400 |
| DO07 | local | 54 | 8.4% | 0.94 | 400 |
| BAV | revelation | 14 | 7.5% | 1.14 | 4800 |
| BR09 | local | 41 | 6.3% | 0.96 | 800 |
| EXC | catastrophe | 22 | 6.1% | 1.01 | 2400 |
| ORF1 | fork | 19 | 6.0% | 1.04 | 800 |
| EX03 | local | 56 | 5.6% | 1.17 | 400 |
| IN01 | local | 87 | 5.4% | 1.05 | 200 |
| BR04 | local | 63 | 5.4% | 0.92 | 400 |
| DTV2 | revelation_mutation | 4 | 5.2% | 0.90 | 1800 |
| DO03 | local | 61 | 4.9% | 1.14 | 400 |
| DTQ6 | mutation | 29 | 4.8% | 1.00 | 600 |
| BR05 | local | 70 | 4.6% | 1.05 | 400 |
| EXV | revelation | 22 | 4.3% | 1.17 | 4800 |
| BR01 | local | 98 | 4.2% | 0.98 | 200 |
| IN06 | local | 68 | 3.5% | 0.98 | 400 |
| PR11 | local | 41 | 3.4% | 1.02 | 800 |
| DT06 | local | 75 | 3.0% | 1.09 | 400 |

## Outliers within a tier (candidates for runaway synergies)

| Build | Core | Tier | Enemy HP/s | z (tier) | Kills/s | HP lost | Deaths | Q/V | Spent | Top origins |
|---|---|---|---:|---:|---:|---:|---:|---|---:|---|
| random magic seg12 #7 | magic | seg12 | 13176 | 4.8 | 46.00 | 0 | 0 | 0/2 | 64000 | ascension:IN09 61912, ascension:DOF1 23343, ascension:DTE2 9643 |
| random magic seg2 #8 | magic | seg2 | 4573 | 2.6 | 36.10 | 122 | 1 | 0/0 | 3000 | native:magic 16358, ascension:DO04 15677, ascension:DO01 12494 |
| random magic seg2 #6 | magic | seg2 | 4567 | 2.6 | 31.50 | 121 | 1 | 1/0 | 3000 | native:magic 16782, ascension:DO01 15359, ascension:DO04 10932 |
| random magic seg9 #9 | magic | seg9 | 10036 | 2.6 | 46.00 | 0 | 0 | 1/0 | 32000 | ascension:IN09 33862, ascension:DOF1 25861, ascension:IN01 14364 |
| random magic seg4 #13 | magic | seg4 | 6816 | 2.6 | 42.50 | 94 | 1 | 1/0 | 8000 | ascension:IN09 42819, ascension:DO01 11136, native:magic 10363 |
| random magic seg4 #14 | magic | seg4 | 6461 | 2.3 | 41.50 | 168 | 1 | 0/0 | 8000 | native:magic 19232, ascension:DO01 14727, ascension:DO07 10898 |
| random magic seg4 #9 | magic | seg4 | 6281 | 2.2 | 43.80 | 131 | 0 | 1/0 | 8000 | ascension:DOK2 39113, native:magic 11742, ascension:DO01 7997 |

## Node pairs enriched among the top decile builds of their tier

| Pair | Builds with pair | In top decile | Lift |
|---|---:|---:|---:|
| DOF1 + DOK2 | 7 | 6 | 9.4x |
| INC + INS2 | 6 | 5 | 9.1x |
| DTS1 + G1 | 5 | 4 | 8.8x |
| DTV + INS2 | 5 | 4 | 8.8x |
| DTV + pick.M2 | 5 | 4 | 8.8x |
| DT12 + INQ4 | 4 | 3 | 8.2x |
| BR02 + DTS1 | 4 | 3 | 8.2x |
| DOA + DTV | 4 | 3 | 8.2x |
| DOS1 + INS2 | 4 | 3 | 8.2x |
| DT07 + INS1 | 4 | 3 | 8.2x |
| DT12 + INC | 4 | 3 | 8.2x |
| DTV + INQ4 | 4 | 3 | 8.2x |
| G1 + INS2 | 4 | 3 | 8.2x |
| INS1 + INS2 | 4 | 3 | 8.2x |
| DOQ1 + DTF2 | 4 | 3 | 8.2x |
| DOS2 + pick.M1 | 4 | 3 | 8.2x |
| DOF1 + DT12 | 4 | 3 | 8.2x |
| DTK2 + INS2 | 4 | 3 | 8.2x |
| DOF1 + DTA | 4 | 3 | 8.2x |
| DOF1 + INC | 4 | 3 | 8.2x |
| DOS2 + DT09 | 7 | 5 | 7.8x |
| DOS2 + DTQ6 | 7 | 5 | 7.8x |
| DTV + INC | 7 | 5 | 7.8x |
| DOF1 + INQ2 | 6 | 4 | 7.3x |
| DT09 + INS2 | 6 | 4 | 7.3x |

## Authored presets and routes

| Build | Core | Tier | Nodes | Spent | Enemy HP/s | Kills/s | HP lost | Deaths | Q/V | Native / tree / sets share | Frame p95 ms |
|---|---|---|---:|---:|---:|---:|---:|---:|---|---|---:|
| Authored: Loaded Coin | magic | seg6 | 15 | 13600 | 4196 | 32.00 | 186 | 0 | 1/1 | 30 / 70 / 0% | 1.9 |
| Authored: Mass Grave | magic | seg6 | 15 | 12800 | 5927 | 40.60 | 211 | 0 | 1/2 | 7 / 88 / 5% | 2.0 |
| Authored: Sigil Web | magic | seg6 | 14 | 12400 | 1620 | 11.90 | 173 | 0 | 1/0 | 78 / 15 / 7% | 2.8 |
| Distortion developed | magic | seg4 | 12 | 6400 | 3927 | 31.00 | 206 | 1 | 1/0 | 45 / 55 / 0% | 2.0 |
| Distortion early | magic | seg2 | 5 | 1000 | 1290 | 10.50 | 127 | 1 | 0/0 | 88 / 10 / 1% | 1.8 |
| Distortion pure | magic | seg6 | 16 | 14800 | 4280 | 32.30 | 202 | 0 | 1/1 | 33 / 64 / 2% | 2.6 |
| Dominion developed | magic | seg4 | 12 | 5600 | 4730 | 35.20 | 187 | 1 | 1/0 | 28 / 71 / 0% | 3.0 |
| Dominion early | magic | seg2 | 5 | 1200 | 2612 | 20.60 | 109 | 1 | 0/0 | 41 / 55 / 4% | 3.4 |
| Dominion pure | magic | seg6 | 16 | 14000 | 6214 | 40.60 | 8 | 0 | 1/2 | 7 / 90 / 3% | 2.2 |
| Invocation developed | magic | seg4 | 11 | 5200 | 1429 | 9.80 | 148 | 1 | 1/0 | 83 / 16 / 1% | 2.1 |
| Invocation early | magic | seg2 | 5 | 1000 | 828 | 5.80 | 134 | 1 | 0/0 | 47 / 0 / 52% | 1.0 |
| Invocation pure | magic | seg6 | 15 | 13600 | 1436 | 10.10 | 183 | 0 | 1/0 | 76 / 13 / 9% | 3.1 |
| Ascendant: Three-Core avalanche | melee | seg12 | 51 | 71000 | 6997 | 44.70 | 62 | 0 | 1/2 | 15 / 60 / 15% | 1.6 |
| Authored: Blood domino | melee | seg6 | 14 | 12000 | 6159 | 43.60 | 196 | 0 | 1/2 | 18 / 16 / 65% | 6.6 |
| Authored: Bomb suit | melee | seg6 | 15 | 13000 | 5984 | 43.60 | 161 | 0 | 1/2 | 5 / 11 / 84% | 7.4 |
| Authored: Corpse artillery | melee | seg9 | 20 | 16400 | 5240 | 36.70 | 224 | 0 | 1/1 | 25 / 39 / 34% | 1.5 |
| Authored: Death Debt | melee | seg9 | 26 | 20600 | 6360 | 42.00 | 184 | 0 | 1/2 | 34 / 49 / 14% | 3.0 |
| Authored: Endless Lunge | melee | seg6 | 13 | 11600 | 5665 | 36.50 | 0 | 0 | 1/2 | 5 / 0 / 95% | 7.9 |
| Authored: Running guns | melee | seg6 | 19 | 15800 | 2415 | 16.80 | 0 | 0 | 1/1 | 14 / 8 / 73% | 1.3 |
| Authored: Three-Core avalanche | melee | seg12 | 51 | 71000 | 6649 | 45.20 | 75 | 0 | 1/2 | 23 / 49 / 19% | 1.5 |
| Bastion developed | melee | seg4 | 12 | 5800 | 3228 | 25.30 | 181 | 0 | 1/0 | 8 / 1 / 91% | 5.7 |
| Bastion early | melee | seg2 | 5 | 1000 | 450 | 2.90 | 159 | 1 | 0/0 | 64 / 0 / 36% | 1.3 |
| Bastion pure | melee | seg6 | 16 | 14200 | 1505 | 9.90 | 163 | 0 | 1/0 | 24 / 50 / 26% | 2.8 |
| Execution developed | melee | seg4 | 11 | 4800 | 2935 | 23.30 | 46 | 0 | 1/0 | 84 / 0 / 16% | 2.8 |
| Execution early | melee | seg2 | 5 | 1000 | 1176 | 7.90 | 51 | 0 | 0/0 | 31 / 0 / 69% | 1.2 |
| Execution pure | melee | seg6 | 15 | 13200 | 5488 | 43.40 | 26 | 0 | 1/2 | 19 / 18 / 63% | 5.4 |
| Hybrid: Corpse artillery | melee | seg9 | 20 | 16400 | 6492 | 43.90 | 142 | 0 | 1/2 | 10 / 23 / 67% | 5.3 |
| Hybrid: Death Debt | melee | seg9 | 26 | 20600 | 5542 | 40.70 | 140 | 0 | 1/2 | 37 / 43 / 16% | 2.7 |
| Hybrid: Death Debt, melee side | melee | seg9 | 23 | 19800 | 5975 | 37.00 | 215 | 0 | 1/2 | 42 / 42 / 11% | 2.6 |
| Hybrid: Running guns | melee | seg6 | 19 | 15800 | 5743 | 39.50 | 0 | 0 | 1/2 | 5 / 3 / 91% | 7.9 |
| Momentum developed | melee | seg4 | 10 | 4400 | 3267 | 24.80 | 0 | 0 | 1/0 | 8 / 0 / 92% | 5.9 |
| Momentum early | melee | seg2 | 5 | 1000 | 1088 | 7.80 | 51 | 0 | 0/0 | 23 / 0 / 77% | 1.2 |
| Momentum pure | melee | seg6 | 14 | 12800 | 2127 | 15.30 | 0 | 0 | 1/1 | 16 / 0 / 84% | 1.1 |
| Route: Death Debt, melee side | melee | seg9 | 23 | 19800 | 7200 | 43.80 | 163 | 0 | 1/2 | 16 / 24 / 57% | 6.7 |
| Authored: Bullet Hell | ranged | seg6 | 15 | 13200 | 1680 | 13.30 | 182 | 0 | 1/1 | 16 / 43 / 33% | 0.9 |
| Authored: Carpet Bomb | ranged | seg6 | 14 | 12400 | 4851 | 35.30 | 233 | 1 | 1/2 | 27 / 70 / 3% | 2.0 |
| Authored: Kill Line | ranged | seg6 | 15 | 12800 | 1241 | 8.90 | 247 | 0 | 1/0 | 69 / 29 / 1% | 0.9 |
| Authored: Runes and mines | ranged | seg9 | 22 | 18000 | 4910 | 34.40 | 278 | 0 | 1/2 | 10 / 85 / 0% | 1.2 |
| Authored: Spell-loaded rail | ranged | seg9 | 24 | 20200 | 1781 | 12.30 | 207 | 0 | 1/0 | 56 / 23 / 0% | 1.2 |
| Authored: Stormwire | ranged | seg9 | 24 | 20600 | 4374 | 30.10 | 244 | 0 | 1/1 | 13 / 74 / 0% | 1.2 |
| Barrage developed | ranged | seg4 | 12 | 6000 | 1278 | 9.50 | 163 | 1 | 1/0 | 26 / 61 / 1% | 1.0 |
| Barrage early | ranged | seg2 | 5 | 1000 | 684 | 4.80 | 154 | 1 | 0/0 | 39 / 45 / 1% | 0.9 |
| Barrage pure | ranged | seg6 | 16 | 14400 | 2373 | 18.70 | 229 | 1 | 1/1 | 51 / 38 / 7% | 2.4 |
| Hybrid: Kill Feed, ranged side | ranged | seg9 | 21 | 18000 | 1770 | 13.10 | 235 | 0 | 1/0 | 29 / 52 / 1% | 1.0 |
| Hybrid: Runes and mines | ranged | seg9 | 22 | 18000 | 5089 | 35.30 | 217 | 0 | 1/2 | 28 / 64 / 3% | 2.1 |
| Hybrid: Spell-loaded rail | ranged | seg9 | 24 | 20200 | 1707 | 10.50 | 265 | 0 | 1/0 | 58 / 23 / 0% | 1.2 |
| Hybrid: Stormwire | ranged | seg9 | 24 | 20600 | 5979 | 34.80 | 279 | 0 | 1/1 | 6 / 65 / 19% | 1.1 |
| Hybrid: Wildfire, ranged side | ranged | seg9 | 20 | 17600 | 2421 | 17.10 | 154 | 0 | 1/1 | 12 / 36 / 35% | 1.0 |
| Ordnance developed | ranged | seg4 | 11 | 5200 | 4727 | 35.60 | 212 | 1 | 1/0 | 5 / 85 / 10% | 1.0 |
| Ordnance early | ranged | seg2 | 5 | 1000 | 1025 | 7.10 | 49 | 0 | 0/0 | 32 / 68 / 1% | 0.8 |
| Ordnance pure | ranged | seg6 | 15 | 13600 | 4567 | 34.40 | 241 | 1 | 1/2 | 11 / 89 / 0% | 1.1 |
| Precision developed | ranged | seg4 | 12 | 5600 | 1442 | 9.90 | 208 | 1 | 1/0 | 42 / 18 / 38% | 1.0 |
| Precision early | ranged | seg2 | 5 | 1000 | 887 | 6.90 | 167 | 1 | 0/0 | 58 / 0 / 40% | 0.8 |
| Precision pure | ranged | seg6 | 16 | 14000 | 2782 | 18.80 | 224 | 1 | 1/1 | 75 / 18 / 4% | 2.3 |
| Route: Kill Feed, ranged side | ranged | seg9 | 21 | 18000 | 2438 | 18.40 | 164 | 0 | 1/1 | 14 / 41 / 36% | 1.0 |
| Route: Wildfire, ranged side | ranged | seg9 | 20 | 17600 | 1783 | 11.80 | 180 | 0 | 1/0 | 29 / 47 / 1% | 1.1 |

## Simulation cost

| Tier | Frame p50 ms (median over builds) | Frame p95 ms | Frame p99 ms |
|---|---:|---:|---:|
| seg2 | 0.36 | 1.83 | 2.95 |
| seg4 | 0.39 | 2.37 | 3.54 |
| seg6 | 0.42 | 2.80 | 4.15 |
| seg9 | 0.42 | 2.46 | 3.52 |
| seg12 | 0.42 | 3.08 | 4.54 |

## Caveats

- One scripted scenario: no enemy movement or AI, a fixed crowd mix, scripted inputs. Builds that rely on positioning, kiting or timing are under- or over-served by it.
- Gear is a random set at the tier's rank with two random accessories; item stats are balance revision 1 unless the label says otherwise.
- Lifts and pair enrichments are correlational within this sample; treat them as pointers for the tree audit, not as verdicts.
- Damage-silent nodes include every non-damage node by construction; the list is filtered to kinds that normally emit payloads but still needs reading by hand.
