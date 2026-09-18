# Build simulator report: balance revision 2 (item curves), campaign 3, same seed as campaign 2

296 builds (0 failed to install), 480 frames each at 60 simulated fps against a 60-body mixed crowd refilled every half second. Player inputs are scripted: a native strike every fourth frame at a random living target, Q whenever it is off recovery, V whenever it charged naturally, a dash every 90 frames. Incoming damage is scripted through the real player damage path: contact ticks from enemies within reach (10 x swarm x enemy damage multiplier every half second), spitter volleys and one sniper shot on their intervals. Every purchase used the real ledger rules; every hit resolved on the real combat services; attribution comes from the balance recorder. Numbers are for this scenario only.

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
| seg2 | melee | 19 | 308.7 / 1521.0 / 3711.9 | 1.75 / 11.12 / 26.75 | 46 / 134 / 162 | 0.47 | 1 / 18 / 74 | 240 / 1222 / 3435 | 0 / 0 / 80 | 0 / 0 / 0 | 112.0 / 694.7 / 1299.9 |
| seg2 | ranged | 19 | 567.9 / 1128.1 / 1365.2 | 3.75 / 7.62 / 11.12 | 119 / 136 / 162 | 0.79 | 2 / 9 / 35 | 398 / 1012 / 1478 | 0 / 1 / 80 | 0 / 0 / 0 | 232.2 / 441.7 / 832.4 |
| seg2 | magic | 19 | 509.0 / 1410.2 / 3434.9 | 3.62 / 10.12 / 25.00 | 53 / 127 / 156 | 0.79 | 1 / 7 / 61 | 458 / 1365 / 3338 | 0 / 0 / 1 | 0 / 0 / 0 | 321.0 / 489.1 / 1453.3 |
| seg2 | all | 57 | 438.2 / 1325.0 / 3320.7 | 2.62 / 9.75 / 24.62 | 51 / 134 / 160 | 0.68 | 1 / 9 / 66 | 398 / 1170 / 3278 | 0 / 0 / 80 | 0 / 0 / 0 | 169.7 / 470.1 / 1237.3 |
| seg4 | melee | 19 | 410.7 / 2895.0 / 5222.6 | 2.50 / 21.75 / 35.25 | 0 / 80 / 133 | 0.00 | 31 / 62 / 100 | 405 / 2812 / 4762 | 0 / 1 / 80 | 0 / 0 / 0 | 51.3 / 361.9 / 686.4 |
| seg4 | ranged | 19 | 1057.1 / 1923.3 / 4429.9 | 6.25 / 14.75 / 31.00 | 132 / 169 / 202 | 0.37 | 4 / 14 / 26 | 652 / 1972 / 3945 | 0 / 3 / 80 | 0 / 0 / 0 | 132.1 / 240.4 / 588.2 |
| seg4 | magic | 19 | 892.3 / 2768.3 / 5728.2 | 5.25 / 17.00 / 40.25 | 29 / 151 / 189 | 0.74 | 1 / 5 / 82 | 750 / 2318 / 5168 | 0 / 1 / 1 | 0 / 0 / 0 | 171.6 / 358.1 / 716.0 |
| seg4 | all | 57 | 892.3 / 2257.8 / 4705.3 | 3.88 / 15.88 / 34.25 | 23 / 148 / 181 | 0.37 | 3 / 20 / 89 | 615 / 2138 / 4425 | 0 / 1 / 80 | 0 / 0 / 0 | 127.0 / 327.7 / 654.8 |
| seg6 | melee | 24 | 1310.7 / 4747.4 / 6718.2 | 7.62 / 32.88 / 43.12 | 0 / 0 / 127 | 0.00 | 55 / 92 / 100 | 975 / 4178 / 5872 | 0 / 1 / 80 | 0 / 0 / 2 | 84.6 / 296.7 / 480.5 |
| seg6 | ranged | 22 | 1985.8 / 2906.5 / 4198.9 | 13.50 / 21.25 / 31.62 | 119 / 177 / 232 | 0.18 | 4 / 25 / 58 | 1672 / 2798 / 3975 | 1 / 4 / 80 | 0 / 0 / 1 | 124.1 / 181.7 / 306.2 |
| seg6 | magic | 22 | 2537.1 / 5318.5 / 6745.9 | 14.12 / 36.75 / 45.50 | 89 / 139 / 187 | 0.36 | 2 / 36 / 65 | 1920 / 4875 / 5948 | 0 / 1 / 1 | 0 / 0 / 1 | 162.9 / 332.4 / 438.9 |
| seg6 | all | 68 | 1765.5 / 4156.6 / 6469.5 | 12.00 / 30.12 / 43.12 | 0 / 127 / 205 | 0.18 | 5 / 50 / 100 | 1492 / 3975 / 5768 | 0 / 1 / 80 | 0 / 0 / 1 | 110.3 / 279.1 / 438.9 |
| seg9 | melee | 22 | 4322.6 / 6406.9 / 7017.2 | 29.50 / 41.50 / 47.12 | 0 / 84 / 143 | 0.00 | 62 / 77 / 100 | 4020 / 5692 / 6442 | 0 / 1 / 80 | 0 / 1 / 2 | 135.1 / 204.3 / 364.5 |
| seg9 | ranged | 26 | 1579.6 / 4746.7 / 6917.7 | 11.00 / 31.75 / 42.88 | 110 / 162 / 217 | 0.00 | 35 / 52 / 69 | 1418 / 4155 / 5632 | 0 / 1 / 80 | 0 / 1 / 1 | 88.3 / 168.5 / 244.0 |
| seg9 | magic | 16 | 4938.5 / 6373.2 / 8220.8 | 33.50 / 42.38 / 46.25 | 31 / 61 / 196 | 0.25 | 0 / 24 / 90 | 4650 / 5730 / 6390 | 0 / 1 / 80 | 0 / 0 / 2 | 154.3 / 199.2 / 256.9 |
| seg9 | all | 64 | 2976.3 / 5846.3 / 7345.4 | 19.88 / 39.62 / 45.75 | 31 / 114 / 189 | 0.06 | 20 / 63 / 90 | 2595 / 5430 / 6285 | 0 / 1 / 80 | 0 / 1 / 2 | 123.7 / 193.8 / 271.8 |
| seg12 | melee | 18 | 4605.3 / 6894.4 / 8154.0 | 28.75 / 45.50 / 47.50 | 0 / 37 / 107 | 0.00 | 74 / 95 / 100 | 3802 / 6038 / 6608 | 0 / 1 / 80 | 1 / 2 / 2 | 72.1 / 106.2 / 127.4 |
| seg12 | ranged | 16 | 5524.1 / 6694.7 / 7437.8 | 36.38 / 42.12 / 44.12 | 53 / 110 / 266 | 0.06 | 8 / 62 / 90 | 4590 / 5782 / 5985 | 0 / 1 / 80 | 1 / 1 / 2 | 86.5 / 104.6 / 116.2 |
| seg12 | magic | 16 | 6938.3 / 7953.9 / 9705.1 | 42.50 / 44.88 / 46.50 | 23 / 58 / 91 | 0.06 | 0 / 74 / 94 | 5730 / 6112 / 6532 | 0 / 1 / 80 | 1 / 2 / 2 | 108.4 / 124.5 / 151.6 |
| seg12 | all | 50 | 5524.1 / 7014.8 / 8380.9 | 36.38 / 44.00 / 47.25 | 15 / 66 / 164 | 0.04 | 14 / 81 / 97 | 4590 / 5955 / 6488 | 0 / 1 / 80 | 1 / 2 / 2 | 86.5 / 109.6 / 131.1 |

