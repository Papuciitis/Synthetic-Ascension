# Build simulator report: balance revision 1, campaign 2 (durable crowd), 2026-09-19

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
| seg2 | melee | 19 | 308.7 / 1501.9 / 3687.0 | 1.75 / 11.00 / 26.25 | 31 / 120 / 158 | 0.37 | 1 / 37 / 83 | 255 / 1170 / 3458 | 0 / 0 / 80 | 0 / 0 / 0 | 112.7 / 660.7 / 1330.6 |
| seg2 | ranged | 19 | 588.9 / 1015.5 / 1398.2 | 2.00 / 6.25 / 10.12 | 85 / 132 / 164 | 0.53 | 1 / 8 / 49 | 255 / 795 / 1365 | 0 / 1 / 80 | 0 / 0 / 0 | 216.1 / 410.1 / 834.3 |
| seg2 | magic | 19 | 483.0 / 1375.4 / 3129.0 | 3.75 / 9.62 / 23.50 | 109 / 125 / 151 | 0.84 | 0 / 5 / 37 | 412 / 1282 / 3315 | 0 / 0 / 1 | 0 / 0 / 0 | 331.9 / 475.6 / 1583.8 |
| seg2 | all | 57 | 460.3 / 1330.5 / 3137.4 | 2.38 / 9.12 / 24.12 | 51 / 131 / 155 | 0.58 | 0 / 10 / 70 | 345 / 1132 / 3300 | 0 / 0 / 80 | 0 / 0 / 0 | 161.0 / 466.1 / 1229.0 |
| seg4 | melee | 19 | 381.5 / 2402.8 / 5138.4 | 1.88 / 15.88 / 36.00 | 0 / 56 / 106 | 0.00 | 42 / 77 / 100 | 292 / 2070 / 4688 | 0 / 1 / 80 | 0 / 0 / 0 | 47.7 / 300.3 / 658.2 |
| seg4 | ranged | 19 | 992.8 / 1905.1 / 3012.2 | 6.88 / 14.25 / 21.38 | 107 / 129 / 165 | 0.47 | 1 / 21 / 41 | 885 / 1860 / 2512 | 0 / 3 / 80 | 0 / 0 / 0 | 147.7 / 238.1 / 579.3 |
| seg4 | magic | 19 | 738.5 / 2599.9 / 5865.0 | 4.00 / 16.50 / 39.88 | 62 / 119 / 189 | 0.68 | 2 / 14 / 37 | 562 / 2182 / 5235 | 0 / 1 / 1 | 0 / 0 / 0 | 142.0 / 337.9 / 733.1 |
| seg4 | all | 57 | 738.5 / 2150.0 / 4791.2 | 4.12 / 15.00 / 35.00 | 7 / 117 / 148 | 0.39 | 3 / 29 / 96 | 555 / 1950 / 4560 | 0 / 1 / 80 | 0 / 0 / 0 | 113.5 / 283.2 / 642.3 |
| seg6 | melee | 24 | 1111.7 / 4256.7 / 6516.0 | 6.25 / 27.88 / 44.00 | 0 / 0 / 112 | 0.00 | 41 / 93 / 100 | 675 / 3428 / 5738 | 0 / 1 / 80 | 0 / 0 / 2 | 69.5 / 266.0 / 495.8 |
| seg6 | ranged | 22 | 1840.5 / 2518.6 / 4137.6 | 12.12 / 19.50 / 30.12 | 92 / 130 / 162 | 0.45 | 1 / 20 / 55 | 1590 / 2512 / 3960 | 1 / 3 / 80 | 0 / 0 / 1 | 115.2 / 170.0 / 269.9 |
| seg6 | magic | 22 | 2345.5 / 5200.2 / 6513.7 | 15.25 / 35.75 / 45.50 | 36 / 110 / 158 | 0.59 | 1 / 16 / 61 | 2122 / 4882 / 6015 | 0 / 1 / 1 | 0 / 0 / 1 | 154.8 / 325.9 / 409.2 |
| seg6 | all | 68 | 1628.9 / 3715.1 / 6509.9 | 12.00 / 26.50 / 44.00 | 0 / 97 / 151 | 0.34 | 1 / 41 / 100 | 1538 / 3458 / 5715 | 0 / 1 / 80 | 0 / 0 / 1 | 101.8 / 232.2 / 427.6 |
| seg9 | melee | 22 | 3573.9 / 4959.7 / 7264.1 | 24.00 / 30.75 / 45.38 | 0 / 92 / 159 | 0.05 | 16 / 52 / 100 | 3150 / 3982 / 6172 | 0 / 1 / 80 | 0 / 1 / 2 | 111.7 / 204.7 / 344.8 |
| seg9 | ranged | 26 | 1069.9 / 4139.9 / 6037.0 | 7.38 / 25.00 / 38.12 | 100 / 133 / 167 | 0.35 | 5 / 31 / 51 | 742 / 3308 / 5115 | 0 / 1 / 80 | 0 / 0 / 1 | 60.8 / 146.1 / 192.9 |
| seg9 | magic | 16 | 3725.1 / 5691.4 / 7598.7 | 26.38 / 37.50 / 44.62 | 12 / 77 / 141 | 0.62 | 1 / 7 / 94 | 3525 / 5250 / 5992 | 0 / 1 / 80 | 0 / 0 / 1 | 116.4 / 177.9 / 237.5 |
| seg9 | all | 64 | 2300.2 / 4959.7 / 7223.2 | 14.25 / 30.75 / 44.62 | 46 / 103 / 160 | 0.31 | 2 / 35 / 77 | 1852 / 4005 / 5992 | 0 / 1 / 80 | 0 / 1 / 2 | 89.2 / 173.3 / 237.5 |
| seg12 | melee | 18 | 2964.8 / 6585.3 / 7588.6 | 19.88 / 42.12 / 47.25 | 0 / 50 / 86 | 0.06 | 61 / 84 / 100 | 2625 / 5640 / 6510 | 0 / 1 / 80 | 1 / 1 / 2 | 46.4 / 100.9 / 118.6 |
| seg12 | ranged | 16 | 3490.0 / 6094.4 / 6711.3 | 23.25 / 37.25 / 41.75 | 96 / 123 / 192 | 0.75 | 2 / 8 / 60 | 3000 / 5048 / 5580 | 0 / 1 / 80 | 1 / 1 / 2 | 54.5 / 95.2 / 104.9 |
| seg12 | magic | 16 | 5413.1 / 7386.2 / 8016.5 | 35.00 / 43.25 / 46.00 | 16 / 60 / 108 | 0.25 | 1 / 30 / 75 | 4658 / 5842 / 6232 | 0 / 1 / 80 | 1 / 1 / 2 | 84.6 / 115.6 / 125.5 |
| seg12 | all | 50 | 3184.5 / 6553.2 / 7835.0 | 22.00 / 40.88 / 46.00 | 0 / 73 / 175 | 0.34 | 2 / 56 / 96 | 2910 / 5370 / 6180 | 0 / 1 / 80 | 1 / 1 / 2 | 49.9 / 101.1 / 122.5 |

