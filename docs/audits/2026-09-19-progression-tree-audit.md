# Progression-tree balance audit (V4 advancement tree), 2026-09-19

Proposed changes only. Nothing in this document has been coded; every
proposal names the evidence it rests on and the measurement that would
confirm it. The tree is `data/ascension/tree_v4.json` (350 nodes, 336
implemented, 8 partial, 5 n/a, 1 ambiguous per `tools/design/v4_status.json`).

## 0. Evidence and its limits

| Source | What it measures | Where |
|---|---|---|
| Structure pass | Every node's reachability, requirement closure, conflicts and a guided-walk unlock cost (an upper bound on the cheapest unlock), judged by `AscensionLedger.can_buy` with unlimited Followers and every milestone satisfied | `docs/audits/2026-09-19-build-simulator/structure-rev1.json` |
| Campaign 2 (item balance revision 1) | 296 builds (37 presets, 16 authored, 3 routes, 240 seeded random walks) x 480 frames; the only run with per-node pick rates | `.../campaign2-rev1/` |
| Campaign 3 (item revision 2, same seed and job list) | Same builds; damage attribution by origin and node, lifts, silent nodes, outliers, pair enrichment | `.../campaign3-rev2/` and `rev1-vs-rev2.md` |
| Ablation (items + accessories + sets, this document's run) | Every pure preset fought whole, then once per owned node with that node refunded through the real refund rule; a repeat on another crowd stream gives each preset's noise floor | `.../ablation-rev2/` |
| Code reads | Four engine paths behind the strangest ablation results (Bastion Stored Force, Ordnance Fracture/Spotter, Barrage SUPPRESSION, Momentum fill) | `core/systems/ascension/engines/` |

Limits that shape every conclusion below:

- **One scripted scenario.** No enemy AI or movement, a fixed 60-body
  crowd, a native strike every fourth frame at a random living target, a
  dash every 90 frames in a random direction, and 480 simulated frames.
  Disciplines that depend on *player movement or aim* are under-served:
  Momentum only gains Momentum from dashes (its travel gain needs the
  player to walk with an enemy within 2L, which the script never does), so
  every 60- and 75-Momentum node is dormant; Precision's Held Breath, Dead
  Center and Deadeye need aimed lines; Bastion's Guard catches only the
  spitters' scripted volleys.
- **Revelations are under-sampled.** V charges naturally 0-2 times in a
  fight, so the nine Revelations and their 27 mutations rarely fire
  (mean pick rate 22% / 7%, and 0-2 owners for most mutations).
- **Campaigns 2 and 3 have a held-Q defect**: Guard (Bastion) and Deadshot
  (Precision) were re-pressed every six frames (80 casts per fight). Their
  campaign numbers are wrong; the ablation run has the fix (one held cast,
  released through the runner's recovery rule).
- **"Silent" means no payload carried the node's own id.** Mutations,
  keystones, forks and most locals modify a parent's payload and are silent
  by construction; the finding is a payload-kind node that stays silent.
- **Lifts are correlational** (mean output of builds that own the node
  over builds of the same tier and Core that do not). The ablation is
  causal for one build each but has a noise floor of about +/-5-13% on
  output and far more on HP lost (a base with 0 HP lost turns any loss
  into a huge percentage). Cross-preset rankings move up to 2x between
  gear seeds and crowd streams (Barrage pure 2572 HP/s in campaign 3, 1275
  in the ablation base), so only the extremes are ranked here.
- **Nothing is tuned from play.** A human playtest of the tree is still
  owed; several proposals below explicitly need one.

## 1. Headline findings, ranked by how much they change the game

### F1. The cross-Core layer is unreachable in practice

Guided unlock costs (upper bounds) against the lab budgets (seg2 3,000 /
seg4 8,000 / seg6 16,000 / seg9 32,000 / seg12 64,000):

| Layer | Guided unlock | First tier that affords it | Pick rate (campaign 2) | Owners in campaign 3 (296 builds) |
|---|---:|---|---:|---:|
| First Gate `G1` | 5,600 | seg4 | 15% | many |
| Fusions (27) | 6,000-18,600 (median 7,600) | seg6-seg9 | 1% (0-4%) | 8 never, 11 owned by 1-2 builds |
| Unions (3) | 21,400-29,000 | seg9 | 0% | 0 |
| Last Gate `G2` | 53,800 | seg12 | 0% | 2 |
| `ASC` | 108,800 | none | - | 2 |
| `ASC1-3`, `ASC.S1-2` | 102,000-103,000 | none | - | 0-2 |

Six nodes cannot be bought within the seg12 budget at all, and the 27
Fusions, the layer the whole hybrid design rests on, are effectively
absent from random walks because they require the second Core (G1
5,600) plus two specific locals, one of which is usually ring 2-3 of the
*foreign* discipline, plus 1,800. The random walk therefore treats every
Fusion as unaffordable until seg6 and even then picks it 1% of the time.
The Union milestone `union_diversity_*` needs three Fusions of one pair
(3 x 1,800 plus their eight prerequisite locals). G2 needs a Revelation
(10,400-12,800 guided) *and* a Fusion; ASC then needs three Revelations
(one per Core) and three Fusions (one per pair) on top of G2.

This is the biggest structural finding: the tree's top third is priced
for an economy the game does not produce (the follower economy audit put
seg9 hoards at about 30-40k).

### F2. Melee's tree is invisible behind the sets

Share of enemy HP removed, campaign 3 (medians over builds):

| Tier | Melee: native / tree / sets | Ranged | Magic |
|---|---|---|---|
| seg2 | 20 / 0 / 80% | 43 / 38 / 15% | 36 / 52 / 12% |
| seg6 | 21 / 6 / 71% | 39 / 47 / 8% | 15 / 82 / 3% |
| seg12 | 44 / 24 / 29% | 21 / 63 / 7% | 8 / 86 / 5% |

At seg2 the melee tree contributes nothing measurable and at seg6 six
percent; Gravemarch's Mass Arrest and Lattice's six-piece do the
killing. The controlled set probe (`set-output-rev2/`: the same 56
authored builds fought once per set, everything else equal) makes the
size of the effect explicit:

| Tier | Core | Conduit share / HP/s | Gravemarch | Lattice |
|---|---|---|---|---|
| seg2 | melee | 2% / 309 | 78% / 1,394 | 92% / 3,462 |
| seg6 | melee | 1% / 622 | 80% / 2,729 | 90% / 5,797 |
| seg6 | ranged | 1% / 1,478 | 37% / 2,122 | 4% / 2,495 |
| seg6 | magic | 0% / 3,845 | 12% / 5,160 | 2% / 4,960 |
| seg12 | melee | 0% / 7,601 | 21% / 7,936 | 55% / 8,293 |

The median spread between the best and worst set for the same build is
1.79x, 19 of 56 builds move by 2x or more on the set alone, and Endless
Lunge reads 352 / 2,472 / 6,023 HP/s under Conduit / Gravemarch /
Lattice. Conduit's six-piece landed 45-92 HP per fight because its
Overclock only listened to `enemy_killed`, which actor-less (proxy)
deaths never emit; that is fixed after this probe (Overclock now primes
on `enemy_defeated` too), so the Conduit column will move on a rerun.
Lattice's numbers are its own. Momentum pure is 87% set damage and in the ablation every one
of its thirteen nodes lands inside the noise floor. Part of this is the
scenario (see the Momentum note above), but Execution pure, whose nodes
do fire, is still 75% sets at seg6. Magic is the mirror image: 82-88%
tree. The set scaling change of balance revision 2 (bounded channels)
does not change the R1-R6 picture, where the set's damage channel is
1.5-2.0.

### F3. Revelations barely happen and two of them are liabilities

V charges 0-2 times per 480-frame fight. Removing RUPTURE (Bastion),
THE HOST (Invocation), BLINK (Momentum) or REWRITE (Distortion) from
their pure builds changes output within noise because V never cast (0
casts) or cast once. Where they do fire, two carry a survivability
price in the correlational data: `INV` THE HOST (HP-lost lift 2.17) and
`BRV` SUPPRESSION (1.62), and `ORV` FIRE MISSION (1.59). The Barrage
ablation row that reads "-75% HP lost without SUPPRESSION" is *not*
evidence (V cast 0 times in both fights; the difference is crowd
stream). At 4,800 Followers plus 10-13k of prerequisites, a Revelation
is the most expensive thing a seg6-seg9 player can buy and the least
observable.

### F4. Foundation nodes at local prices

Refunding one ring-1/2 local collapses whole builds because the
authored routes hang everything off it:

| Build | Node (name) | Dependents that leave with it | Output change |
|---|---|---:|---:|
| Precision pure | `PR03` Penetrator | 9 (`PR04`, `PR07`, `PR09`, `PR12`, `PRF1`, `PRK1`, `PRC`, `PRV`, `PRE1`) | -78% |
| Execution pure | `EX01` Finish | 12 | -54% |
| Ordnance pure | `OR01` Impact Fuse / `OR12` Big One | 0 / 2 | -53% / -52% |
| Bastion pure | `BA02` Return to Sender / `BA04` Full Tank / `BAK1` Anvil | 0 / 4 / 0 | -62% / -62% / -68% |
| Dominion pure | `DO01` Gravity Well | 0 | -23% (HP lost x3) |
| Distortion pure | `DT06` Causal Debt | 6 | -31% |

These are keystones in effect, sold as 200-400 Follower locals with no
UI signal. Refund exists (Hub, shrinking share), so a player can brick a
build by refunding the wrong 400-Follower node.

### F5. Anti-synergies inside authored builds (beyond noise)

- **Bastion: Stored Force starves Full Tank.** `BastionEngine.on_native_fire`
  spends up to 20 Force on every native strike for +0.05D per point
  (`BA01`, at most +1D single-target) unless Force is already 100. Full
  Tank (`BA04`) needs 100 Force for a 3D nova in 2R. With the spend in
  place the pool rarely reaches 100; removing `BA01` raised Bastion
  pure's output +19% (noise floor 6%). Anvil (`BAK1`, double Force gain
  while stationary) is what makes the build work at all (-68% without
  it), which the scripted stationary player over-rewards.
- **Ordnance: three nodes whose removal helps.** Removing `OR08`
  Fracture +41%, `ORK1` Spotter +28%, `ORV` FIRE MISSION +23% (floor
  +10%). Spotter's Beacon shells retarget durable enemies every 0.8 s
  and Fracture fires three 0.6D shrapnel bullets per three distinct
  blasts; no shell queue cap exists in `OrdnanceEngine`, so the
  mechanism is not a cap. This needs a targeted probe (Ordnance pure
  with and without each node on five crowd streams) before any change;
  it is listed because +41% is four times the floor.
- **Precision: One Bullet is the build.** `PRK1` (-35%) and `PR03`
  (-78%) carry the build; removing the Q, the Revelation, `PR04`, `PR09`
  or `PRE1` lands at +7-14% (floor +12%), i.e. Deadshot and JUDGEMENT
  are not measurably pulling their 800 and 4,800 Followers here.
- **Distortion: Bad Penny is the build.** `DTQ6` Bad Penny (-38%),
  `DTQ` Coin (-33%), `DT06` (-31%), `DTF2` Pass It On (-28%), `DT09`
  (-18%); removing `DT01` Twice, `DT12`, `DTK1` Loaded Dice or `DTC`
  Payday reads +8-9% (floor +13%).

### F6. Dead nodes inside their own authored builds (0% change on removal)

Bastion pure: `BA08` Vessel, `BA09` Armor Break, `BA10` Immovable (n/a),
`BAE2` Bomb Bunker, `BAQ2` Counterweight, `BAQ4` Bunker, `BAV` RUPTURE.
Invocation pure: `IN05` Fed by Death, `IN10` Chain Pulse, `IN11` Copy
Rune, `INC` Choir, `INF2` Split Sigils, `INV` THE HOST, `INQ6` (+5%,
inside noise). Momentum pure: every node except Lunge (`MOQ`, whose
removal turns 0 HP lost into 252). Execution pure: `EX02` Mark (-4%),
`EXF2` Blood (-2%), `EXK1` Only the Weak (-3%). Each has a scenario
reason (Vessel needs Force above 100, which needs Overpressure and a
Force source the script starves; Chain Pulse needs a six-target pulse in
an 8-second fight; Mark needs the sim to hit the same target twice) but
together they say the authored "pure" presets carry 4-7 nodes each that
the scenario cannot make matter.

### F7. Ring-1 claims are a tax everyone pays

Campaign 2 pick rates when affordable: `BA01` Stored Force 87%, `BA02`
86%, `DO01` Gravity Well 86%, `PR01` Read 85%, `BR01` Heat 85%, `BR02`
85%, `EX02` Mark 84%, `OR01` 82%, `MO01` Stride 82%. Locals average 50%,
actives 58%. Five of the top nine are "claims" (Stride claims Momentum,
Stored Force claims Force, Heat claims Heat, Read claims Read) that do
nothing alone and are prerequisites for the count gates (`count >= 4`
locals for Q, keystones, forks, sinks, G1). The walk buys them because
they are the only 200-Follower things it can buy, not because they are
good.

### F8. Weak forks and mutations

Correlational lifts with at least 10 owners, output (HP-lost) lift:

- `MOQ4` Fork 0.64 (0.72), `MOF2` Burnout 0.75 (0.36), `ORF2` Guidance
  0.75 (1.46), `PRF2` Smart Rounds 0.78 (1.12), `EXF2` Blood 0.82 (1.87
  versus `EXF1` Meat), `BAQ1` Bulwark 0.75 (1.32), `BAQ3` Mirror 0.82
  (1.23), `BAQ5` Martyr 0.83 (1.38), `BAQ4` Bunker 0.86, `DTQ` Coin 0.77,
  `BA07` Surrounded 0.78, `MOK2` No Brakes 0.87 (1.53), `BRA` Hot Blood
  0.88, `EXQ1` Wide 0.90 (2.80: the riskiest node in the tree), `EXQ4`
  Drop 0.93 (1.61), `MOQ6` Long Lunge 0.94 (1.69).
- Strong: `EX12` Clean Cut 1.58, `EX05` Corpse Bomb 1.56 (21% of its
  owners' damage), `EXQ` Gavel 1.37, `PR10` Dead Center 1.25, `BAQ6`
  Living Rampart 1.24 (0.56), `INQ4` Swarm 1.24 (0.62), `DOK2` Event
  Horizon 1.23 (14% share), `MOQ5` Carry 1.21, `ORK2` Danger Close 1.21,
  `BRQ2` Vented 1.21, `EXQ5` Second Swing 1.20.

Three Guard mutations (Bulwark, Mirror, Martyr) raise damage taken by
23-38% while lowering output, which is the opposite of a defensive
active's promise. Given the held-Q defect in campaigns 2-3 these three
need re-measurement before action; they are listed so the rerun looks
at them first.

### F9. Runaway candidates

- `IN09` Detonate Sigil: the top four outliers of campaign 3 are magic
  random walks whose largest single origin is `IN09` (20-36k damage in a
  fight where the tier median is 7-11k total); it is a ring-3 local at 800.
- `DOF1` Singularity: 25.8% of its owners' damage (the highest mean share
  of any node) and the pair `DOF1 + DOK2` Event Horizon is 7.8x enriched
  in the top decile (Event Horizon makes the Well's acquisition radius the
  whole camera; Singularity compresses six normals at 1.5D and stuns).
- `MM2` Death Debt (fusion): 15.8% share where owned (6 builds).
- `EX05` Corpse Bomb + `EX10` Chain Sentence: the chain executes and
  re-bombs; Execution pure is the only pure build with 0 HP lost at seg6.

### F10. Hybrids are only better because they are richer

Authored hybrids at seg9 (16-20k) reach 5,600-7,017 HP/s; pure presets
at seg6 (12-15k) reach 1,300-7,500. Per 1,000 Followers spent the pure
Dominion/Execution/Distortion builds are the best value in the tree and
the hybrids sit below them. Axioms (the one cross-Core rule per
discipline, 2,400 each) are picked 14% of the time and read 0.88-1.08
lift, with `INA` Echo Chamber and `DOA` Common Ground raising HP lost
(1.54, 1.41). The Witness strike from G1 attributes 1-4% of damage at
seg6-seg12. The design intent (a hybrid is a *different* build, not a
bigger one) is not visible in the data yet, largely because F1 keeps
Fusions and Unions out of every measured build.

## 2. Per-discipline notes

Numbers are the ablation base (items + accessories + sets, seg6 budget,
480 frames) unless marked C3 (campaign 3 median).

| Discipline | Pure base HP/s | HP lost | Set share (C3, pure) | Load-bearing nodes | Dead in own build |
|---|---:|---:|---:|---|---|
| Execution | 5,759 | 0 | 75% | `EX01`, `EX10` (-35%), `EX05` (-22%), `EX06` (-15%), `EX04` (-13%), `EXQ` (-10%), `EXV` (-10%) | `EX02`, `EXF2`, `EXK1` |
| Momentum | 2,485 | 0 | 87% | `MOQ` (survivability only) | all others (scenario) |
| Bastion | 1,509 | 132 | 1% | `BAK1` (-68%), `BA02`/`BA04`/`BAF2` (-62%), `BAC` (-49%) | `BA08`, `BA09`, `BA10`, `BAE2`, `BAQ2`, `BAQ4`, `BAV` |
| Precision | 1,769 | 197 | 4% | `PR03` (-78%), `PRK1` (-35%) | `PRQ`, `PRV`, `PR04`, `PR09`, `PRE1` (inside noise) |
| Barrage | 1,275 | 229 | 8% | `BR04` Hot Rounds (-18%), `BRC` Overload (-14%), `BR09` (-8%), `BRK1` (-7%) | `BRE2`, `BRF2` (+10%, +9%), `BRQ` (-1%) |
| Ordnance | 2,982 | 143 | 0% | `OR01` (-53%), `OR12` (-52%), `OR04` (-33%), `OR03` (-23%), `ORQ1` (-22%), `OR09` (-15%), `ORQ` (-12%) | `OR08`, `ORK1`, `ORV` (removal helps) |
| Invocation | 1,363 | 138 | 10% | `IN06` Echo Shrine (-15%) | `IN05`, `IN10`, `IN11`, `INC`, `INF2`, `INV`, `INK1` |
| Distortion | 4,515 | 118 | 2% | `DTQ6` (-38%), `DTQ` (-33%), `DT06` (-31%), `DTF2` (-28%), `DT09` (-18%) | `DT01`, `DT12`, `DTK1`, `DTC`, `DTV` |
| Dominion | 7,473 | 48 | 5% | `DOF1` (-28%), `DOQ` (-24%), `DO01` (-23%), `DO11` (-8%), `DOK1` (-8%) | `DO04`, `DO05` (+12%), `DO08`, `DOV` |

Reading: Dominion, Execution and Distortion are one class (4,500-7,500
HP/s at seg6); Ordnance and Momentum a second (2,500-3,000); Bastion,
Precision, Barrage and Invocation a third (1,300-1,800). The third class
is exactly the set of disciplines whose fantasy needs the player to do
something the script does not (hold a guard, line up a shot, manage
Heat by stopping fire, fight near Sigils), so the gap is partly real and
partly measurement. A human playtest of those four is the priority.

## 3. Proposed changes

Each row: what, why (finding), how to confirm. Costs are Followers. None
of these is coded.

### 3.1 Cross-Core reach (F1, F10)

| # | Proposal | Why | Confirm |
|---|---|---|---:|
| P1 | `G1` 1,600 -> 1,000; its "four native locals + Q or Keystone" requirement -> "four native locals". | The Q/Keystone clause adds 800-1,200 to every hybrid path; the four locals already prove commitment. Target guided unlock 2,600 (seg2-seg4). | Structure pass: `G1` guided unlock <= 3,000 |
| P2 | Fusions: drop `cores_required` to *either* Core plus G1 (a Witness strike counts as the foreign Core's strike for the Fusion's trigger), keep the two local prerequisites, price 1,800 -> 1,200. | Fusions are the hybrid layer and are owned by 0-2 builds in 296. Their prerequisites should be the two ideas they fuse, not the second Core's ring-2 economy. Target: first Fusion by seg6 (guided <= 8,000). | Structure pass median Fusion unlock <= 8,000; random-walk pick rate > 10% at seg6 |
| P3 | Unions: `at_least: 3` Fusions -> 2, drop the `union_diversity` milestone or make it "two Fusions of that pair from different disciplines", price 6,000 -> 4,000. | Never owned; guided 21-29k is seg9 money for a passive rule. Target guided <= 16,000. | Structure pass; at least one Union in the seg9 random walks |
| P4 | `G2`: require G1 + one Fusion (drop the Revelation), 4,800 -> 3,200. | The Revelation clause alone is 10-13k of prerequisites and Revelations are the least-observed layer (F3). Target guided <= 24,000 (seg9). | Structure pass |
| P5 | `ASC`: 20,000 -> 12,000; require G2 + two Revelations (any Cores) + two Fusions (different pairs) instead of three and three. | Guided 108,800 versus a 64,000 seg12 budget; the ASC sinks and adaptations (5 nodes) are unreachable in any lab tier. Target guided <= 60,000. | Structure pass: no node above the seg12 budget |
| P6 | Axioms 2,400 -> 1,200 and ring 4 -> ring 3. | 14% pick, lifts 0.88-1.08: they are priced as capstones and perform as locals. | Campaign pick rate 30%+; lift unchanged |

### 3.2 Sets versus tree (F2)

| # | Proposal | Why | Confirm |
|---|---|---|---:|
| P7 | Lower Lattice's melee payloads first (Echo Buffer node 1.05 -> 0.75, Afterstrike, the melee triangle), then Gravemarch's (Mass Arrest slam 1.55 -> 1.2, Sunderstep), by 25-30% at R0-R1, and let the revision-2 `damage` channel (1.5 at R1, 2.85 at R15) restore the late game; rerun the set probe after the Conduit fix before touching Conduit. | Lattice supplies 90% of melee damage through seg6 and 55% at seg12; a rank-1 set should not outdamage a 3,000-16,000 Follower tree. Item-side change, kept separate from tree tuning; it also removes Lattice's melee outliers (28k of 30k damage in two seg2 random walks). | Set probe rerun: melee set share at seg6 <= 50%, seg12 <= 20%, same-build spread median <= 1.3x; Execution pure still 0-1 deaths |
| P8 | Melee locals that emit payloads (`EX03` Spillover 0.5D, `EX06` Cleave 0.8D, `MO02` Passing Blade 0.6D, `MO04` Afterimage 0.6D, `BA06` Thorns 0.2-2D) +25% coefficient. | The melee tree's 0.5-0.8D payloads are the smallest in the tree (ranged 0.6-1.0D with pierce and returns, magic 1-1.5D areas). With P7 alone melee output drops; P8 moves the share, not the total. | Melee tree share at seg6 >= 20% with total output within 10% of today |

### 3.3 Revelations (F3)

| # | Proposal | Why | Confirm |
|---|---|---|---:|
| P9 | Revelation price 4,800 -> 3,200; their prerequisite count gate (8 discipline nodes) -> 6. | Guided 10.4-12.8k for something that fires 0-2 times per fight. Target guided <= 8,000 (seg6). | Structure pass; 22% -> 40% pick |
| P10 | V charge: make Revelation charge visible in the sim/telemetry as charge per kill and per damage, then set the natural charge so a seg6 fight yields 2-3 casts. | Everything about Revelations is untestable at 0-2 casts. This is a measurement change first, a tuning change second. | Simulator `v_casts` p50 >= 2 at seg6 |
| P11 | `INV` THE HOST and `BRV` SUPPRESSION: add the operating-cost/safety clause the design spec promised (SUPPRESSION freezes Heat: confirmed in `add_heat`, no Jam possible during it; THE HOST's duplicates should not extend the caster's exposure). Re-measure with P10 before touching numbers. | HP-lost lifts 2.17 and 1.62 are correlational and V-starved; do not tune blind. | Post-P10 ablation of Invocation/Barrage pure, HP lost within the floor |

### 3.4 Foundation nodes and refunds (F4)

| # | Proposal | Why | Confirm |
|---|---|---|---:|
| P12 | Tag `EX01`, `PR03`, `OR01`, `OR12`, `BA02`, `BA04`, `BAK1`, `DO01`, `DT06`, `IN01`, `BR01`, `MO01` as **foundation** in the tree JSON (a `tags` entry) and have the Ascension screen show "N owned nodes depend on this" before a refund, with the dependents' refund total. | Refund is real and shrinking; bricking a build for 400 Followers of refund is the worst outcome the tree can produce. | Screen test: refund confirmation lists dependents |
| P13 | Give the three worst single points of failure a second source: Precision pierce also from `PRF1` Deadeye (already +1 pierce on aligned hits) and from `BR09` Ricochet when owned through G1; Execution's `EX10` Chain Sentence and `EX05` Corpse Bomb accept *any* execute source (Gavel, DECIMATION, Elite Sentence) so `EX01` is a strong start, not the only one; Ordnance's Big One counts Mine blasts. | `PR03` -78%, `EX01` -54%, `OR12` -52%. | Ablation: no local's removal costs more than 40% in its own pure build |

### 3.5 Anti-synergies and dead nodes (F5, F6)

| # | Proposal | Why | Confirm |
|---|---|---|---:|
| P14 | `BA01` Stored Force: the per-strike spend applies only while Force is below 60, or becomes a 10-point spend; Full Tank keeps 100. | Removing Stored Force improved Bastion pure by +19% because its own spend starves Full Tank. | Ablation: `BA01` removal within the floor |
| P15 | `BA08` Vessel, `BA09` Armor Break, `BAQ2` Counterweight, `BAQ4` Bunker, `BAE2` Bomb Bunker: run a Bastion probe with a moving player and projectile-heavy crowd before changing anything; if still dead, merge Vessel into Overpressure (`BAF2`) and Armor Break into Full Tank. | Zero change on removal in the only build authored to use them; the scenario starves Force, so this is a probe first. | Targeted probe |
| P16 | `OR08` Fracture, `ORK1` Spotter, `ORV` FIRE MISSION: five-stream probe with and without each; if the +23-41% holds, Spotter's Beacon shells become *additional* shells (do not consume the Impact Fuse schedule) and Fracture's shrapnel keeps the blast's root so it can chain. | Beyond noise, mechanism unconfirmed; do not tune before the probe. | Probe; then ablation within floor |
| P17 | Invocation: `IN10` Chain Pulse threshold 6 -> 4 distinct enemies; `INC` Choir "three grown Sigils" -> two; `IN05` Fed by Death radius 1.5R -> 2R. | The pure build is the weakest in the tree (1,363 HP/s) and its ring-3/4 nodes never trigger in an 8-second fight; lowering the thresholds makes the discipline's payoff reachable inside one encounter. | Invocation pure >= 2,500 HP/s at seg6, `IN10`/`INC` removal beyond the floor |
| P18 | Momentum: the sim needs a movement script (walk toward the nearest enemy between strikes) before any Momentum change is proposed; the only causal number today is that Lunge is the discipline's survivability. | Every Momentum node is dormant in the scenario. | Simulator change, then ablation |

### 3.6 Ring-1 claims (F7)

| # | Proposal | Why | Confirm |
|---|---|---|---:|
| P19 | Make the discipline's resource claim free with the Core choice (a ring-0 socket the player picks when they first buy any node of that discipline), and fold `MO01` Stride, `BA01` Stored Force, `BR01` Heat, `PR01` Read into their first payload node (Passing Blade, Return to Sender, Fifth Shot, Far Shot). Keep the count gates at 4 but count the free claim. | 82-87% pick rates for nodes that do nothing alone; the 200 Followers are a tax and the walk shows it. | Campaign: ring-1 pick rates fall to the local mean (~50%); no change in tier output |

### 3.7 Forks and mutations (F8)

| # | Proposal | Why | Confirm |
|---|---|---|---:|
| P20 | `MOQ4` Fork (0.64): waves fire on any Lunge endpoint hit, not only elites/bosses. | Lowest lift in the tree; the trigger is elite-only in a normal-heavy game. | Lift >= 0.95 |
| P21 | `ORF2` Guidance (0.75, HP 1.46): the guided target takes automatic Shells *in addition to* the ordinary schedule, capped at one guided Shell per 0.8 s. | Redirecting all automatic Shells to one elite starves the crowd. | Lift >= 0.95 |
| P22 | `EXQ1` Wide (HP-lost 2.80, the riskiest node): keep 2R radius but drop the 2.5D to 2D, or give Wide's landing a 0.3 s stun. | A Gavel mutation that nearly triples damage taken is a trap. | HP-lost lift <= 1.3 |
| P23 | `EXF2` Blood versus `EXF1` Meat: Blood's +0.25D per fresh victim -> +0.5D (cap +3D unchanged). | Fork pairs should be a choice; Blood reads 0.82 lift and 1.87 HP lost. | Both forks 0.95-1.1 |
| P24 | `DTQ` Coin (0.77): Tails' cost 10% HP -> 6%, or Tails also vents pending Debt instantly. | An active that lowers output on average is not an active. | Lift >= 0.95 |
| P25 | Guard mutations `BAQ1` Bulwark, `BAQ3` Mirror, `BAQ5` Martyr: re-measure after the held-Q fix (campaigns 2-3 are invalid for Guard); if the HP-lost lifts stay above 1.2, Bulwark should add prevention, not only cover. | Held-Q defect. | Fresh campaign with the ablation's Q logic |

### 3.8 Runaway candidates (F9)

| # | Proposal | Why | Confirm |
|---|---|---|---:|
| P26 | `IN09` Detonate Sigil: 1.5D + 0.3D per Growth -> 1.0D + 0.25D per Growth, and one detonation per Sigil per 0.5 s. | The four largest outliers in 296 builds are IN09 builds; it is a ring-3 local at 800. | Outlier z <= 2.5 at every tier |
| P27 | `DOF1` Singularity + `DOK2` Event Horizon: Event Horizon's camera-wide acquisition feeds six-normal Singularities on every Well; give Event Horizon a 0.5 s acquisition tick or cap Singularity at one per Well per 2 s. | 25.8% share and the strongest pair enrichment (7.8x); Dominion pure is already the top pure build. | Pair enrichment <= 3x; Dominion pure within 20% of Execution pure |
| P28 | `EX05` Corpse Bomb 15% of victim max HP + 0.5D -> 12% + 0.5D when chained through `EX10` (chain generation >= 1). | 21% share, 1.56 lift; the chain is the fantasy, so cap the chain not the bomb. | Lift 1.2-1.4 |

## 4. What this audit cannot settle (needs a human playtest)

- Whether Bastion, Precision, Barrage and Invocation are weak or only
  weak against a script that does not guard, aim, stop firing or stand in
  Sigils. Their pure presets should be played at seg6 with the recorder's
  extended capture on.
- Whether Revelations *feel* worth 4,800 at 1-2 casts a segment (P9-P11).
- Whether the foundation-node refund warning (P12) reads clearly.
- Whether hybrids after P1-P5 play as different builds rather than richer
  ones (the design's stated intent).

## 5. Suggested order

1. Measurement first: P10 (V charge visibility), P18 (movement script),
   P16/P15 probes, a fresh campaign with the held-Q fix (P25).
2. Structure: P1-P6, P9, P19 (JSON-only changes, verified by the
   structure pass and one campaign).
3. Safety: P12-P13 (UI and second sources).
4. Numbers: P7-P8 (sets versus tree), P14, P17, P20-P24, P26-P28, one at a
   time, each with a same-seed comparison.

Every proposal is reversible and JSON- or coefficient-level except P12
(screen), P13 (rule sources) and P19 (claims), which touch engine code.