## Where the damage comes from (share of enemy HP removed)

| Tier | Core | Native | Tree (ascension) | Sets | Status | Witness | Mixed/unknown |
|---|---|---:|---:|---:|---:|---:|---:|
| seg2 | melee | 20% | 0% | 80% | 0% | 0% | 0% |
| seg2 | ranged | 43% | 38% | 15% | 1% | 0% | 4% |
| seg2 | magic | 36% | 52% | 12% | 0% | 0% | 0% |
| seg4 | melee | 22% | 1% | 77% | 0% | 0% | 0% |
| seg4 | ranged | 36% | 49% | 10% | 0% | 1% | 3% |
| seg4 | magic | 20% | 74% | 6% | 0% | 0% | 0% |
| seg6 | melee | 21% | 6% | 71% | 0% | 2% | 0% |
| seg6 | ranged | 39% | 47% | 8% | 1% | 1% | 4% |
| seg6 | magic | 15% | 82% | 3% | 0% | 0% | 0% |
| seg9 | melee | 31% | 17% | 51% | 0% | 1% | 0% |
| seg9 | ranged | 16% | 67% | 8% | 1% | 4% | 4% |
| seg9 | magic | 9% | 88% | 3% | 0% | 0% | 0% |
| seg12 | melee | 44% | 24% | 29% | 0% | 2% | 1% |
| seg12 | ranged | 21% | 63% | 7% | 1% | 3% | 4% |
| seg12 | magic | 8% | 86% | 5% | 0% | 1% | 0% |

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
| IN02 | local | IN | 92 | 1.08 | 1.39 | implemented |
| EX02 | local | EX | 90 | 0.94 | 0.75 | implemented |
| PR01 | local | PR | 90 | 1.04 | 1.02 | implemented |
| EX01 | local | EX | 87 | 1.24 | 0.97 | implemented |
| DO05 | local | DO | 87 | 1.04 | 1.09 | implemented |
| BA01 | local | BA | 85 | 0.92 | 0.97 | implemented |
| BA02 | local | BA | 84 | 1.14 | 0.73 | implemented |
| DO12 | local | DO | 83 | 1.04 | 1.14 | implemented |
| MO01 | local | MO | 82 | 0.94 | 0.88 | implemented |
| PR02 | local | PR | 82 | 0.98 | 1.02 | implemented |
| MO02 | local | MO | 81 | 0.93 | 0.97 | implemented |
| BAQ | active | BA | 70 | 0.75 | 0.57 | implemented |
| PR03 | local | PR | 70 | 1.23 | 0.89 | implemented |
| MO04 | local | MO | 67 | 0.92 | 0.92 | implemented |
| EX04 | local | EX | 64 | 0.99 | 1.01 | implemented |
| IN03 | local | IN | 63 | 0.91 | 1.02 | implemented |
| MOQ | active | MO | 62 | 0.97 | 0.38 | implemented |
| BA05 | local | BA | 62 | 1.08 | 0.93 | implemented |
| OR03 | local | OR | 62 | 0.98 | 1.04 | implemented |
| DTQ | active | DT | 62 | 0.77 | 0.98 | implemented |
| MO03 | local | MO | 61 | 0.85 | 0.90 | implemented |
| DO02 | local | DO | 59 | 1.07 | 0.84 | implemented |
| DO09 | local | DO | 59 | 1.09 | 1.09 | implemented |
| PR05 | local | PR | 58 | 0.95 | 0.98 | implemented |
| DT10 | local | DT | 58 | 0.89 | 0.75 | implemented |
| BA10 | local | BA | 57 | 0.90 | 0.91 | n/a |
| IN05 | local | IN | 57 | 1.01 | 0.81 | implemented |
| BA03 | local | BA | 55 | 0.91 | 0.88 | implemented |
| INQ | active | IN | 55 | 0.96 | 1.23 | implemented |
| OR05 | local | OR | 54 | 0.95 | 0.99 | implemented |
| MO05 | local | MO | 52 | 0.92 | 0.82 | implemented |
| OR06 | local | OR | 52 | 1.04 | 1.03 | implemented |
| MO07 | local | MO | 51 | 0.90 | 0.82 | implemented |
| BA07 | local | BA | 51 | 0.78 | 0.87 | implemented |
| PR06 | local | PR | 51 | 1.16 | 0.94 | implemented |
| IN04 | local | IN | 51 | 0.85 | 1.14 | implemented |
| DT04 | local | DT | 51 | 1.00 | 1.21 | implemented |
| DO06 | local | DO | 51 | 1.16 | 0.90 | implemented |
| BR03 | local | BR | 50 | 0.95 | 1.01 | implemented |
| DT05 | local | DT | 50 | 0.95 | 0.84 | implemented |
| MO08 | local | MO | 49 | 1.04 | 0.82 | implemented |
| PR04 | local | PR | 47 | 1.21 | 0.78 | implemented |
| OR09 | local | OR | 47 | 0.89 | 1.27 | implemented |
| MO06 | local | MO | 46 | 0.93 | 1.35 | implemented |
| EX10 | local | EX | 44 | 1.23 | 0.54 | implemented |
| OR12 | local | OR | 43 | 1.04 | 0.88 | implemented |
| BA08 | local | BA | 42 | 0.96 | 0.90 | implemented |
| BA11 | local | BA | 42 | 1.06 | 1.01 | implemented |
| OR07 | local | OR | 41 | 0.96 | 1.36 | implemented |
| IN10 | local | IN | 41 | 1.05 | 0.81 | implemented |
| DT09 | local | DT | 41 | 0.97 | 0.93 | implemented |
| BA09 | local | BA | 40 | 1.02 | 0.95 | implemented |
| BA12 | local | BA | 40 | 0.95 | 0.58 | implemented |
| DT07 | local | DT | 40 | 1.09 | 0.73 | implemented |
| OR11 | local | OR | 39 | 1.07 | 1.21 | implemented |
| MO10 | local | MO | 38 | 0.92 | 1.06 | implemented |
| MO09 | local | MO | 37 | 0.93 | 0.69 | implemented |
| PR10 | local | PR | 37 | 1.25 | 0.82 | implemented |
| BR07 | local | BR | 37 | 0.92 | 0.96 | implemented |
| EX08 | local | EX | 36 | 1.15 | 1.26 | implemented |

