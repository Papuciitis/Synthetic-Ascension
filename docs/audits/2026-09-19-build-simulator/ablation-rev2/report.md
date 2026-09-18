# Build simulator report: ablation of every pure preset at balance revision 2 (items + accessories + sets), 2026-09-19

## Sources and tiers

| Source | Builds |
|---|---:|
| ablation | 130 |
| ablation_base | 9 |
| ablation_repeat | 9 |

| Tier | Segment | Budget | Gear rank | Enemy HP x | Enemy damage x | Builds |
|---|---:|---:|---:|---:|---:|---:|

## Outcome distributions per tier (p10 / p50 / p90)

| Tier | Core | n | Enemy HP/s | Kills/s | HP lost | Deaths (mean) | Min HP % | Followers/min | Q casts | V casts | HP/s per 1k spent |
|---|---|---:|---|---|---|---:|---|---|---|---|---|

## Where the damage comes from (share of enemy HP removed)

| Tier | Core | Native | Tree (ascension) | Sets | Status | Witness | Mixed/unknown |
|---|---|---:|---:|---:|---:|---:|---:|

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

## Nodes by mean share of a build's damage while owned

| Node | Kind | Owned in | Mean share | Damage lift | Cost |
|---|---|---:|---:|---:|---:|

## Outliers within a tier (candidates for runaway synergies)

| Build | Core | Tier | Enemy HP/s | z (tier) | Kills/s | HP lost | Deaths | Q/V | Spent | Top origins |
|---|---|---|---:|---:|---:|---:|---:|---|---:|---|

## Node pairs enriched among the top decile builds of their tier

| Pair | Builds with pair | In top decile | Lift |
|---|---:|---:|---:|

## Authored presets and routes

| Build | Core | Tier | Nodes | Spent | Enemy HP/s | Kills/s | HP lost | Deaths | Q/V | Native / tree / sets share | Frame p95 ms |
|---|---|---|---:|---:|---:|---:|---:|---:|---|---|---:|

## Ablation: each node's contribution to its own authored build

Every pure preset was fought whole, then once per owned node with that node refunded through the real refund rule (dependents leave with it; a refunded Q or V is replaced by another owned one). Same crowd stream and gear as the base. A change inside the preset's noise floor (the repeat row below) is not a finding, and an HP-lost change against a base under 1 HP is shown as an absolute number; a node whose removal changes neither output nor survivability there is a candidate dead node in that build, not a verdict.