## Where the damage comes from (share of enemy HP removed)

| Tier | Core | Native | Tree (ascension) | Sets | Status | Witness | Mixed/unknown |
|---|---|---:|---:|---:|---:|---:|---:|
| seg2 | melee | 20% | 0% | 80% | 0% | 0% | 0% |
| seg2 | ranged | 39% | 33% | 15% | 1% | 0% | 13% |
| seg2 | magic | 34% | 55% | 11% | 0% | 0% | 0% |
| seg4 | melee | 19% | 1% | 80% | 0% | 0% | 0% |
| seg4 | ranged | 38% | 48% | 10% | 0% | 1% | 3% |
| seg4 | magic | 20% | 74% | 6% | 0% | 0% | 0% |
| seg6 | melee | 16% | 7% | 75% | 0% | 2% | 0% |
| seg6 | ranged | 40% | 46% | 8% | 1% | 1% | 4% |
| seg6 | magic | 16% | 81% | 3% | 0% | 0% | 0% |
| seg9 | melee | 21% | 17% | 60% | 0% | 1% | 0% |
| seg9 | ranged | 17% | 65% | 8% | 1% | 4% | 5% |
| seg9 | magic | 8% | 88% | 3% | 0% | 0% | 0% |
| seg12 | melee | 36% | 25% | 36% | 0% | 2% | 1% |
| seg12 | ranged | 23% | 59% | 9% | 1% | 3% | 6% |
| seg12 | magic | 7% | 87% | 5% | 0% | 0% | 0% |

## Node pick rates in random walks (affordable = guided unlock within the tier budget)

Random walks buy uniformly among buyable nodes weighted only by kind, so a pick rate is a structural fact (how often the node is buyable and how long it stays buyable), not a player preference. High rates mark nodes the rules push everyone through; low rates mark nodes the rules rarely expose.