## Nodes by mean share of a build's damage while owned

| Node | Kind | Owned in | Mean share | Damage lift | Cost |
|---|---|---:|---:|---:|---:|
| DOF1 | fork | 24 | 25.8% | 0.99 | 800 |
| EX05 | local | 47 | 20.9% | 1.56 | 400 |
| OR04 | local | 61 | 19.5% | 1.02 | 400 |
| MM2 | fusion | 6 | 15.8% | - | 1800 |
| DO01 | local | 96 | 15.8% | 1.07 | 200 |
| DO04 | local | 44 | 13.7% | 1.14 | 400 |
| DOK2 | keystone | 25 | 13.6% | 1.23 | 1200 |
| DTE2 | evolution | 8 | 13.3% | 1.04 | 0 |
| IN09 | local | 38 | 13.1% | 0.99 | 800 |
| OR01 | local | 89 | 11.7% | 1.04 | 200 |
| DT08 | local | 33 | 11.1% | 1.07 | 800 |
| DO07 | local | 54 | 8.9% | 1.07 | 400 |
| EX06 | local | 59 | 8.7% | 0.92 | 400 |
| PR07 | local | 42 | 8.4% | 1.13 | 400 |
| EXC | catastrophe | 22 | 7.7% | 0.96 | 2400 |
| BAV | revelation | 14 | 7.2% | 1.12 | 4800 |
| DTQ6 | mutation | 29 | 6.9% | 0.97 | 600 |
| BR09 | local | 41 | 6.7% | 0.94 | 800 |
| IN01 | local | 87 | 6.1% | 0.97 | 200 |
| BR04 | local | 63 | 5.9% | 0.90 | 400 |
| IN06 | local | 68 | 5.5% | 1.01 | 400 |
| EX03 | local | 56 | 5.5% | 1.13 | 400 |
| ORF1 | fork | 19 | 5.4% | 1.01 | 800 |
| BR01 | local | 98 | 4.6% | 1.00 | 200 |
| DO03 | local | 61 | 4.5% | 1.04 | 400 |
| DTV2 | revelation_mutation | 4 | 4.4% | 0.90 | 1800 |
| BR05 | local | 70 | 4.2% | 1.03 | 400 |
| DT01 | local | 93 | 3.9% | 1.04 | 200 |
| EXV | revelation | 22 | 3.7% | 1.11 | 4800 |
| EX11 | local | 21 | 3.4% | 1.18 | 800 |