| Build | Node removed (with) | Kind | Enemy HP/s | Change | HP lost | Change | Deaths | Casts Q/V | Status |
|---|---|---|---:|---:|---:|---:|---:|---|---|
| Barrage pure | BR01 (+BRC, BRV) | local | 1210 | -5% | 222 | -3% | 0 | 1/0 | implemented |
| Barrage pure | BR02 | local | 1254 | -2% | 226 | -1% | 0 | 1/0 | implemented |
| Barrage pure | BR04 | local | 1052 | -18% | 249 | +9% | 0 | 1/0 | implemented |
| Barrage pure | BR05 (+BR10, BRE2) | local | 1254 | -2% | 222 | -3% | 0 | 1/0 | implemented |
| Barrage pure | BR08 | local | 1262 | -1% | 248 | +8% | 0 | 1/0 | implemented |
| Barrage pure | BR09 (+BR10, BRE2) | local | 1174 | -8% | 217 | -5% | 0 | 1/0 | implemented |
| Barrage pure | BR10 (+BRE2) | local | 1320 | +4% | 232 | +1% | 0 | 1/0 | implemented |
| Barrage pure | BR11 | local | 1225 | -4% | 224 | -2% | 0 | 1/0 | implemented |
| Barrage pure | BRC (+BRV) | catastrophe | 1100 | -14% | 235 | +2% | 0 | 1/0 | implemented |
| Barrage pure | BRE2 | evolution | 1399 | +10% | 225 | -2% | 0 | 1/0 | partial |
| Barrage pure | BRF2 (+BRE2) | fork | 1385 | +9% | 222 | -3% | 0 | 1/0 | implemented |
| Barrage pure | BRK1 | keystone | 1181 | -7% | 207 | -10% | 0 | 1/0 | implemented |
| Barrage pure | BRQ (+BRQ4, BRE2) | active | 1262 | -1% | 234 | +2% | 0 | 0/0 | implemented |
| Barrage pure | BRQ4 (+BRE2) | mutation | 1201 | -6% | 238 | +4% | 1 | 1/0 | implemented |
| Barrage pure | BRV | revelation | 1182 | -7% | 58 | -75% | 0 | 1/0 | implemented |
| Bastion pure | BA01 | local | 1802 | +19% | 125 | -5% | 0 | 1/0 | implemented |
| Bastion pure | BA02 | local | 568 | -62% | 156 | +18% | 0 | 1/0 | implemented |
| Bastion pure | BA03 | local | 1504 | -0% | 138 | +5% | 0 | 1/0 | implemented |
| Bastion pure | BA04 (+BAF2, BAC, BAV, BAE2) | local | 570 | -62% | 153 | +16% | 0 | 1/0 | implemented |
| Bastion pure | BA08 | local | 1509 | +0% | 132 | +0% | 0 | 1/0 | implemented |
| Bastion pure | BA09 | local | 1509 | +0% | 132 | +0% | 0 | 1/0 | implemented |
| Bastion pure | BA10 | local | 1509 | +0% | 132 | +0% | 0 | 1/0 | n/a |
| Bastion pure | BAC (+BAV) | catastrophe | 771 | -49% | 102 | -23% | 0 | 1/0 | implemented |
| Bastion pure | BAE2 | evolution | 1509 | +0% | 132 | +0% | 0 | 1/0 | implemented |
| Bastion pure | BAF2 (+BAE2) | fork | 570 | -62% | 153 | +16% | 0 | 1/0 | implemented |
| Bastion pure | BAK1 | keystone | 489 | -68% | 200 | +51% | 0 | 1/0 | implemented |
| Bastion pure | BAQ (+BAQ2, BAQ4, BAE2) | active | 1425 | -6% | 156 | +18% | 0 | 0/0 | implemented |
| Bastion pure | BAQ2 (+BAE2) | mutation | 1507 | -0% | 132 | +0% | 0 | 1/0 | implemented |
| Bastion pure | BAQ4 (+BAE2) | mutation | 1509 | +0% | 132 | +0% | 0 | 1/0 | implemented |
| Bastion pure | BAV | revelation | 1509 | +0% | 132 | +0% | 0 | 1/0 | implemented |
| Distortion pure | DT01 | local | 4895 | +8% | 126 | +6% | 0 | 1/1 | implemented |
| Distortion pure | DT02 | local | 4552 | +1% | 114 | -4% | 0 | 1/1 | implemented |
| Distortion pure | DT03 (+DT08, DT12, DTC, DTV) | local | 4419 | -2% | 149 | +26% | 0 | 1/0 | implemented |
| Distortion pure | DT06 (+DT09, DT12, DTF2, DTC, DTV, DTE2) | local | 3095 | -31% | 132 | +11% | 0 | 1/0 | implemented |
| Distortion pure | DT08 (+DT12) | local | 4758 | +5% | 132 | +11% | 0 | 1/1 | implemented |
| Distortion pure | DT09 (+DTE2) | local | 3704 | -18% | 158 | +33% | 0 | 1/1 | implemented |
| Distortion pure | DT10 (+DT08, DT12, DTC, DTV) | local | 4785 | +6% | 114 | -4% | 0 | 1/0 | implemented |
| Distortion pure | DT12 | local | 4933 | +9% | 123 | +4% | 0 | 1/1 | implemented |
| Distortion pure | DTC (+DTV) | catastrophe | 4881 | +8% | 132 | +11% | 0 | 1/0 | implemented |
| Distortion pure | DTE2 | evolution | 4479 | -1% | 158 | +33% | 0 | 1/1 | implemented |
| Distortion pure | DTF2 (+DTE2) | fork | 3262 | -28% | 132 | +11% | 0 | 1/1 | implemented |
| Distortion pure | DTK1 | keystone | 4878 | +8% | 145 | +22% | 0 | 1/1 | implemented |
| Distortion pure | DTQ (+DTQ6, DTE2) | active | 3024 | -33% | 149 | +26% | 0 | 0/1 | implemented |
| Distortion pure | DTQ6 (+DTE2) | mutation | 2786 | -38% | 132 | +11% | 0 | 1/1 | implemented |
| Distortion pure | DTV | revelation | 4539 | +1% | 140 | +19% | 0 | 1/0 | implemented |
| Dominion pure | DO01 | local | 5738 | -23% | 150 | +210% | 0 | 1/1 | implemented |
| Dominion pure | DO02 | local | 7247 | -3% | 70 | +45% | 0 | 1/2 | implemented |
| Dominion pure | DO04 | local | 7725 | +3% | 70 | +45% | 0 | 1/2 | implemented |
| Dominion pure | DO05 | local | 8338 | +12% | 85 | +76% | 0 | 1/2 | implemented |
| Dominion pure | DO06 | local | 7661 | +3% | 88 | +82% | 0 | 1/2 | implemented |
| Dominion pure | DO07 (+DOK1, DOC, DOV) | local | 7918 | +6% | 70 | +45% | 0 | 1/0 | implemented |
| Dominion pure | DO08 | local | 7997 | +7% | 95 | +97% | 0 | 1/2 | implemented |
| Dominion pure | DO11 (+DOE1) | local | 6881 | -8% | 101 | +109% | 0 | 1/2 | implemented |
| Dominion pure | DOC (+DOV) | catastrophe | 7635 | +2% | 83 | +73% | 0 | 1/0 | implemented |
| Dominion pure | DOE1 | evolution | 7003 | -6% | 117 | +143% | 0 | 1/2 | implemented |
| Dominion pure | DOF1 (+DOE1) | fork | 5398 | -28% | 173 | +258% | 0 | 1/1 | implemented |
| Dominion pure | DOK1 | keystone | 6901 | -8% | 70 | +45% | 0 | 1/2 | implemented |
| Dominion pure | DOQ (+DOQ6, DOE1) | active | 5713 | -24% | 140 | +191% | 0 | 0/1 | implemented |
| Dominion pure | DOQ6 (+DOE1) | mutation | 7650 | +2% | 123 | +155% | 0 | 1/2 | implemented |
| Dominion pure | DOV | revelation | 7614 | +2% | 73 | +52% | 0 | 1/0 | implemented |
| Execution pure | EX01 (+EX03, EX04, EX05, EX06, EX10, EXQ, EXQ3, EXF2, EXK1, EXC, EXV, EXE2) | local | 2625 | -54% | 46 | +46 abs | 0 | 0/0 | implemented |
| Execution pure | EX02 | local | 5515 | -4% | 0 | +0 abs | 0 | 1/1 | implemented |
| Execution pure | EX03 (+EXF2, EXE2) | local | 5549 | -4% | 132 | +132 abs | 0 | 1/1 | implemented |
| Execution pure | EX04 (+EXK1) | local | 5002 | -13% | 188 | +188 abs | 0 | 1/1 | implemented |
| Execution pure | EX05 | local | 4502 | -22% | 194 | +194 abs | 0 | 1/1 | implemented |
| Execution pure | EX06 | local | 4916 | -15% | 142 | +142 abs | 0 | 1/1 | implemented |
| Execution pure | EX10 (+EXC, EXV) | local | 3766 | -35% | 179 | +179 abs | 0 | 1/0 | implemented |
| Execution pure | EXC (+EXV) | catastrophe | 5278 | -8% | 183 | +183 abs | 0 | 1/0 | implemented |
| Execution pure | EXE2 | evolution | 5391 | -6% | 164 | +164 abs | 0 | 1/1 | implemented |
| Execution pure | EXF2 (+EXE2) | fork | 5646 | -2% | 153 | +153 abs | 0 | 1/1 | implemented |
| Execution pure | EXK1 | keystone | 5572 | -3% | 140 | +140 abs | 0 | 1/1 | implemented |
| Execution pure | EXQ (+EXQ3, EXE2) | active | 5201 | -10% | 144 | +144 abs | 0 | 0/1 | implemented |
| Execution pure | EXQ3 (+EXE2) | mutation | 5361 | -7% | 172 | +172 abs | 0 | 1/1 | implemented |
| Execution pure | EXV | revelation | 5206 | -10% | 156 | +156 abs | 0 | 1/0 | implemented |
| Invocation pure | IN01 | local | 1450 | +6% | 130 | -6% | 0 | 1/0 | implemented |
| Invocation pure | IN02 | local | 1359 | -0% | 122 | -12% | 0 | 1/0 | implemented |
| Invocation pure | IN04 | local | 1302 | -4% | 130 | -6% | 0 | 1/0 | implemented |
| Invocation pure | IN05 (+IN11, INF2, INC, INV, INE2) | local | 1359 | -0% | 138 | +0% | 0 | 1/0 | implemented |
| Invocation pure | IN06 | local | 1156 | -15% | 156 | +14% | 0 | 1/0 | implemented |
| Invocation pure | IN10 (+INC, INV, INE2) | local | 1347 | -1% | 138 | +0% | 0 | 1/0 | implemented |
| Invocation pure | IN11 (+INF2, INE2) | local | 1302 | -5% | 138 | +0% | 0 | 1/0 | implemented |
| Invocation pure | INC (+INV) | catastrophe | 1342 | -2% | 138 | +0% | 0 | 1/0 | implemented |
| Invocation pure | INE2 | evolution | 1320 | -3% | 130 | -6% | 0 | 1/0 | implemented |
| Invocation pure | INF2 (+INE2) | fork | 1368 | +0% | 138 | +0% | 0 | 1/0 | implemented |
| Invocation pure | INK1 | keystone | 1328 | -3% | 130 | -6% | 0 | 1/0 | implemented |
| Invocation pure | INQ (+INQ6, INE2) | active | 1328 | -3% | 145 | +6% | 0 | 0/0 | implemented |
| Invocation pure | INQ6 (+INE2) | mutation | 1432 | +5% | 138 | +0% | 0 | 1/0 | implemented |
| Invocation pure | INV | revelation | 1371 | +1% | 138 | +0% | 0 | 1/0 | implemented |
| Momentum pure | MO01 (+MOC, MOV) | local | 2467 | -1% | 0 | +0 abs | 0 | 1/0 | implemented |
| Momentum pure | MO02 (+MOC, MOV) | local | 2682 | +8% | 0 | +0 abs | 0 | 1/0 | implemented |
| Momentum pure | MO03 (+MOF1, MOC, MOV, MOE1) | local | 2452 | -1% | 0 | +0 abs | 0 | 1/0 | implemented |
| Momentum pure | MO04 (+MO12, MOC, MOV) | local | 2485 | +0% | 0 | +0 abs | 0 | 1/0 | implemented |
| Momentum pure | MO07 (+MO12, MOC, MOV) | local | 2383 | -4% | 0 | +0 abs | 0 | 1/0 | implemented |
| Momentum pure | MO12 (+MOC, MOV) | local | 2403 | -3% | 0 | +0 abs | 0 | 1/0 | implemented |
| Momentum pure | MOC (+MOV) | catastrophe | 2452 | -1% | 0 | +0 abs | 0 | 1/0 | implemented |
| Momentum pure | MOE1 | evolution | 2452 | -1% | 0 | +0 abs | 0 | 1/0 | implemented |
| Momentum pure | MOF1 (+MOE1) | fork | 2441 | -2% | 0 | +0 abs | 0 | 1/0 | implemented |
| Momentum pure | MOK1 | keystone | 2441 | -2% | 0 | +0 abs | 0 | 1/0 | implemented |
| Momentum pure | MOQ (+MOQ1, MOE1) | active | 2452 | -1% | 252 | +252 abs | 0 | 0/0 | implemented |
| Momentum pure | MOQ1 (+MOE1) | mutation | 2441 | -2% | 0 | +0 abs | 0 | 1/0 | implemented |
| Momentum pure | MOV | revelation | 2629 | +6% | 0 | +0 abs | 0 | 1/0 | implemented |
| Ordnance pure | OR01 | local | 1389 | -53% | 143 | +0% | 0 | 1/0 | implemented |
| Ordnance pure | OR02 | local | 2900 | -3% | 177 | +24% | 0 | 1/1 | implemented |
| Ordnance pure | OR03 | local | 2311 | -23% | 119 | -17% | 0 | 1/0 | implemented |
| Ordnance pure | OR04 (+ORC, ORV) | local | 1987 | -33% | 143 | +0% | 0 | 1/0 | implemented |
| Ordnance pure | OR08 (+ORK1) | local | 4202 | +41% | 161 | +13% | 0 | 1/1 | implemented |
| Ordnance pure | OR09 (+ORF1, ORE1) | local | 2534 | -15% | 119 | -17% | 0 | 1/0 | implemented |
| Ordnance pure | OR12 (+ORC, ORV) | local | 1436 | -52% | 143 | +0% | 0 | 1/0 | implemented |
| Ordnance pure | ORC (+ORV) | catastrophe | 3211 | +8% | 185 | +30% | 0 | 1/0 | implemented |
| Ordnance pure | ORE1 | evolution | 2835 | -5% | 151 | +6% | 0 | 1/1 | implemented |
| Ordnance pure | ORF1 (+ORE1) | fork | 2996 | +0% | 180 | +26% | 0 | 1/1 | implemented |
| Ordnance pure | ORK1 | keystone | 3830 | +28% | 161 | +13% | 0 | 1/1 | implemented |
| Ordnance pure | ORQ (+ORQ1, ORE1) | active | 2618 | -12% | 127 | -11% | 0 | 0/1 | implemented |
| Ordnance pure | ORQ1 (+ORE1) | mutation | 2327 | -22% | 143 | +0% | 0 | 1/0 | implemented |
| Ordnance pure | ORV | revelation | 3667 | +23% | 193 | +36% | 0 | 1/0 | implemented |
| Precision pure | PR01 | local | 1719 | -3% | 197 | +0% | 0 | 1/0 | implemented |
| Precision pure | PR02 | local | 1851 | +5% | 207 | +5% | 0 | 1/0 | implemented |
| Precision pure | PR03 (+PR04, PR07, PR09, PR12, PRF1, PRK1, PRC, PRV, PRE1) | local | 384 | -78% | 197 | +0% | 0 | 1/0 | implemented |
| Precision pure | PR04 (+PRE1) | local | 2014 | +14% | 210 | +7% | 0 | 1/0 | implemented |
| Precision pure | PR05 | local | 1824 | +3% | 191 | -3% | 0 | 1/0 | implemented |
| Precision pure | PR07 (+PR12) | local | 1749 | -1% | 174 | -12% | 0 | 1/0 | implemented |
| Precision pure | PR09 | local | 1997 | +13% | 210 | +7% | 0 | 1/0 | implemented |
| Precision pure | PR12 | local | 1857 | +5% | 207 | +5% | 0 | 1/0 | implemented |
| Precision pure | PRC (+PRV) | catastrophe | 1897 | +7% | 196 | -1% | 0 | 1/0 | implemented |
| Precision pure | PRE1 | evolution | 1945 | +10% | 200 | +2% | 0 | 1/0 | implemented |
| Precision pure | PRF1 (+PRE1) | fork | 1895 | +7% | 233 | +18% | 0 | 1/0 | implemented |
| Precision pure | PRK1 | keystone | 1153 | -35% | 194 | -1% | 0 | 1/0 | partial |
| Precision pure | PRQ (+PRQ5, PRE1) | active | 1973 | +12% | 187 | -5% | 0 | 0/0 | implemented |
| Precision pure | PRQ5 (+PRE1) | mutation | 1899 | +7% | 197 | +0% | 0 | 1/0 | implemented |
| Precision pure | PRV | revelation | 1956 | +11% | 200 | +2% | 0 | 1/0 | implemented |