| Nearly always bought when affordable | Kind | Pick rate | Damage lift |
|---|---|---:|---:|
| BA01 | local | 87% | 0.91 |
| BA02 | local | 86% | 1.09 |
| DO01 | local | 86% | 1.17 |

| Rarely bought when affordable | Kind | Pick rate | Guided unlock | Status |
|---|---|---:|---:|---|
| ORV2 | revelation_mutation | 0% | 14600 | implemented |
| G2 | gate | 0% | 53800 | implemented |
| MR1 | fusion | 0% | 6400 | implemented |
| MR2 | fusion | 0% | 7600 | implemented |
| MR3 | fusion | 0% | 7800 | implemented |
| MR4 | fusion | 0% | 8200 | implemented |
| MR7 | fusion | 0% | 6800 | implemented |
| MM1 | fusion | 0% | 9400 | implemented |
| MM2 | fusion | 0% | 6400 | implemented |
| MM4 | fusion | 0% | 9400 | implemented |
| MM7 | fusion | 0% | 6600 | implemented |
| RM2 | fusion | 0% | 10200 | implemented |
| RM5 | fusion | 0% | 6000 | implemented |
| RM6 | fusion | 0% | 7600 | implemented |
| RM8 | fusion | 0% | 17400 | implemented |
| UMR | union | 0% | 23800 | implemented |
| UMM | union | 0% | 21400 | implemented |
| URM | union | 0% | 29000 | implemented |
| MR9 | fusion | 1% | 6800 | implemented |
| MM8 | fusion | 1% | 6800 | implemented |
| MM3 | fusion | 1% | 8400 | implemented |
| MR6 | fusion | 1% | 6000 | implemented |
| RM3 | fusion | 1% | 7600 | implemented |
| RM4 | fusion | 1% | 6000 | implemented |
| RM9 | fusion | 1% | 18600 | implemented |
| INE1 | evolution | 1% | 5800 | implemented |
| BRE2 | evolution | 1% | 5600 | partial |
| EXE1 | evolution | 1% | 6600 | partial |
| BAE1 | evolution | 1% | 5400 | implemented |
| DTV1 | revelation_mutation | 1% | 13000 | implemented |

## Nodes that never attributed damage while owned

A silent node is not necessarily dead: defensive, movement, economy and enabling nodes never emit a payload of their own. Read this with the kind and the lift columns; a damage-kind node (mutation of an attack, fusion, revelation) that stays silent across many builds is the finding.