## Outliers within a tier (candidates for runaway synergies)

| Build | Core | Tier | Enemy HP/s | z (tier) | Kills/s | HP lost | Deaths | Q/V | Spent | Top origins |
|---|---|---|---:|---:|---:|---:|---:|---|---:|---|
| random magic seg12 #7 | magic | seg12 | 11328 | 3.2 | 47.50 | 15 | 0 | 0/2 | 64000 | ascension:IN09 28571, ascension:DOF1 14364, ascension:DTE2 11113 |
| random magic seg4 #13 | magic | seg4 | 7021 | 2.9 | 42.50 | 89 | 1 | 1/0 | 8000 | ascension:IN09 35940, ascension:DO01 8651, native:magic 8586 |
| random magic seg2 #6 | magic | seg2 | 4360 | 2.9 | 30.75 | 121 | 1 | 1/0 | 3000 | native:magic 14272, ascension:DO01 10828, ascension:DO04 7875 |
| random magic seg9 #9 | magic | seg9 | 10004 | 2.6 | 47.50 | 0 | 0 | 1/0 | 32000 | ascension:IN09 20769, ascension:DOF1 20518, ascension:IN01 11766 |
| random melee seg2 #10 | melee | seg2 | 3822 | 2.3 | 27.75 | 162 | 0 | 0/0 | 3000 | set:lattice:6 28423, native:melee 2153 |
| random melee seg2 #6 | melee | seg2 | 3712 | 2.2 | 25.25 | 84 | 0 | 80/0 | 3000 | set:lattice:6 27595, native:melee 2101 |
| random magic seg4 #9 | magic | seg4 | 5728 | 2.0 | 40.25 | 148 | 1 | 80/0 | 8000 | ascension:DOK2 26814, ascension:DO08 6456, ascension:DO01 6236 |