| Build (base) | Enemy HP/s | HP lost | Deaths | Casts Q/V | Repeat on another crowd stream: HP/s, HP lost (noise floor) |
|---|---:|---:|---:|---|---|
| Barrage pure | 1275 | 229 | 0 | 1/0 | 1342 (+5%), 213 (-7%) |
| Bastion pure | 1509 | 132 | 0 | 1/0 | 1422 (-6%), 143 (+8%) |
| Distortion pure | 4515 | 118 | 0 | 1/1 | 5101 (+13%), 176 (+49%) |
| Dominion pure | 7473 | 48 | 0 | 1/2 | 7005 (-6%), 61 (+27%) |
| Execution pure | 5759 | 0 | 0 | 1/1 | 5813 (+1%), 9 (+9 abs) |
| Invocation pure | 1363 | 138 | 0 | 1/0 | 1343 (-1%), 180 (+31%) |
| Momentum pure | 2485 | 0 | 0 | 1/0 | 2691 (+8%), 0 (+0 abs) |
| Ordnance pure | 2982 | 143 | 0 | 1/1 | 3291 (+10%), 145 (+2%) |
| Precision pure | 1769 | 197 | 0 | 1/0 | 1973 (+12%), 207 (+5%) |

## Simulation cost

| Tier | Frame p50 ms (median over builds) | Frame p95 ms | Frame p99 ms |
|---|---:|---:|---:|

## Caveats

- One scripted scenario: no enemy movement or AI, a fixed crowd mix, scripted inputs. Builds that rely on positioning, kiting or timing are under- or over-served by it.
- Gear is a random set at the tier's rank with two random accessories; item stats are balance revision 1 unless the label says otherwise.
- Lifts and pair enrichments are correlational within this sample; treat them as pointers for the tree audit, not as verdicts.
- Damage-silent nodes include every non-damage node by construction; the list is filtered to kinds that normally emit payloads but still needs reading by hand.