| Node | Kind | Discipline | Owned in builds | Damage lift | HP-lost lift | Status |
|---|---|---|---:|---:|---:|---|
| IN02 | local | IN | 92 | 1.10 | 0.99 | implemented |
| EX02 | local | EX | 90 | 0.94 | 0.82 | implemented |
| PR01 | local | PR | 90 | 0.98 | 1.03 | implemented |
| EX01 | local | EX | 87 | 1.18 | 0.89 | implemented |
| DO05 | local | DO | 87 | 1.16 | 1.10 | implemented |
| BA01 | local | BA | 85 | 0.91 | 1.05 | implemented |
| BA02 | local | BA | 84 | 1.09 | 0.63 | implemented |
| DO12 | local | DO | 83 | 0.97 | 1.14 | implemented |
| MO01 | local | MO | 82 | 0.97 | 0.85 | implemented |
| PR02 | local | PR | 82 | 1.02 | 1.10 | implemented |
| PR03 | local | PR | 70 | 1.05 | 0.86 | implemented |
| MO04 | local | MO | 67 | 0.91 | 0.94 | implemented |
| EX04 | local | EX | 64 | 1.08 | 0.59 | implemented |
| IN03 | local | IN | 63 | 0.88 | 1.09 | implemented |
| MOQ | active | MO | 62 | 0.98 | 0.06 | implemented |
| OR03 | local | OR | 62 | 0.93 | 1.16 | implemented |
| DTQ | active | DT | 62 | 0.81 | 1.15 | implemented |
| MO03 | local | MO | 61 | 0.71 | 0.94 | implemented |
| DO02 | local | DO | 59 | 1.08 | 0.96 | implemented |
| DO09 | local | DO | 59 | 1.13 | 1.04 | implemented |
| PR05 | local | PR | 58 | 0.87 | 1.05 | implemented |
| DT10 | local | DT | 58 | 0.89 | 1.08 | implemented |
| BA10 | local | BA | 57 | 0.93 | 0.77 | n/a |
| IN05 | local | IN | 57 | 1.04 | 0.90 | implemented |
| BA03 | local | BA | 55 | 0.93 | 0.94 | implemented |
| INQ | active | IN | 55 | 0.93 | 1.15 | implemented |
| OR05 | local | OR | 54 | 0.90 | 1.07 | implemented |
| MO05 | local | MO | 52 | 0.95 | 0.63 | implemented |
| OR06 | local | OR | 52 | 1.02 | 1.00 | implemented |
| MO07 | local | MO | 51 | 0.98 | 1.01 | implemented |
| BA07 | local | BA | 51 | 0.73 | 0.96 | implemented |
| PR06 | local | PR | 51 | 1.14 | 0.88 | implemented |
| IN04 | local | IN | 51 | 0.79 | 1.00 | implemented |
| DT04 | local | DT | 51 | 1.05 | 0.88 | implemented |
| DO06 | local | DO | 51 | 1.21 | 1.02 | implemented |
| BR03 | local | BR | 50 | 0.83 | 1.03 | implemented |
| DT05 | local | DT | 50 | 0.94 | 0.97 | implemented |
| MO08 | local | MO | 49 | 1.22 | 1.07 | implemented |
| PR04 | local | PR | 47 | 1.11 | 0.88 | implemented |
| OR09 | local | OR | 47 | 0.92 | 1.07 | implemented |
| MO06 | local | MO | 46 | 0.87 | 0.76 | implemented |
| EX10 | local | EX | 44 | 1.20 | 0.90 | implemented |
| OR12 | local | OR | 43 | 1.24 | 0.92 | implemented |
| BA08 | local | BA | 42 | 0.97 | 0.97 | implemented |
| BA11 | local | BA | 42 | 1.09 | 1.12 | implemented |
| OR07 | local | OR | 41 | 0.89 | 1.32 | implemented |
| IN10 | local | IN | 41 | 1.09 | 0.91 | implemented |
| DT09 | local | DT | 41 | 0.99 | 1.10 | implemented |
| BA09 | local | BA | 40 | 1.05 | 0.79 | implemented |
| BA12 | local | BA | 40 | 1.05 | 0.86 | implemented |
| DT07 | local | DT | 40 | 1.09 | 0.69 | implemented |
| MO10 | local | MO | 38 | 0.75 | 0.73 | implemented |
| MO09 | local | MO | 37 | 0.78 | 0.89 | implemented |
| PR10 | local | PR | 37 | 1.34 | 0.90 | implemented |
| BR07 | local | BR | 37 | 0.85 | 0.95 | implemented |
| EX08 | local | EX | 36 | 1.33 | 1.14 | implemented |
| DO10 | local | DO | 36 | 0.96 | 1.10 | partial |
| MO11 | local | MO | 35 | 0.61 | 1.07 | implemented |
| MOQ1 | mutation | MO | 35 | 1.01 | 0.33 | implemented |
| MOQ2 | mutation | MO | 35 | 0.87 | 0.96 | implemented |

## Nodes by mean share of a build's damage while owned

| Node | Kind | Owned in | Mean share | Damage lift | Cost |
|---|---|---:|---:|---:|---:|
| DOF1 | fork | 24 | 22.9% | 0.94 | 800 |
| EX05 | local | 47 | 18.8% | 2.07 | 400 |
| OR04 | local | 61 | 17.6% | 1.17 | 400 |
| MM2 | fusion | 6 | 15.2% | - | 1800 |
| DO01 | local | 96 | 14.9% | 1.17 | 200 |
| DO04 | local | 44 | 14.6% | 1.09 | 400 |
| DOK2 | keystone | 25 | 14.1% | 1.29 | 1200 |
| IN09 | local | 38 | 13.6% | 0.93 | 800 |
| DTE2 | evolution | 8 | 13.3% | 1.10 | 0 |
| OR01 | local | 89 | 12.4% | 0.98 | 200 |
| DT08 | local | 33 | 11.9% | 0.98 | 800 |
| DO07 | local | 54 | 10.8% | 1.14 | 400 |
| PR07 | local | 42 | 7.6% | 1.02 | 400 |
| EX06 | local | 59 | 7.5% | 0.91 | 400 |
| BAV | revelation | 14 | 7.0% | 1.54 | 4800 |
| EXC | catastrophe | 22 | 6.9% | 1.00 | 2400 |
| BR09 | local | 41 | 6.9% | 0.86 | 800 |
| IN01 | local | 87 | 6.8% | 0.99 | 200 |
| DTQ6 | mutation | 29 | 6.4% | 0.98 | 600 |
| BR04 | local | 63 | 6.2% | 0.83 | 400 |
| IN06 | local | 68 | 5.5% | 1.03 | 400 |
| EX03 | local | 56 | 5.4% | 1.14 | 400 |
| DO03 | local | 61 | 4.7% | 1.10 | 400 |
| ORF1 | fork | 19 | 4.7% | 1.08 | 800 |
| DT01 | local | 93 | 4.5% | 1.20 | 200 |
| BR01 | local | 98 | 3.9% | 0.90 | 200 |
| BAC | catastrophe | 22 | 3.7% | 1.07 | 2400 |
| DTV2 | revelation_mutation | 4 | 3.6% | 0.89 | 1800 |
| BR05 | local | 70 | 3.3% | 1.08 | 400 |
| EXV | revelation | 22 | 3.3% | 1.50 | 4800 |