## Node pairs enriched among the top decile builds of their tier

| Pair | Builds with pair | In top decile | Lift |
|---|---:|---:|---:|
| DT12 + INQ4 | 4 | 3 | 8.2x |
| DOS2 + pick.D1 | 4 | 3 | 8.2x |
| IN12 + OR02 | 4 | 3 | 8.2x |
| INC + pick.P2 | 4 | 3 | 8.2x |
| INQ4 + OR02 | 4 | 3 | 8.2x |
| INQ4 + pick.P2 | 4 | 3 | 8.2x |
| DOF1 + DOK2 | 7 | 5 | 7.8x |
| DOS2 + INK2 | 8 | 5 | 6.9x |
| DOF1 + pick.D3 | 5 | 3 | 6.6x |
| IN07 + OR02 | 5 | 3 | 6.6x |
| INK2 + OR02 | 5 | 3 | 6.6x |
| IN10 + OR02 | 5 | 3 | 6.6x |
| DOS2 + DT12 | 5 | 3 | 6.6x |
| DTQ5 + INV1 | 5 | 3 | 6.6x |
| BR02 + INQ4 | 5 | 3 | 6.6x |
| DOK2 + OR02 | 5 | 3 | 6.6x |
| DTQ5 + pick.P2 | 5 | 3 | 6.6x |
| INK2 + pick.P2 | 5 | 3 | 6.6x |
| INV1 + pick.D1 | 5 | 3 | 6.6x |
| DOF1 + DOS2 | 5 | 3 | 6.6x |
| DOS2 + INQ4 | 7 | 4 | 6.3x |
| DTQ5 + INV | 7 | 4 | 6.3x |
| DO07 + pick.P2 | 7 | 4 | 6.3x |
| DOS2 + DT09 | 7 | 4 | 6.3x |
| DOS2 + DTQ6 | 7 | 4 | 6.3x |