## Outliers within a tier (candidates for runaway synergies)

| Build | Core | Tier | Enemy HP/s | z (tier) | Kills/s | HP lost | Deaths | Q/V | Spent | Top origins |
|---|---|---|---:|---:|---:|---:|---:|---|---:|---|
| random magic seg2 #6 | magic | seg2 | 4751 | 3.1 | 32.62 | 134 | 1 | 1/0 | 3000 | ascension:DO01 13399, native:magic 10459, ascension:DO04 9946 |
| random magic seg4 #13 | magic | seg4 | 6845 | 2.9 | 41.25 | 62 | 1 | 1/0 | 8000 | ascension:IN09 35234, native:magic 8362, ascension:DO01 8256 |
| random magic seg12 #7 | magic | seg12 | 10005 | 2.4 | 47.50 | 0 | 0 | 0/2 | 64000 | ascension:IN09 23995, ascension:DOF1 9256, ascension:DO04 7730 |
| random magic seg9 #9 | magic | seg9 | 9046 | 2.3 | 47.50 | 0 | 0 | 1/0 | 32000 | ascension:IN09 18747, ascension:IN01 17192, ascension:DOF1 16255 |
| random melee seg2 #10 | melee | seg2 | 3821 | 2.2 | 27.75 | 120 | 0 | 0/0 | 3000 | set:lattice:6 28415, native:melee 2153 |
| random magic seg4 #9 | magic | seg4 | 5865 | 2.2 | 39.88 | 119 | 1 | 80/0 | 8000 | ascension:DOK2 25997, ascension:DO01 6827, ascension:DO08 6477 |
| random melee seg2 #6 | melee | seg2 | 3687 | 2.1 | 25.00 | 62 | 0 | 80/0 | 3000 | set:lattice:6 27302, native:melee 2193 |
| random melee seg6 #14 | melee | seg6 | 7933 | 2.1 | 47.00 | 0 | 0 | 1/2 | 16000 | set:lattice:6 35424, native:melee 18787, ascension:EXC 3473 |

## Node pairs enriched among the top decile builds of their tier

| Pair | Builds with pair | In top decile | Lift |
|---|---:|---:|---:|
| DOF1 + DOK2 | 7 | 6 | 9.4x |
| DOK2 + pick.M3 | 6 | 4 | 7.3x |
| DOC + DTQ5 | 6 | 4 | 7.3x |
| DOV + DTQ5 | 6 | 4 | 7.3x |
| DTQ5 + INC | 6 | 4 | 7.3x |
| DOF1 + INQ4 | 6 | 4 | 7.3x |
| DOF1 + pick.D3 | 5 | 3 | 6.6x |
| DOF1 + INA | 5 | 3 | 6.6x |
| DOS2 + DT12 | 5 | 3 | 6.6x |
| DTS1 + INA | 5 | 3 | 6.6x |
| DOF1 + DOS2 | 5 | 3 | 6.6x |
| DTK2 + DTQ5 | 5 | 3 | 6.6x |
| DTQ5 + IN12 | 7 | 4 | 6.3x |
| DTQ5 + INK2 | 7 | 4 | 6.3x |
| DTQ5 + INV | 7 | 4 | 6.3x |
| INA + INK2 | 7 | 4 | 6.3x |
| DOS2 + DT09 | 7 | 4 | 6.3x |
| DOS2 + DTQ6 | 7 | 4 | 6.3x |
| DT09 + INA | 7 | 4 | 6.3x |
| DOC + DOK2 | 9 | 5 | 6.1x |
| INK2 + INQ4 | 9 | 5 | 6.1x |
| DO08 + DOK2 | 20 | 10 | 5.5x |
| DO06 + DTQ5 | 10 | 5 | 5.5x |
| DOF1 + DTQ6 | 8 | 4 | 5.5x |
| DOQ1 + DTQ5 | 6 | 3 | 5.5x |

## Authored presets and routes

| Build | Core | Tier | Nodes | Spent | Enemy HP/s | Kills/s | HP lost | Deaths | Q/V | Native / tree / sets share | Frame p95 ms |
|---|---|---|---:|---:|---:|---:|---:|---:|---|---|---:|
| Authored: Loaded Coin | magic | seg6 | 15 | 13600 | 2901 | 21.00 | 119 | 0 | 1/1 | 12 / 88 / 0% | 1.3 |
| Authored: Mass Grave | magic | seg6 | 15 | 12800 | 6508 | 45.50 | 5 | 0 | 1/2 | 5 / 91 / 4% | 1.9 |
| Authored: Sigil Web | magic | seg6 | 14 | 12400 | 1920 | 13.25 | 110 | 0 | 1/0 | 78 / 10 / 11% | 2.7 |
| Distortion developed | magic | seg4 | 12 | 6400 | 1181 | 8.62 | 139 | 0 | 1/0 | 29 / 70 / 1% | 1.1 |
| Distortion early | magic | seg2 | 5 | 1000 | 472 | 3.75 | 125 | 1 | 0/0 | 72 / 27 / 1% | 1.1 |
| Distortion pure | magic | seg6 | 16 | 14800 | 4791 | 36.00 | 84 | 0 | 1/1 | 28 / 69 / 2% | 2.4 |
| Dominion developed | magic | seg4 | 12 | 5600 | 2062 | 13.25 | 137 | 1 | 1/0 | 18 / 82 / 0% | 2.0 |
| Dominion early | magic | seg2 | 5 | 1200 | 2755 | 19.88 | 109 | 1 | 0/0 | 41 / 56 / 3% | 3.3 |
| Dominion pure | magic | seg6 | 16 | 14000 | 5200 | 36.00 | 86 | 0 | 1/1 | 7 / 87 / 6% | 2.3 |
| Invocation developed | magic | seg4 | 11 | 5200 | 738 | 4.00 | 119 | 1 | 1/0 | 51 / 48 / 1% | 1.5 |
| Invocation early | magic | seg2 | 5 | 1000 | 921 | 6.50 | 134 | 1 | 0/0 | 43 / 0 / 56% | 1.1 |
| Invocation pure | magic | seg6 | 15 | 13600 | 1660 | 13.50 | 111 | 1 | 1/0 | 70 / 14 / 13% | 2.7 |
| Ascendant: Three-Core avalanche | melee | seg12 | 51 | 71000 | 7161 | 44.50 | 73 | 0 | 1/2 | 12 / 51 / 29% | 1.7 |
| Authored: Blood domino | melee | seg6 | 14 | 12000 | 5957 | 44.00 | 79 | 0 | 1/2 | 12 / 10 / 78% | 5.8 |
| Authored: Bomb suit | melee | seg6 | 15 | 13000 | 5960 | 42.00 | 51 | 0 | 80/1 | 4 / 6 / 89% | 6.3 |
| Authored: Corpse artillery | melee | seg9 | 20 | 16400 | 5654 | 37.75 | 163 | 1 | 1/1 | 15 / 44 / 40% | 1.5 |
| Authored: Death Debt | melee | seg9 | 26 | 20600 | 4217 | 30.62 | 184 | 0 | 1/1 | 33 / 62 / 0% | 1.8 |
| Authored: Endless Lunge | melee | seg6 | 13 | 11600 | 6516 | 41.00 | 0 | 0 | 1/1 | 4 / 0 / 96% | 7.8 |
| Authored: Running guns | melee | seg6 | 19 | 15800 | 2647 | 18.75 | 0 | 0 | 1/1 | 11 / 5 / 80% | 1.4 |
| Authored: Three-Core avalanche | melee | seg12 | 51 | 71000 | 6585 | 44.75 | 73 | 0 | 1/2 | 22 / 44 / 27% | 1.6 |
| Bastion developed | melee | seg4 | 12 | 5800 | 3772 | 29.75 | 94 | 0 | 80/0 | 7 / 0 / 93% | 6.3 |
| Bastion early | melee | seg2 | 5 | 1000 | 309 | 1.88 | 155 | 1 | 0/0 | 98 / 0 / 2% | 1.0 |
| Bastion pure | melee | seg6 | 16 | 14200 | 1258 | 7.50 | 90 | 0 | 80/0 | 24 / 75 / 1% | 1.2 |
| Execution developed | melee | seg4 | 11 | 4800 | 1235 | 9.75 | 30 | 0 | 1/0 | 99 / 0 / 1% | 1.0 |
| Execution early | melee | seg2 | 5 | 1000 | 1376 | 8.88 | 51 | 0 | 0/0 | 26 / 0 / 74% | 1.2 |
| Execution pure | melee | seg6 | 15 | 13200 | 5644 | 44.38 | 14 | 0 | 1/2 | 12 / 12 / 76% | 4.9 |
| Hybrid: Corpse artillery | melee | seg9 | 20 | 16400 | 6934 | 47.38 | 79 | 0 | 1/2 | 8 / 16 / 75% | 6.0 |
| Hybrid: Death Debt | melee | seg9 | 26 | 20600 | 4429 | 30.75 | 92 | 0 | 1/1 | 40 / 55 / 0% | 1.5 |
| Hybrid: Death Debt, melee side | melee | seg9 | 23 | 19800 | 4960 | 30.38 | 102 | 0 | 1/1 | 36 / 59 / 0% | 1.4 |
| Hybrid: Running guns | melee | seg6 | 19 | 15800 | 5727 | 39.62 | 0 | 0 | 1/1 | 4 / 2 / 93% | 7.3 |
| Momentum developed | melee | seg4 | 10 | 4400 | 3693 | 27.62 | 0 | 0 | 1/0 | 6 / 0 / 94% | 5.2 |
| Momentum early | melee | seg2 | 5 | 1000 | 1331 | 8.38 | 51 | 0 | 0/0 | 19 / 0 / 81% | 1.0 |
| Momentum pure | melee | seg6 | 14 | 12800 | 2319 | 17.00 | 0 | 0 | 1/0 | 12 / 0 / 88% | 1.1 |
| Route: Death Debt, melee side | melee | seg9 | 23 | 19800 | 7223 | 44.62 | 159 | 0 | 1/2 | 9 / 12 / 77% | 5.4 |
| Authored: Bullet Hell | ranged | seg6 | 15 | 13200 | 1840 | 14.50 | 169 | 1 | 1/0 | 13 / 39 / 42% | 0.8 |
| Authored: Carpet Bomb | ranged | seg6 | 14 | 12400 | 4138 | 30.25 | 150 | 1 | 5/1 | 35 / 60 / 4% | 2.1 |
| Authored: Kill Line | ranged | seg6 | 15 | 12800 | 711 | 4.38 | 162 | 0 | 80/0 | 68 / 30 / 0% | 1.0 |
| Authored: Runes and mines | ranged | seg9 | 22 | 18000 | 3185 | 20.25 | 159 | 0 | 2/1 | 6 / 88 / 0% | 0.8 |
| Authored: Spell-loaded rail | ranged | seg9 | 24 | 20200 | 961 | 4.88 | 101 | 0 | 80/0 | 55 / 15 / 0% | 0.9 |
| Authored: Stormwire | ranged | seg9 | 24 | 20600 | 3640 | 20.12 | 118 | 0 | 1/1 | 5 / 83 / 0% | 0.9 |
| Barrage developed | ranged | seg4 | 12 | 6000 | 1083 | 7.38 | 109 | 0 | 1/0 | 19 / 67 / 1% | 0.7 |
| Barrage early | ranged | seg2 | 5 | 1000 | 589 | 3.62 | 103 | 0 | 0/0 | 30 / 53 / 1% | 0.8 |
| Barrage pure | ranged | seg6 | 16 | 14400 | 2245 | 18.12 | 142 | 1 | 1/1 | 58 / 29 / 8% | 2.1 |
| Hybrid: Kill Feed, ranged side | ranged | seg9 | 21 | 18000 | 1149 | 7.75 | 141 | 1 | 1/0 | 17 / 53 / 1% | 0.8 |
| Hybrid: Runes and mines | ranged | seg9 | 22 | 18000 | 3453 | 23.62 | 145 | 1 | 6/1 | 43 / 43 / 6% | 2.2 |
| Hybrid: Spell-loaded rail | ranged | seg9 | 24 | 20200 | 826 | 4.12 | 148 | 1 | 80/0 | 61 / 11 / 0% | 0.9 |
| Hybrid: Stormwire | ranged | seg9 | 24 | 20600 | 4966 | 30.12 | 167 | 1 | 1/1 | 5 / 66 / 21% | 1.0 |
| Hybrid: Wildfire, ranged side | ranged | seg9 | 20 | 17600 | 2220 | 14.25 | 98 | 0 | 1/0 | 11 / 27 / 48% | 1.1 |
| Ordnance developed | ranged | seg4 | 11 | 5200 | 3012 | 21.38 | 165 | 1 | 3/0 | 9 / 69 / 22% | 0.9 |
| Ordnance early | ranged | seg2 | 5 | 1000 | 834 | 6.00 | 135 | 0 | 0/0 | 28 / 71 / 1% | 0.8 |
| Ordnance pure | ranged | seg6 | 15 | 13600 | 2866 | 20.75 | 168 | 1 | 3/1 | 8 / 92 / 0% | 0.8 |
| Precision developed | ranged | seg4 | 12 | 5600 | 993 | 6.88 | 130 | 0 | 80/0 | 50 / 9 / 40% | 1.0 |
| Precision early | ranged | seg2 | 5 | 1000 | 1003 | 8.12 | 167 | 0 | 0/0 | 54 / 0 / 44% | 0.7 |
| Precision pure | ranged | seg6 | 16 | 14000 | 2380 | 15.75 | 144 | 1 | 80/0 | 84 / 9 / 4% | 2.1 |
| Route: Kill Feed, ranged side | ranged | seg9 | 21 | 18000 | 2444 | 10.12 | 106 | 0 | 1/0 | 7 / 22 / 46% | 0.9 |
| Route: Wildfire, ranged side | ranged | seg9 | 20 | 17600 | 1070 | 7.38 | 85 | 0 | 1/0 | 17 / 52 / 1% | 0.9 |