## Authored presets and routes

| Build | Core | Tier | Nodes | Spent | Enemy HP/s | Kills/s | HP lost | Deaths | Q/V | Native / tree / sets share | Frame p95 ms |
|---|---|---|---:|---:|---:|---:|---:|---:|---|---|---:|
| Authored: Loaded Coin | magic | seg6 | 15 | 13600 | 4156 | 31.62 | 159 | 0 | 1/1 | 10 / 90 / 0% | 1.3 |
| Authored: Mass Grave | magic | seg6 | 15 | 12800 | 5827 | 39.00 | 109 | 0 | 1/1 | 7 / 87 / 5% | 2.4 |
| Authored: Sigil Web | magic | seg6 | 14 | 12400 | 2020 | 13.62 | 139 | 0 | 1/0 | 82 / 11 / 7% | 2.5 |
| Distortion developed | magic | seg4 | 12 | 6400 | 1280 | 10.12 | 151 | 0 | 1/0 | 28 / 71 / 1% | 1.3 |
| Distortion early | magic | seg2 | 5 | 1000 | 489 | 3.62 | 45 | 0 | 0/0 | 70 / 29 / 1% | 1.2 |
| Distortion pure | magic | seg6 | 16 | 14800 | 4849 | 36.50 | 97 | 0 | 1/1 | 30 / 68 / 2% | 2.5 |
| Dominion developed | magic | seg4 | 12 | 5600 | 2357 | 17.00 | 170 | 1 | 1/0 | 17 / 83 / 0% | 1.9 |
| Dominion early | magic | seg2 | 5 | 1200 | 2590 | 20.00 | 109 | 1 | 0/0 | 39 / 58 / 3% | 3.2 |
| Dominion pure | magic | seg6 | 16 | 14000 | 5792 | 38.00 | 105 | 0 | 1/1 | 7 / 88 / 5% | 2.1 |
| Invocation developed | magic | seg4 | 11 | 5200 | 892 | 5.25 | 148 | 1 | 1/0 | 46 / 53 / 1% | 1.5 |
| Invocation early | magic | seg2 | 5 | 1000 | 922 | 6.50 | 134 | 1 | 0/0 | 44 / 0 / 56% | 1.2 |
| Invocation pure | magic | seg6 | 15 | 13600 | 1777 | 12.00 | 173 | 0 | 1/0 | 77 / 11 / 10% | 2.9 |
| Ascendant: Three-Core avalanche | melee | seg12 | 51 | 71000 | 6946 | 46.75 | 36 | 0 | 1/2 | 16 / 55 / 23% | 1.7 |
| Authored: Blood domino | melee | seg6 | 14 | 12000 | 5823 | 43.00 | 112 | 0 | 1/2 | 12 / 16 / 72% | 5.9 |
| Authored: Bomb suit | melee | seg6 | 15 | 13000 | 6070 | 42.00 | 72 | 0 | 80/1 | 5 / 6 / 89% | 7.4 |
| Authored: Corpse artillery | melee | seg9 | 20 | 16400 | 5977 | 41.50 | 143 | 0 | 1/1 | 18 / 41 / 40% | 1.6 |
| Authored: Death Debt | melee | seg9 | 26 | 20600 | 5079 | 36.75 | 189 | 0 | 1/1 | 39 / 55 / 0% | 1.3 |
| Authored: Endless Lunge | melee | seg6 | 13 | 11600 | 6412 | 41.75 | 0 | 0 | 1/1 | 5 / 0 / 95% | 7.7 |
| Authored: Running guns | melee | seg6 | 19 | 15800 | 3062 | 21.62 | 0 | 0 | 1/1 | 11 / 5 / 80% | 1.3 |
| Authored: Three-Core avalanche | melee | seg12 | 51 | 71000 | 6578 | 46.88 | 66 | 0 | 1/2 | 20 / 46 / 25% | 1.5 |
| Bastion developed | melee | seg4 | 12 | 5800 | 3798 | 29.75 | 91 | 0 | 80/0 | 7 / 0 / 93% | 6.0 |
| Bastion early | melee | seg2 | 5 | 1000 | 309 | 1.88 | 155 | 1 | 0/0 | 98 / 0 / 2% | 1.1 |
| Bastion pure | melee | seg6 | 16 | 14200 | 1311 | 8.25 | 69 | 0 | 80/0 | 30 / 70 / 1% | 1.4 |
| Execution developed | melee | seg4 | 11 | 4800 | 1573 | 12.25 | 23 | 0 | 1/0 | 97 / 3 / 0% | 2.2 |
| Execution early | melee | seg2 | 5 | 1000 | 1376 | 8.88 | 51 | 0 | 0/0 | 26 / 0 / 74% | 2.5 |
| Execution pure | melee | seg6 | 15 | 13200 | 5230 | 43.12 | 22 | 0 | 1/2 | 18 / 6 / 75% | 5.2 |
| Hybrid: Corpse artillery | melee | seg9 | 20 | 16400 | 7017 | 47.38 | 91 | 0 | 1/2 | 9 / 23 / 68% | 6.4 |
| Hybrid: Death Debt | melee | seg9 | 26 | 20600 | 5600 | 41.00 | 6 | 0 | 1/1 | 43 / 52 / 0% | 1.4 |
| Hybrid: Death Debt, melee side | melee | seg9 | 23 | 19800 | 6503 | 41.50 | 106 | 0 | 1/1 | 46 / 49 / 0% | 1.4 |
| Hybrid: Running guns | melee | seg6 | 19 | 15800 | 5258 | 36.25 | 0 | 0 | 1/1 | 5 / 3 / 91% | 6.7 |
| Momentum developed | melee | seg4 | 10 | 4400 | 3630 | 27.00 | 0 | 0 | 1/0 | 7 / 0 / 93% | 5.5 |
| Momentum early | melee | seg2 | 5 | 1000 | 1300 | 9.00 | 51 | 0 | 0/0 | 20 / 0 / 80% | 1.1 |
| Momentum pure | melee | seg6 | 14 | 12800 | 2619 | 19.38 | 0 | 0 | 1/1 | 13 / 0 / 87% | 1.2 |
| Route: Death Debt, melee side | melee | seg9 | 23 | 19800 | 7552 | 44.12 | 97 | 0 | 1/2 | 14 / 27 / 56% | 5.0 |
| Authored: Bullet Hell | ranged | seg6 | 15 | 13200 | 2073 | 17.50 | 179 | 0 | 1/1 | 15 / 36 / 42% | 0.9 |
| Authored: Carpet Bomb | ranged | seg6 | 14 | 12400 | 3797 | 28.00 | 180 | 0 | 12/1 | 40 / 56 / 4% | 2.0 |
| Authored: Kill Line | ranged | seg6 | 15 | 12800 | 761 | 4.75 | 173 | 0 | 80/0 | 79 / 20 / 0% | 1.0 |
| Authored: Runes and mines | ranged | seg9 | 22 | 18000 | 4849 | 33.12 | 172 | 0 | 2/1 | 6 / 89 / 0% | 0.9 |
| Authored: Spell-loaded rail | ranged | seg9 | 24 | 20200 | 973 | 5.12 | 115 | 0 | 80/0 | 51 / 15 / 0% | 0.9 |
| Authored: Stormwire | ranged | seg9 | 24 | 20600 | 4673 | 29.25 | 167 | 0 | 1/1 | 5 / 82 / 0% | 1.0 |
| Barrage developed | ranged | seg4 | 12 | 6000 | 1101 | 8.12 | 32 | 0 | 1/0 | 19 / 67 / 1% | 1.0 |
| Barrage early | ranged | seg2 | 5 | 1000 | 568 | 3.75 | 148 | 0 | 0/0 | 30 / 54 / 1% | 1.0 |
| Barrage pure | ranged | seg6 | 16 | 14400 | 2572 | 20.75 | 218 | 0 | 1/1 | 53 / 34 / 8% | 2.2 |
| Hybrid: Kill Feed, ranged side | ranged | seg9 | 21 | 18000 | 1589 | 11.38 | 168 | 0 | 1/0 | 17 / 60 / 1% | 0.9 |
| Hybrid: Runes and mines | ranged | seg9 | 22 | 18000 | 4391 | 29.88 | 173 | 0 | 3/1 | 37 / 53 / 4% | 2.0 |
| Hybrid: Spell-loaded rail | ranged | seg9 | 24 | 20200 | 1336 | 8.50 | 174 | 0 | 80/0 | 60 / 12 / 0% | 1.0 |
| Hybrid: Stormwire | ranged | seg9 | 24 | 20600 | 5846 | 36.25 | 241 | 0 | 1/1 | 5 / 61 / 22% | 1.1 |
| Hybrid: Wildfire, ranged side | ranged | seg9 | 20 | 17600 | 2965 | 20.50 | 110 | 0 | 1/1 | 12 / 32 / 41% | 1.0 |
| Ordnance developed | ranged | seg4 | 11 | 5200 | 4430 | 31.00 | 208 | 1 | 3/0 | 6 / 79 / 15% | 1.0 |
| Ordnance early | ranged | seg2 | 5 | 1000 | 832 | 6.50 | 132 | 1 | 0/0 | 25 / 74 / 1% | 0.8 |
| Ordnance pure | ranged | seg6 | 15 | 13600 | 3028 | 22.25 | 242 | 1 | 2/1 | 9 / 90 / 0% | 0.8 |
| Precision developed | ranged | seg4 | 12 | 5600 | 1153 | 7.50 | 178 | 0 | 80/0 | 51 / 12 / 36% | 0.9 |
| Precision early | ranged | seg2 | 5 | 1000 | 968 | 8.00 | 162 | 1 | 0/0 | 54 / 0 / 44% | 0.8 |
| Precision pure | ranged | seg6 | 16 | 14000 | 2473 | 17.00 | 163 | 0 | 80/0 | 88 / 6 / 4% | 2.2 |
| Route: Kill Feed, ranged side | ranged | seg9 | 21 | 18000 | 2976 | 18.50 | 108 | 0 | 1/1 | 13 / 33 / 43% | 0.8 |
| Route: Wildfire, ranged side | ranged | seg9 | 20 | 17600 | 1580 | 11.00 | 112 | 0 | 1/0 | 15 / 55 / 1% | 0.8 |

## Simulation cost

| Tier | Frame p50 ms (median over builds) | Frame p95 ms | Frame p99 ms |
|---|---:|---:|---:|
| seg2 | 0.33 | 1.21 | 2.41 |
| seg4 | 0.37 | 2.20 | 3.40 |
| seg6 | 0.38 | 2.39 | 4.18 |
| seg9 | 0.38 | 1.68 | 2.67 |
| seg12 | 0.37 | 2.30 | 3.55 |

## Caveats

- One scripted scenario: no enemy movement or AI, a fixed crowd mix, scripted inputs. Builds that rely on positioning, kiting or timing are under- or over-served by it.
- Gear is a random set at the tier's rank with two random accessories; item stats are balance revision 1 unless the label says otherwise.
- Lifts and pair enrichments are correlational within this sample; treat them as pointers for the tree audit, not as verdicts.
- Damage-silent nodes include every non-damage node by construction; the list is filtered to kinds that normally emit payloads but still needs reading by hand.