## Tree structure (real purchase rules, unlimited wallet, milestones satisfied)

350 nodes. Unreachable by the guided walk and by every authored route: 0. Guided unlock is what a targeted walk spent before the node became buyable plus its price, an upper bound on the true minimum.

| Dearest nodes to unlock | Kind | Guided unlock |
|---|---|---:|
| ASC | ascendant | 108800 |
| ASC.S1 | sink | 103000 |
| ASC.S2 | sink | 103000 |
| ASC1 | choice | 102000 |
| ASC2 | choice | 102000 |
| ASC3 | choice | 102000 |
| G2 | gate | 53800 |
| URM | union | 29000 |
| UMR | union | 23800 |
| UMM | union | 21400 |
| RM9 | fusion | 18600 |
| RM8 | fusion | 17400 |
| ORV1 | revelation_mutation | 14600 |
| ORV2 | revelation_mutation | 14600 |
| ORV3 | revelation_mutation | 14600 |
| DTV1 | revelation_mutation | 13000 |
| DTV2 | revelation_mutation | 13000 |
| DTV3 | revelation_mutation | 13000 |
| EXV1 | revelation_mutation | 13000 |
| EXV2 | revelation_mutation | 13000 |

Beyond the largest simulated budget (64000): ASC1 (102000), ASC2 (102000), ASC3 (102000), ASC.S1 (103000), ASC.S2 (103000), ASC (108800).

Nodes with conflicts: 46. Implementation status: ambiguous 1, implemented 336, n/a 5, partial 8.

## Simulation cost

| Tier | Frame p50 ms (median over builds) | Frame p95 ms | Frame p99 ms |
|---|---:|---:|---:|
| seg2 | 0.32 | 1.25 | 2.74 |
| seg4 | 0.35 | 2.09 | 3.11 |
| seg6 | 0.36 | 2.35 | 4.08 |
| seg9 | 0.39 | 2.17 | 3.97 |
| seg12 | 0.41 | 2.73 | 4.55 |

## Caveats

- One scripted scenario: no enemy movement or AI, a fixed crowd mix, scripted inputs. Builds that rely on positioning, kiting or timing are under- or over-served by it.
- Gear is a random set at the tier's rank with two random accessories; item stats are balance revision 1 unless the label says otherwise.
- Lifts and pair enrichments are correlational within this sample; treat them as pointers for the tree audit, not as verdicts.
- Damage-silent nodes include every non-damage node by construction; the list is filtered to kinds that normally emit payloads but still needs reading by hand.
