# Ascension Tree — the Follower-funded progression system

**Status:** design, implementable (2026-09-06). Nothing here is in the game yet.
**Source data:** `tools/design/ascension_tree_data.py` (one source of truth for every node); `tools/design/build_ascension_tree.py` regenerates `tools/design/ascension_tree.json`, the mock-up and the node tables in this file.
**Mock-up:** `tools/design/ascension_tree_mockup.html` (open in a browser; no server needed).
**Brainstorm it consolidates:** `SYNTHETIC_ASCENSION_FOLLOWER_ASCENSION_TREE_MEGA_SPEC (1).md` (root). Where this document disagrees with the brainstorm, this document wins; §2 records why.

> Followers should not primarily buy bigger numbers. They should buy permission to violate increasingly fundamental rules of the game.

---

## 1. What this is

The player chooses Melee, Ranged or Magic when the run starts (already true: `data/styles/*.tres`, chosen in `ui/screens/base.tscn`). That style opens a radial tree of nine wedges (three per style; only the starting style's map is on screen). Followers buy nodes outward from the centre: fundamentals, then mechanics, then a specialization ring with forks, keystones and each wedge's active ability, then a ring of Revelations (the screen wipes), then an edge of Witnesses, bridges, endless sinks and the Ascendant. Items keep their job (how the build works); the tree defines what the character has become capable of.

Three things in the current game make this possible without a rewrite:
- Followers already have one choke point (`Global.transaction_followers`), one per-run save block (`attempt_*`), and a reconstruction floor that five systems respect.
- Modifier sources are already runner nodes on the player with a fixed poll/hook surface (`ManifestationRunner` is the template).
- Actives already have a HUD contract (`active_cd_changed`, `hud_key_text`, `get_active_state()`) that binds by runner name.

And two things must change: income has to grow with the run (it is flat today), and belief Power has to stop rewarding hoarding (it caps at 225 Followers today).

---

## 2. Research verdicts

### 2.1 What the referenced systems teach

| System | Works | Fails | Applied here |
|---|---|---|---|
| Path of Exile keystones | Rule change with a real price; long paths are commitment | Travel nodes are stat tax; the web needs external planners | Every Keystone, Revelation and Axiom carries a price line. No node exists only to be walked through: every Small is conditional. |
| Wolcen Gate of Fates | Concentric rings, 3/6/12 sections; "farther = more specialised" reads instantly | Rotating rings: players spent 20 minutes finding the arrows | Fixed geometry, no rotation. Bridges are authored on the gutters between wedges. |
| Enshrouded | Three archetypes around one centre, one connected web | Respec at 1 rune per point makes builds disposable | Only the starting style's map is shown; refunds shrink by segment; Revelations never refund. |
| Last Epoch skill trees | Each active has its own small tree; five slots cap hotkeys | Trees need guides | One Active per wedge with a 3-branch mutation cluster and a capstone needing two; one Q and one V slotted. |
| Hades duo boons, WoW hero talents | Cross-source powers need prerequisites from both sides; hero talents bridge two specs with one theme | Duo offer rate frustrates | Bridges need a Revelation in your style plus the Witness of the other style, and are one themed rule, not access to the other tree. |
| Dota talents, Nova Drift exclusions | Milestone forks and mutual exclusions keep builds distinct | — | One fork per wedge; some keystones exclude each other across wedges (Never Stop vs Anvil vs Sovereign Ground, One Bullet vs Overclock). |
| Diablo 3 paragon | An infinite sink keeps veterans playing | Unbounded mainstat: 7 Greater Rift tiers of power for time played | Sinks are geometric (×1.35 per rank, faster than income) with hard caps on runaway effects. |
| Diablo 4 paragon boards | Legendary nodes and glyph radius make local decisions | Filler bloat; "convoluted" | 17–18 nodes per wedge; ~180 ids per game; no filler. |
| Vampire Survivors, Rogue Legacy 2 | Rank cost += base; labour-cost inflation after a threshold | Hidden global fees; gold-gain upgrades need 10× to break even | Capital costs are fixed per class and ring and escalate per class owned; the next cost is always shown. |
| Brotato endless factor | Scaling that guarantees runs end | — | Attention/world response is the run-ender lever (later); costs never cap income. |
| Hades 2 Grasp | A budget you can never fill | — | One Q and one V slot; buying more than you can slot is allowed, slotting is the real limit. |
| Warframe waybounds | A deep node unbinds to any school at a huge cost | — | Axioms: learned in one wedge, apply to every style you can produce hits with. |
| Cult of the Lamb, Path of Achra | Followers as a living resource with jobs; prayers unlock by thresholds | — | Peak congregation gates the outer rings: hoarding cannot substitute for having been believed in. |
| Idle-game cost math | Costs must grow faster than income so purchases slow but never stop | — | Reach ×1.35 per segment; sinks ×1.35–1.5 per rank; ring bases grow ~×5 per ring. |
| Ordinator, Perkus Maximus, SPERG | Perks change behaviour; baseline is free; no filler | — | Fundamentals are 5–7 conditional nodes per wedge; the baseline attack is never gated. |

### 2.2 Brainstorm verdicts

| Brainstorm idea | Verdict | Why |
|---|---|---|
| "4,000 by segment 2–3 is small money" | Changed | True only because income is flat 1–3 per kill. Income now scales with Reach; prices stay fixed and legible. |
| Delete belief Power | Changed | It is the only current reason to hold Followers. It is re-keyed to peak Followers (spending never lowers it) and capped at +30%. |
| Nine apex screen wipes | Kept, differentiated | Decimation is HP-fraction gated, Total Fire Mission is telegraphed and delayed, The World Breaks First scales with damage taken, The Host multiplies only what you placed, Kneel deals no damage, Line of Judgement is a designation, Consensus Failure has a whitelist and a hangover. |
| Momentum subtree | Kept, unified | It claims the existing `momentum` manifestation meter; items and tree fill the same bar. |
| Invocation "constructs / manifestations" | Renamed | Sigils. Manifestation stays the item-rule word. |
| Consensus Failure "everything favourable" | Bounded | Whitelist (Luck checks, Twice, Debt, projectile denial, melee miss); no cooldown resets; item ICDs kept; 4 s then 6 s of forced failure. |
| Crossfire as a deep node and Absolute Suppression | Merged | Crossfire is Barrage's fork B; Suppression is its timed, capped multiplication. |
| Kneel vs Gravemarch Mass Arrest | Changed | Kneel pulls to the cursor point and deals no damage itself. |
| Bastion "Return to Sender" reflect | Changed | Bastion consumes projectiles into Force; Reflect Shield already parries. |
| "Followers per chained target" | Changed | Percent of current, except where the count is hard-capped (Decimation). |
| Crit and cooldown-reduction smalls | Rejected | No such stats exist. Precision uses per-enemy Reads; Distortion owns Lucky Crit; cooldown nodes name one ability; one new poll (`dash_cooldown_multiplier`). |
| Ordnance drones | Rejected | Minions exist (Spiderlings); Ordnance is placed and delayed, never autonomous. |
| Hybrids "for a duration everything triggers everything" | Changed | Bridges are passive rules with generation caps and a per-wedge bridge-open list. |
| Segment-inflated prices, global purchase fee, per-segment Follower caps, rotating rings, unlimited respec | Rejected | See §3 and §2.1. |
| Ascension Doctrine (segments 3/6/9) | Kept, folded | Free forced picks stay; presented as three sockets at the tree's centre and labelled "Doctrine". |
| Peak vs current Followers | Kept, made load-bearing | `attempt_peak_followers` gates rings and feeds belief Power. |
| Attention / world response | Deferred | Peak titles are recorded so it can be built on later. |
| Added | — | Witness nodes as the hybrid gate; one slotted Q and one V; Heat Is Universal; Sovereign Ground; a per-enemy status registry (Sentenced, Primed, Read, Fractured, Beacon, Linked, Subjugated); Reach; Witness bursts; peak gates. |

---

## 3. Economy

### 3.1 Where the current economy stands (verified in code)

- Income per kill: `randi(follower_reward_min, max)` + 3 for elites + a Luck proc (≤20% for +1); grunt 1, brute 2–3, herald 5–8, bosses 10–14; weighted mean ≈ 1.7 per kill. Spawns run at 1–4 per second, so a segment grosses roughly 6,000 from segment 2 on. Boss arena clear +25, miniboss +8. The overtime decay multiplier bottoms at 0.35 but both kill paths wrap it in `maxi(1, …)`, so a 1-Follower enemy is never devalued.
- Sinks: the shop (~100 per item), vendor refresh 3 × 1.75ⁿ, wager stakes 8/22/55, tithes of 1, and reconstruction `max((10 + 2(seg−1)) × 1.7^deaths, 20% of current)`. Zero Followers on death ends the run.
- Belief Power: `min(0.15, 0.01·√followers)`, capped at 225 Followers.
- Every cost is flat, income is flat, so Followers grow linearly and any large price collapses within a few segments. That is the "order of magnitude out".

### 3.2 Reach (load-bearing shape; ratio tunable 1.30–1.40)

`reach(seg) = 1.35 ^ max(0, seg − 2)` — R(1) = R(2) = 1.

Every recurring Follower quantity in the game is expressed in Reach units. Fiction: each segment is a larger population centre; the HUD reads "SEGMENT 7 · REACH ×11". Followers stay people converted at that scale, never a wallet multiplier.

Applied to: kill rewards (`round_stochastic(roll × reach × overtime)`, which also removes the `maxi(1, …)` floor so Overtime decay finally bites), elite bonus, Herald/Leech drains, tithes (`Global.tithe_unit() = ceil(reach)`), Tithe Bones (22 × reach per HP bar), wager stakes, vendor item values, vendor refresh, and the flat part of reconstruction. Segments 1–2 are numerically unchanged, so the tutorial, the assistant gate and every tested tithe keep working.

| Segment | Reach | Gross this segment | Cumulative | Expected on hand at the Hub |
|---|---:|---:|---:|---:|
| 1 | 1 | 1,500 | 1,500 | 1,400 |
| 2 | 1 | 6,000 | 7,500 | 5,700 |
| 3 | 1.35 | 8,100 | 15,600 | 8,900 |
| 5 | 2.46 | 14,800 | 41,000 | 16,000 |
| 10 | 11.0 | 66,000 | 240,000 | 73,000 |
| 20 | 222 | 1.33M | 5.1M | 1.5M |
| 40 | 89,300 | 536M | 2.07B | 590M |

"On hand" assumes ~75% spent at each Hub and ~10% lost mid-segment. The brainstorm's §38 example (1.84M on hand, Ranged, eyeing a 750k Revelation and a 2.5M bridge) is segment 20–21 on this curve.

### 3.3 Income feel (tunable)

Kills stay 1-ish; the per-enemy numbers in the `.tres` files do not change. Added on top:
- **Witness bursts**: a sliding 0.6 s kill window; every 8th kill inside it grants +6 × reach with reason `witness_burst` and the popup "WITNESSED · +N". Capped by design at ~10–15% of income; no burst before the assistant milestone in segment 1.
- **Objectives**: boss arena 150 × reach, miniboss 50 × reach, each secondary objective 60 × reach (`objective_recruit`), Exit Rite 120 × reach (`exodus`). Ordinary kills should end at ≤55% of income.
- Both kill paths (`EnemyLifecycle.gd` and `EnemyCombatService._finalize_proxy_death`) collapse into one `Global.compute_kill_reward(reward_min, reward_max, elite_bonus, is_elite, luck)` so they cannot drift again.

### 3.4 Belief Power (load-bearing: keyed to peak)

`follower_belief_power() = min(0.30, 0.02 · log2(1 + attempt_peak_followers / 25))`

25 → +2%, 100 → +4.7%, 1k → +10.7%, 16k (s5) → +18.7%, 73k (s10) → +23%, cap +30% around a peak of 800k (s18). Spending on the tree never lowers it, so the hoard incentive is gone while early Followers still matter from minute one. `attempt_peak_followers` is updated only inside `transaction_followers` and emits `peak_followers_changed`. The Run Sheet's BELIEF row (asserted by `RunSheetLedgerTest`) becomes "BELIEF · PEAK 12,400".

### 3.5 Capital costs: fixed bases, escalated per class owned (load-bearing shape; bases tunable)

`cost = base(class, ring) × escalation(class, owned_of_that_class)`

| Class | Base by ring | Escalation | First typical buy | Refundable | Where |
|---|---|---|---|---|---|
| Small | 150 / 300 / 600 (ring 1/2/3), per rank | linear: × (1 + 0.10 n), n = Small ranks owned | Hub after s1 | yes | Hub + Wardstone |
| Mechanic | 2,500 / 4,000 / 12,000 | × 1.15ⁿ | Hub after s2 | yes | Hub + Wardstone |
| Mutation | 25,000 | × 1.25ⁿ | s10+ | yes | Hub + Wardstone |
| Keystone | 35,000 | × 1.5ⁿ | s7–8 | no | Hub |
| Fork | 50,000 | × 1.5ⁿ | s9 | no | Hub |
| Active | 60,000 | × 1.5ⁿ | s9–10 | no | Hub |
| Axiom | 40,000 | × 1.5ⁿ | s9+ | no | Hub |
| Capstone | 80,000 | × 1.25ⁿ | s11+ | no | Hub |
| Revelation | 300,000 | × 2ⁿ | s15–17, then every ~3 segments | no | Hub |
| Witness | 300,000 | × 2ⁿ | s23 | no | Hub |
| Bridge | 2,500,000 | × 2ⁿ | s24 | no | Hub |
| Ascendant | 25,000,000 | unique | s31 | no | Hub |
| Sink | 60,000 | × ratio^rank per line (1.3–1.5) | s16+ | no | Hub + Wardstone |

Why not segment-inflated prices: a price that rises while you farm for it destroys "saving toward X", which the brainstorm's own §38 depends on. Why not a global per-purchase fee: 45 nodes at +3% is an invisible ×3.8 on a Revelation. Per-class escalation is legible ("your third Mechanic costs ×1.32"), never moves while you save, and three Mechanics spread across three wedges cost as much as three deep in one, so the cheap way to reach the Deep ring is to commit. Load-bearing: the ring gradient (150 → 25M), Revelation ×2, sink ratio > Reach ratio.

### 3.6 Peak gates

Your congregation must once have reached the gate; current Followers do not count.

| Gate | Peak required | First cost behind it | Effect on pacing |
|---|---:|---:|---|
| Ring 3 (Prophet) and 4 | 30,000 | 12,000 | one saving Hub around segment 6 |
| Revelation | 500,000 | 300,000 | first Revelation at s16–17 rather than s15 |
| Witness / Bridge | 5,000,000 | 300,000 / 2.5M | s23–24 |
| Ascendant | 50,000,000 | 25M | s31 |

A player who buys something at every Wardstone never accumulates, so the peak never crosses the gate; the gate demands one deliberate hoarding phase while the 20% reconstruction tax makes holding that hoard dangerous. That tension is the design. Peak titles (1k FOUNDER, 10k PROPHET, 100k MOVEMENT, 1M ICON, 10M SOVEREIGN) are HUD flavour today and the hook for Attention later.

### 3.7 Operating costs (three shapes)

- **Actives (Q)**: cooldown only. Charging Followers for the build's bread and butter is "gold with a funny name" and punishes playing your build.
- **Revelations (V)**: charged after resolution, either per target (`2 × reach` per normal, `10 × reach` per elite, bosses free) or as a percent of current Followers with a minimum; both are refused past the reconstruction floor and, for per-target wipes, *partially applied*: the wipe hits only as many targets as you can pay for ("you could only afford to convert 40 of them"). Expected 15–30% of a segment's income for a wipe owner.
- **Insurance-class effects** (Revision, a later "lethal damage consumes Followers" node): percent of current with a minimum and an internal cooldown, always cheaper than dying (20% + flat + position).

### 3.8 Endless sinks

Nine repeatable lines (three per style, listed in §5), `60,000 × ratio^rank`, ratios 1.3–1.5, each with a hard cap where the effect could run away. With sink ratios above the Reach ratio, ranks arrive at roughly 0.9 per segment across all lines (≈25 by segment 40): late ranks buy legibility, not dominance. Sinks unlock only after the first Revelation of their style.

### 3.9 Reconstruction floor

`flat = ceil((10 + 2(seg − 1)) × reach × 1.7^deaths)`, the 20% tax unchanged. Unscaled, the flat term is 48 Followers at segment 20 against 1.5M on hand ("spend to zero before a boss, die for free"); scaled it is 44 at s5, 310 at s10, 10.7k at s20, 7.9M at s40 (~1.5% of a segment's income). Add `Global.can_spend_followers(amount)` and route the five floor-respecting systems plus every tree purchase and every Revelation through it.

### 3.10 Respec

`refund = round(paid × clamp(0.50 × 0.90^(seg − 2), 0.10, 0.50))` — s2 50%, s5 36%, s10 22%, s15 13%, s20+ 10%, on the recorded price, never the current one.
- Only Small, Mechanic and Mutation nodes refund, only at the Hub, and never a node that is the only path to a kept node.
- Forks, Keystones, Actives, Capstones, Axioms, Revelations, Witnesses, bridges and the Ascendant are sworn: no refund control, and choosing one side of a fork writes the sibling into `attempt_ascension_sealed`.
- Refunds do not lower the peak and do not reduce the class-escalation counter (tuition was paid).
- A "Schism" world event granting a one-time full refund of one wedge is v2.

### 3.11 Purchase points

- **Hub** (between segments): the full tree and refunds. A fourth button beside Augments / Inventory / Continue opens `AscensionScreen` as an overlay exactly like Major Choice; if a Doctrine offer is pending, that modal opens first.
- **Wardstone** (mid-segment): an ASCENSION tab in the bag, enabled only while the player stands inside an attuned Wardstone's stability ring (`Global.pulpit_available`, set by the stone). Small, Mechanic, Mutation and Sink nodes only; everything identity-shaping and all refunds are Hub-only. It rides the existing bag pause handoff untouched (`hud.gd::_apply_management_pause`, `_claim_pause_if_free`, `adopt_pause_handoff`), and the tree's `refresh_run_state()` runs while paused. Outside a stone the tab says "Reach a Wardstone to preach."

### 3.12 Worked examples

**Segment 5, Melee / Execution.** Hub 1 (1,400): Heavy Hand ×2 (150, 165). Hub 2 (5,700 + 1,000 carry): First Verdict 2,500, Lower Bar ×2. Hub 3 (8,900 + 3,000): Spillover 4,600 (×1.15), Reservoir ×2. Hub 4: Elite Sentence 7,935, a Small. Hub 5: 20,800 on hand, peak 20,800 < 30,000, so ring 3 is gated; belief +19% Power; buys two Smalls and holds ~17,000. Hub 6: 37,000 on hand, the peak crosses 30k, Bloodletting and then the Gavel come within reach. The gate cost exactly one Hub of patience.

**Segment 20, Ranged / Barrage + Ordnance.** 1.9M on hand, peak 1.9M (Revelation gate met; Witness 5M not). Owned: 18 Small ranks, 8 Mechanics, a fork, 2 Actives, 3 Mutations, 1 Axiom, 2 Revelations (bought at s16 for 300k and s19 for 600k). Reconstruction flat floor 10.7k, 20% reserve 380k. Menu: Mechanic #9 18.4k, Mutation #4 61k, Revelation #3 1.2M, sink ranks 60k / 81k / 109k, Total Fire Mission upkeep ~42k per cast (~3% of income), Witness of the Sign 300k behind a 5M peak (s23–24). Decision: Revelation #3 + a Mutation = 1.26M, leaving 640k above the reserve. That is the brainstorm's §38 list almost verbatim.

---

## 4. Structure

### 4.1 Rings and wedges

| Ring | Name | Radius (mock-up) | Holds |
|---|---|---:|---|
| 0 | CORE | 0 | the style core (free, owned) and three Doctrine sockets (filled by the free picks after segments 3 / 6 / 9) |
| 1 | MORTAL | 150 | Fundamentals: conditional Smalls and the wedge's defining Mechanic |
| 2 | BELIEVER | 290 | Mechanics: the interactions that make the wedge's verb |
| 3 | PROPHET | 440 | Specialization: the fork, the keystone, the Active with its three mutation satellites, the axiom |
| 4 | ICON | 600 | the Revelation and the Active's capstone |
| 5 | ASCENDANT | 760 | sinks (in the wedge), Witnesses and bridges (on the gutters), the Ascendant |

Three 120° wedges per style; the usable span is 100° with 20° gutters that carry the boundary spokes and host the edge nodes. Layout is computed from (subtree, ring, order): nothing is hand-placed, so authoring 200 nodes stays cheap. Only the starting style's map exists; the other two styles are visible only as the Witness and bridge nodes on the gutters.

### 4.2 Node taxonomy

| Type | Ranks | Ring | Refund | Rule |
|---|---|---|---|---|
| Small | 1–3 | 1–3 | yes | One conditional number. Never more than three in a row without a Mechanic adjacent. |
| Mechanic | 1 | 1–3 | yes | Introduces one interaction on an existing hook. |
| Fork | A or B | 3 | no | Buying one seals the sibling for the run. |
| Keystone | 1 | 3 | no | A rule change with an explicit price. Needs ≥5 purchased nodes in its wedge. |
| Active | 1 | 3 | no | The wedge's Q ability. Needs ≥4 nodes in the wedge including a Mechanic. |
| Mutation | 1 | 3 (satellite) | yes | Child of the Active; three per Active. |
| Capstone | 1 | 4 | no | Needs any two of the three mutations. |
| Axiom | 1 | 3 | no | Learned in one wedge, applies to every style you can produce hits with. Needs ≥6 nodes. |
| Revelation | 1 | 4 | no | The wedge's V wipe. Needs ≥8 nodes in the wedge plus its Active; has duration, cooldown, target cap, a "cannot hit" clause and an operating cost. |
| Witness | 1 | 5 | no | Grants another style's core attack as a tree-triggerable secondary (never input-triggered). Needs any Revelation of your style and the 5M peak. |
| Bridge | 1 | 5 | no | Needs any Revelation of your style plus the Witness of the other style. |
| Ascendant | 1 | 5 | no | Needs both bridges of your style. |
| Sink | ∞ | 5 | no | Geometric cost, hard-capped effect. |

### 4.3 Rules

- **Adjacency**: a node opens when any one id in its `req` list is owned (OR), all ids in `req_all` are owned, its wedge count and peak gate are met. The style core is free and pre-owned. Ranks of a Small count as one node for wedge counts.
- **Slotting**: the player may own several Actives and Revelations across the three wedges, but one Q and one V are slotted at a time, changed at the Hub or a Wardstone. A second Revelation in the same style costs its escalated price (×2); the Ascendant allows a second V.
- **Sealing**: forks and cross-wedge exclusive keystones write the excluded ids into `attempt_ascension_sealed`; sealed nodes render struck through and cannot be bought or previewed.
- **Recursion safety**: every generated attack carries a `ProcTag` — origin ∈ {PRIMARY, ACTIVE, REVELATION, SIGIL, BRIDGE}, generation, allowed child categories, remaining budget, and no-self tags (AFTERIMAGE, RETARGET, RICOCHET, FRAGMENT, ORDNANCE_TRIGGER, SIGIL_SPAWN, TWICE, LINK_SHARE, CROSSFIRE). PRIMARY chains stop at generation 2, BRIDGE chains at generation 1. Generation ≥1 never emits `weapon_fired` (a beat is not an attack) but does emit `player_hit_landed`, so items and manifestations still see the hits.
- **Bosses**: every Revelation states its boss rule; none kills or displaces a boss.

---

## 5. The nine wedges

Summary (fantasy · input change · resource · Q · fork · keystone · V):

| Wedge | The player now… | Resource / HUD | Active (Q) | Fork A / B | Keystone | Revelation (V) |
|---|---|---|---|---|---|---|
| Melee · Execution | hunts HP fractions, not bodies | VERDICT threshold | Gavel | Quiet Sentence / Collective Sentence | Only the Weak Die | DECIMATION |
| Melee · Momentum | never stops; dashes through enemies | MOMENTUM (shared meter) | Lunge | Unbroken Motion / Thousand Cuts | Never Stop | NO DISTANCE BETWEEN US |
| Melee · Bastion | walks into crowds and banks Force | FORCE | Guard (hold) | Pressure Vessel / Overpressure | Anvil | THE WORLD BREAKS FIRST |
| Ranged · Precision | keeps hitting one target to Read it | READ | Ballistic Solution | Impossible Shot / Terminal Geometry | One Bullet | LINE OF JUDGEMENT |
| Ranged · Barrage | manages Heat | HEAT | Suppressive Burst | One Weapon, Infinite Bullets / Infinite Weapons, One Target | Overclock | ABSOLUTE SUPPRESSION |
| Ranged · Ordnance | places things before enemies arrive | COORD + mines | Designate | Saturation Coordinates / Walking Barrage | Beacon Doctrine | TOTAL FIRE MISSION |
| Magic · Invocation | chooses where to fight: near Sigils | SIGILS + Echoes | Consecrate | Autonomous Invocation / Recursive Ritual | Inherit the Word | THE HOST |
| Magic · Distortion | gambles on purpose | DEBT + coin | Coin | Revision / Inheritance | Loaded Dice | CONSENSUS FAILURE |
| Magic · Dominion | uses the cursor as a second body | LINKS + zones | Compel | Singularity / Forced Orbit | Sovereign Ground | KNEEL |

Cross-wedge exclusions: Never Stop ⟂ Anvil ⟂ Sovereign Ground (a build cannot both never stop and reward standing still); One Bullet ⟂ Overclock.

### 5.1 Node tables

<!-- NODE_TABLES_START -->
_Generated by `tools/design/build_ascension_tree.py` from `ascension_tree_data.py`; do not edit by hand._

### Melee

#### Melee · Execution — *I touch something and it dies.*

**What the player does differently:** Hunt HP fractions, not bodies: ignore healthy targets, sweep through weakened ones, time Gavel and Decimation for the moment the crowd dips under the Verdict line.  
**HUD:** VERDICT 16% readout; enemies under the threshold get a red tick (reuses the Mark overlay path).

| # | id | ring | type | name | effect | needs | excl | base cost |
|---|---|---|---|---|---|---|---|---|
| 1 | `mel_exe_01` | 1 | small | Heavy Hand | (3 ranks) +6% melee damage per rank. · *requires* mel_core |  |  | 150 |
| 2 | `mel_exe_02` | 1 | mechanic | First Verdict | Grants an execute threshold of 10%: a melee hit that leaves a normal enemy at or below 10% HP kills it, ignoring armor; overkill is captured. · *requires* mel_exe_01 | execute_threshold channel, overkill on EnemyDeathContext |  | 2.5k |
| 3 | `mel_exe_03` | 1 | small | Lower Bar | (3 ranks) +3% execute threshold per rank. · *requires* mel_exe_02 |  |  | 150 |
| 4 | `mel_exe_04` | 2 | mechanic | Spillover | Overkill from a melee kill hits the nearest enemy within 90 px. · *requires* mel_exe_02 | nearest_enemy |  | 4k |
| 5 | `mel_exe_05` | 2 | small | Clean Cut | (2 ranks) Executions refund 25% of slash cooldown per rank. · *requires* mel_exe_03, mel_exe_04 | refund_attack_cooldown API |  | 300 |
| 6 | `mel_exe_06` | 2 | mechanic | Elite Sentence | The execute threshold applies to elites at half value. · *requires* mel_exe_04 |  |  | 4k |
| 7 | `mel_exe_07` | 2 | mechanic | Bloodletting | Each execution grants +2% threshold for 4 s (5 stacks, refreshing). · *requires* mel_exe_05, mel_exe_06 |  |  | 4k |
| 8 | `mel_exe_08` | 2 | small | Reservoir | (2 ranks) Spillover carries +25% of the overkill per rank (base 100%). · *requires* mel_exe_04 |  |  | 300 |
| 9 | `mel_exe_fork_a` | 3 | fork A | Quiet Sentence | Your first hit on any enemy Sentences it for 3 s; a second melee hit on a Sentenced enemy executes at 2x threshold. · *requires* mel_exe_07 | per-handle Sentenced status | mel_exe_fork_b | 50k |
| 10 | `mel_exe_fork_b` | 3 | fork B | Collective Sentence | Executions cleave: 60% of the victim's max HP to enemies in a 70 px arc. · *requires* mel_exe_07 |  | mel_exe_fork_a | 50k |
| 11 | `mel_exe_key` | 3 | keystone | Only the Weak Die | +12% execute threshold. **Price:** -25% damage against enemies above 50% HP. · *requires* mel_exe_07; ≥5 nodes in subtree |  |  | 35k |
| 12 | `mel_exe_act` | 3 | active | Gavel | Q: 0.25 s windup, then a 90 px radius strike at 3.0x slash damage that executes at 2x threshold inside the radius. **Bounds:** 6 s cooldown. · *requires* mel_exe_06; ≥4 nodes in subtree |  |  | 60k |
| 13 | `mel_exe_mut1` | 3 | mutation | Public Execution | Gavel overkill spills to every enemy within 120 px. · *requires* mel_exe_act |  |  | 25k |
| 14 | `mel_exe_mut2` | 3 | mutation | Swift Justice | Gavel cooldown 6 -> 3.5 s, radius 90 -> 62 px. · *requires* mel_exe_act |  |  | 25k |
| 15 | `mel_exe_mut3` | 3 | mutation | Tithe of the Condemned | +1 Follower per 10 Gavel executions (cap 20 per segment). · *requires* mel_exe_act |  |  | 25k |
| 16 | `mel_exe_cap` | 4 | capstone | The Verdict Stands | A Gavel that kills 5 or more grants +10% threshold for 6 s. · *requires* 2 of: mel_exe_mut1, mel_exe_mut2, mel_exe_mut3 |  |  | 80k |
| 17 | `mel_exe_axiom` | 3 | axiom | Violence Propagates | Spillover applies to kills of any style you can produce. **Price:** Spill range 90 -> 60 px for non-melee kills. · *requires* mel_exe_08; ≥6 nodes in subtree |  |  | 40k |
| 18 | `mel_exe_rev` | 4 | revelation | DECIMATION | V: 0.6 s stationary cast. Every normal enemy in the camera rect (+64 px) at or below the threshold dies; elites at or below half the threshold lose 50% max HP. **Bounds:** Max 150 targets (lowest HP fraction first); cannot touch bosses; 45 s cooldown. **Operating cost:** 1 Follower per 4 executed (min 5), previewed on the HUD before commit; refuses if unaffordable. · *requires* mel_exe_act; ≥8 nodes in subtree | camera-rect gather |  | 300k |

Sinks in this wedge (repeatable, geometric):
- `snk_mel_sharpen` Sharpen: +3% melee damage per rank. Base 60k, ×1.35 per rank, cap: none.
- `snk_mel_verdict` Verdict: +0.5% execute threshold per rank. Base 60k, ×1.5 per rank, cap: threshold total 40%.

#### Melee · Momentum — *Movement is violence.*

**What the player does differently:** Never stop: dash through enemies to prime them, chain dashes on kills, attack mid-stride.  
**HUD:** The existing MOMENTUM row (the tree claims the manifestation noun) plus dash-charge pips.

| # | id | ring | type | name | effect | needs | excl | base cost |
|---|---|---|---|---|---|---|---|---|
| 1 | `mel_mom_01` | 1 | small | Light Feet | (3 ranks) +4% move speed per rank. · *requires* mel_core |  |  | 150 |
| 2 | `mel_mom_02` | 1 | mechanic | Stride | Claims the Momentum meter: a dash adds +25% Momentum; slashes deal +10% damage per 25% Momentum (cap +40%). · *requires* mel_mom_01 | claim ManifestationState.momentum |  | 2.5k |
| 3 | `mel_mom_03` | 1 | small | Second Wind | (3 ranks) Dash cooldown -10% per rank. · *requires* mel_mom_02 | dash_cooldown_multiplier poll |  | 150 |
| 4 | `mel_mom_04` | 2 | mechanic | Passing Blade | The dash path (40 px wide) deals 0.6x slash damage and Primes enemies hit: their next melee hit taken is +50% (3 s). · *requires* mel_mom_02 | gather_in_sector along dash, per-handle Primed status |  | 4k |
| 5 | `mel_mom_05` | 2 | small | Reach | (3 ranks) Slash arc radius +6 px per rank while Momentum is at or above 50%. · *requires* mel_mom_04 |  |  | 300 |
| 6 | `mel_mom_06` | 2 | mechanic | Kill Reset | A melee kill cuts the remaining dash cooldown by 0.5 s (0.3 s ICD). · *requires* mel_mom_03, mel_mom_04 |  |  | 4k |
| 7 | `mel_mom_07` | 2 | small | Running Cut | (2 ranks) Slash cooldown -5% per rank while moving. · *requires* mel_mom_05 |  |  | 300 |
| 8 | `mel_mom_08` | 3 | mechanic | Afterimage | At Momentum >= 75% every slash repeats 0.25 s later at its origin for 50% (generation 1, NO_AFTERIMAGE). · *requires* mel_mom_06, mel_mom_07 |  |  | 12k |
| 9 | `mel_mom_fork_a` | 3 | fork A | Unbroken Motion | Momentum does not decay for 2 s after a kill. **Price:** Stability can never fill. · *requires* mel_mom_08 |  | mel_mom_fork_b | 50k |
| 10 | `mel_mom_fork_b` | 3 | fork B | Thousand Cuts | At Momentum >= 90% slashes echo once at 35% (generation 1). **Price:** Momentum drains 10%/s while attacking. · *requires* mel_mom_08 |  | mel_mom_fork_a | 50k |
| 11 | `mel_mom_key` | 3 | keystone | Never Stop | The dash gains a second charge (each 1.6 s, i-frames kept). **Price:** Slashes deal -30% while Momentum is below 25%. · *requires* mel_mom_06; ≥5 nodes in subtree | dash charges | mel_bas_key, mag_dom_key | 35k |
| 12 | `mel_mom_act` | 3 | active | Lunge | Q: 240 px dash toward the aim point ending in a 1.5x 180-degree slash; counts as a dash (emits player_dashed). **Bounds:** 5 s cooldown. · *requires* mel_mom_04; ≥4 nodes in subtree |  |  | 60k |
| 13 | `mel_mom_mut1` | 3 | mutation | Rebound | A Lunge kill resets Lunge's cooldown (1.0 s ICD). · *requires* mel_mom_act |  |  | 25k |
| 14 | `mel_mom_mut2` | 3 | mutation | Wake | The Lunge path deals Passing Blade at 1.0x, 60 px wide. · *requires* mel_mom_act |  |  | 25k |
| 15 | `mel_mom_mut3` | 3 | mutation | Shadow Step | Lunge leaves an Afterimage that slashes twice over 0.5 s. · *requires* mel_mom_act |  |  | 25k |
| 16 | `mel_mom_cap` | 4 | capstone | Blur | After a Lunge: 0.6 s of 100% evasion and +25% move speed for 2 s. · *requires* 2 of: mel_mom_mut1, mel_mom_mut2, mel_mom_mut3 |  |  | 80k |
| 17 | `mel_mom_rev` | 4 | revelation | NO DISTANCE BETWEEN US | V: for 4 s each slash first teleports you to the nearest not-yet-hit normal or elite within 400 px (one hop per 0.12 s, 0.1 s i-frames per landing); ends early after 0.5 s without a target. **Bounds:** Cannot hop to bosses; 60 s cooldown; Momentum set to 0 on end. **Operating cost:** 3% of current Followers (min 10). · *requires* mel_mom_act; ≥8 nodes in subtree | teleport with i-frames API |  | 300k |

#### Melee · Bastion — *Their violence is mine.*

**What the player does differently:** Walk into crowds, hold Guard to bank Force, release it through slashes or the rupture; standing still is rewarded (fights Momentum, pairs with Anchor Rite).  
**HUD:** FORCE 64/100 meter (new noun, hue at least 12 degrees from ward).

| # | id | ring | type | name | effect | needs | excl | base cost |
|---|---|---|---|---|---|---|---|---|
| 1 | `mel_bas_01` | 1 | small | Plate | (3 ranks) +3 armor per rank. · *requires* mel_core |  |  | 150 |
| 2 | `mel_bas_02` | 1 | mechanic | Stored Force | Claims Force (cap 100): 40% of post-armor damage taken becomes Force (1 per 2 HP); a slash consumes up to 30 Force for +1% damage each. · *requires* mel_bas_01 | Force resource on AscensionState |  | 2.5k |
| 3 | `mel_bas_03` | 1 | small | Thick Skin | (3 ranks) Damage taken -4% per rank. · *requires* mel_bas_02 |  |  | 150 |
| 4 | `mel_bas_04` | 2 | small | Vessel | (3 ranks) Force cap +20 per rank. · *requires* mel_bas_02 |  |  | 300 |
| 5 | `mel_bas_05` | 2 | mechanic | Surrounded | +5% melee damage per enemy within 90 px at swing time (max +40%). · *requires* mel_bas_03 |  |  | 4k |
| 6 | `mel_bas_06` | 2 | mechanic | Immovable | Displacement of the player is negated; each resisted knockback grants +8 Force and a 70 px 0.4x shockwave. · *requires* mel_bas_04, mel_bas_05 | player displacement hook |  | 4k |
| 7 | `mel_bas_07` | 2 | small | Slow Leak | (2 ranks) Force decay -3%/s per rank (base 6%/s after 3 s idle). · *requires* mel_bas_04 |  |  | 300 |
| 8 | `mel_bas_08` | 3 | mechanic | Return to Sender | Enemy projectiles within 48 px during a slash are consumed: +5 Force and +10% slash damage each (max 5). · *requires* mel_bas_06 | consume_enemy_projectiles_in_radius |  | 12k |
| 9 | `mel_bas_fork_a` | 3 | fork A | Pressure Vessel | Force at cap auto-detonates: 160 px burst dealing Force x2.5, Force -> 0. · *requires* mel_bas_08 |  | mel_bas_fork_b | 50k |
| 10 | `mel_bas_fork_b` | 3 | fork B | Overpressure | Force may exceed its cap by 50%; slashes consume up to 60 Force; no auto-detonate. · *requires* mel_bas_08 |  | mel_bas_fork_a | 50k |
| 11 | `mel_bas_key` | 3 | keystone | Anvil | Standing still for 0.5 s: damage taken -35% and Force gain x2. **Price:** Move speed -15%, dash cooldown +0.6 s. · *requires* mel_bas_07; ≥5 nodes in subtree |  | mel_mom_key | 35k |
| 12 | `mel_bas_act` | 3 | active | Guard | Hold Q: move -50%, damage taken -60%, damage taken becomes Force at 100%, projectiles touching a 72 px ring are consumed (+3 Force). **Bounds:** Drains 4 Force/s and ends at 0; no cooldown. · *requires* mel_bas_05; ≥4 nodes in subtree | hold-input semantics for Q |  | 60k |
| 13 | `mel_bas_mut1` | 3 | mutation | Bulwark | Melee attackers striking the Guard ring are stunned 0.4 s (2 s ICD per enemy). · *requires* mel_bas_act |  |  | 25k |
| 14 | `mel_bas_mut2` | 3 | mutation | Counterweight | Releasing Guard after 1 s fires a 2.0x 145-degree shockwave spending 50% Force. · *requires* mel_bas_act |  |  | 25k |
| 15 | `mel_bas_mut3` | 3 | mutation | Martyr's Ledger | Guard also converts 2% max HP/s into +6 Force/s (never below 30% HP). · *requires* mel_bas_act |  |  | 25k |
| 16 | `mel_bas_cap` | 4 | capstone | Living Rampart | Guard's drain is removed; Force gain while guarding +50%. · *requires* 2 of: mel_bas_mut1, mel_bas_mut2, mel_bas_mut3 |  |  | 80k |
| 17 | `mel_bas_axiom` | 3 | axiom | Pressure Is Power | Damage taken fills Force under any style; ranged and magic attacks may consume Force at half rate. **Price:** Force cap -20. · *requires* mel_bas_07; ≥6 nodes in subtree |  |  | 40k |
| 18 | `mel_bas_rev` | 4 | revelation | THE WORLD BREAKS FIRST | V: needs 40+ Force. A rupture of radius 160 + 2.4 x Force (cap 400) deals Force x4 plus 30% of the damage you took in the last 10 s, knockback 600, stun 0.8 s; Force -> 0. **Bounds:** Bosses capped at 15% max HP; 30 s cooldown. **Operating cost:** 2% of current Followers, 4% if Force was at cap. · *requires* mel_bas_act; ≥8 nodes in subtree | 10 s damage-taken ledger |  | 300k |

Sinks in this wedge (repeatable, geometric):
- `snk_mel_ledger` Ledger: Force cap +5 per rank. Base 60k, ×1.3 per rank, cap: Force cap 300.

### Ranged

#### Ranged · Precision — *One shot, perfect consequence.*

**What the player does differently:** Keep hitting the same target to Read it, line enemies up for pierce, stay far.  
**HUD:** READ n counter; Read enemies show a reticle.

| # | id | ring | type | name | effect | needs | excl | base cost |
|---|---|---|---|---|---|---|---|---|
| 1 | `rng_pre_01` | 1 | small | Rifling | (3 ranks) Projectile speed +10% per rank. · *requires* rng_core |  |  | 150 |
| 2 | `rng_pre_02` | 1 | mechanic | Read the Target | The third consecutive hit on one enemy exposes a Weak Point for 4 s: hits deal x1.4 and report as critical (Lucky Crit rolls untouched). · *requires* rng_pre_01 | per-handle hit streak + Read record |  | 2.5k |
| 3 | `rng_pre_03` | 1 | small | Sharp Eye | (3 ranks) Weak Point multiplier +0.1 per rank. · *requires* rng_pre_02 |  |  | 150 |
| 4 | `rng_pre_04` | 2 | small | Long Arm | (2 ranks) Range +60 px per rank. · *requires* rng_pre_01 |  |  | 300 |
| 5 | `rng_pre_05` | 2 | small | Distance Is Contempt | (3 ranks) +8% damage per rank against targets 300+ px away. · *requires* rng_pre_04 |  |  | 300 |
| 6 | `rng_pre_06` | 2 | mechanic | Penetrator | Pierce +1; +15% damage per enemy already pierced (max +60%). · *requires* rng_pre_03 |  |  | 4k |
| 7 | `rng_pre_07` | 2 | mechanic | Second Read | Hits on a Weak Point gain +1 pierce; the enemy behind becomes Read after one hit. · *requires* rng_pre_06 |  |  | 4k |
| 8 | `rng_pre_08` | 2 | small | Held Breath | (2 ranks) Weak Point duration +1 s per rank. · *requires* rng_pre_03 |  |  | 300 |
| 9 | `rng_pre_fork_a` | 3 | fork A | Impossible Shot | A projectile expiring without a hit retargets once to the nearest enemy within 240 px (generation 1, NO_RETARGET). · *requires* rng_pre_07 | projectile expire callback + retarget API | rng_pre_fork_b | 50k |
| 10 | `rng_pre_fork_b` | 3 | fork B | Terminal Geometry | After piercing a Read enemy the projectile bends up to 45 degrees toward the nearest other Read enemy within 200 px (once). · *requires* rng_pre_07 | projectile bend API | rng_pre_fork_a | 50k |
| 11 | `rng_pre_key` | 3 | keystone | One Bullet | Ranged cooldown 0.22 -> 0.44 s, damage x2.4, pierce +2. **Price:** Every extra-projectile source is disabled (the shotgun mutation included). · *requires* rng_pre_06; ≥5 nodes in subtree |  | rng_bar_key | 35k |
| 12 | `rng_pre_act` | 3 | active | Ballistic Solution | Q: 0.5 s stop, then one 5x infinite-pierce shot (speed 1400) along the line through the most enemies in a 60-degree aim cone. **Bounds:** 8 s cooldown. · *requires* rng_pre_06; ≥4 nodes in subtree |  |  | 60k |
| 13 | `rng_pre_mut1` | 3 | mutation | Twin Solution | Two lines (best and second best, at least 20 degrees apart). · *requires* rng_pre_act |  |  | 25k |
| 14 | `rng_pre_mut2` | 3 | mutation | Executioner's Solution | Normals at or below 25% HP on the line die outright. · *requires* rng_pre_act |  |  | 25k |
| 15 | `rng_pre_mut3` | 3 | mutation | Quick Solution | No stop; cooldown 8 -> 5 s; damage 5x -> 3.5x. · *requires* rng_pre_act |  |  | 25k |
| 16 | `rng_pre_cap` | 4 | capstone | Perfect Solution | Every enemy hit by the Solution becomes Read; kills refund 2 s of its cooldown. · *requires* 2 of: rng_pre_mut1, rng_pre_mut2, rng_pre_mut3 |  |  | 80k |
| 17 | `rng_pre_axiom` | 3 | axiom | Nothing Is Wasted | Any projectile or magic impact that hits nothing retargets once to the nearest enemy within 200 px (generation +1, NO_RETARGET). **Price:** Base range -10%. · *requires* rng_pre_08; ≥6 nodes in subtree |  |  | 40k |
| 18 | `rng_pre_rev` | 4 | revelation | LINE OF JUDGEMENT | V: 1.0 s designation (enemies at 15% time scale while you aim) computes up to three lines maximizing on-screen intersections; on release each fires as an 8x hitscan beam (24 px wide) 0.2 s apart. **Bounds:** Max 60 targets per line; bosses capped at 10% max HP per line; 50 s cooldown. **Operating cost:** 5% of current Followers (min 15). · *requires* rng_pre_act; ≥8 nodes in subtree | hitscan helper, local time scale during designation |  | 300k |

Sinks in this wedge (repeatable, geometric):
- `snk_rng_rifling` Rifling: +2% projectile speed and range per rank. Base 60k, ×1.3 per rank, cap: +60% total.
- `snk_rng_judgement` Judgement: +4% Active and Revelation damage per rank. Base 60k, ×1.35 per rank, cap: none.

#### Ranged · Barrage — *Random bullshit, engineered.*

**What the player does differently:** Manage Heat: hold fire to climb tiers, kill to vent, back off before the Jam (or take Overclock and live hot).  
**HUD:** HEAT bar with tier ticks at 25/50/75 and a red Jam zone.

| # | id | ring | type | name | effect | needs | excl | base cost |
|---|---|---|---|---|---|---|---|---|
| 1 | `rng_bar_01` | 1 | small | Trigger Discipline | (3 ranks) Ranged cooldown -4% per rank. · *requires* rng_core |  |  | 150 |
| 2 | `rng_bar_02` | 1 | mechanic | Heat | Claims Heat: +6 per shot, decays 15/s after 0.6 s idle. At 25: +10% rate; 50: +20% and +1 pellet; 75: +30% and +2; 100: Jam for 1.2 s and Heat -> 0. · *requires* rng_bar_01 | Heat resource, extra_projectiles on the hit profile |  | 2.5k |
| 3 | `rng_bar_03` | 1 | small | Heat Sink | (3 ranks) Jam duration -0.2 s per rank. · *requires* rng_bar_02 |  |  | 150 |
| 4 | `rng_bar_04` | 2 | mechanic | Fragmentation | Ranged kills release 2 fragments (generation 1, 30%, seeking the nearest enemy within 140 px, NO_FRAGMENT). · *requires* rng_bar_02 | spawn-from-point API |  | 4k |
| 5 | `rng_bar_05` | 2 | small | Coolant | (3 ranks) Heat decay +3/s per rank. · *requires* rng_bar_03 |  |  | 300 |
| 6 | `rng_bar_06` | 2 | small | Kill Reload | (2 ranks) Kills vent 8 Heat per rank. · *requires* rng_bar_04 |  |  | 300 |
| 7 | `rng_bar_07` | 2 | mechanic | Ricochet | Projectiles bounce once toward the nearest enemy within 160 px at 60% (generation 1, NO_RICOCHET). · *requires* rng_bar_04 | on-hit retarget API |  | 4k |
| 8 | `rng_bar_08` | 3 | mechanic | Ricochets Ricochet | +1 bounce (generation 2, budget 2), -20% per bounce. · *requires* rng_bar_07 |  |  | 12k |
| 9 | `rng_bar_fork_a` | 3 | fork A | ONE WEAPON, INFINITE BULLETS | The 75 tier becomes +60% rate and +3 pellets. **Price:** Jam lasts 2.0 s. · *requires* rng_bar_08 |  | rng_bar_fork_b | 50k |
| 10 | `rng_bar_fork_b` | 3 | fork B | INFINITE WEAPONS, ONE TARGET | At Heat >= 50 every third shot also fires from a Crossfire point on a 380 px ring, aimed at your target (generation 1, CROSSFIRE, 70%). · *requires* rng_bar_08 |  | rng_bar_fork_a | 50k |
| 11 | `rng_bar_key` | 3 | keystone | Overclock | The Jam is removed; Heat cap 150 with a fourth tier at 100 (+40% rate, +3 pellets). **Price:** Damage taken +35% and decay only 5/s while Heat is 100 or more. · *requires* rng_bar_05; ≥5 nodes in subtree |  | rng_pre_key | 35k |
| 12 | `rng_bar_act` | 3 | active | Suppressive Burst | Q: 1.5 s at +150% fire rate with no Heat gain; ends by setting Heat to 75. **Bounds:** 10 s cooldown. · *requires* rng_bar_04; ≥4 nodes in subtree |  |  | 60k |
| 13 | `rng_bar_mut1` | 3 | mutation | Sustained | Burst lasts 2.5 s instead of 1.5 s. · *requires* rng_bar_act |  |  | 25k |
| 14 | `rng_bar_mut2` | 3 | mutation | Vented | Burst ends at Heat 25 instead of 75, venting a 120 px 1.0x burn nova. · *requires* rng_bar_act |  |  | 25k |
| 15 | `rng_bar_mut3` | 3 | mutation | Enfilade | Every Burst shot ricochets (+1, generation budget respected). · *requires* rng_bar_act |  |  | 25k |
| 16 | `rng_bar_cap` | 4 | capstone | Belt-Fed | Burst kills extend it by 0.15 s each (max +2 s). · *requires* 2 of: rng_bar_mut1, rng_bar_mut2, rng_bar_mut3 |  |  | 80k |
| 17 | `rng_bar_axiom` | 3 | axiom | Heat Is Universal | Slashes and casts add +4 Heat; Heat rate tiers apply to every style's attack cooldown. **Price:** The Jam applies to every style. · *requires* rng_bar_06; ≥6 nodes in subtree |  |  | 40k |
| 18 | `rng_bar_rev` | 4 | revelation | ABSOLUTE SUPPRESSION | V: for 5 s every shot you fire spawns 3 more from three rotating Crossfire points on a 420 px ring (generation 1, CROSSFIRE, 60%, no fragments or ricochets); Heat is frozen. **Bounds:** Cap 300 secondary shots; Crossfire never targets bosses; 60 s cooldown. **Operating cost:** 1 Follower per 20 shots spawned (min 8), charged on end. · *requires* rng_bar_act; ≥8 nodes in subtree |  |  | 300k |

Sinks in this wedge (repeatable, geometric):
- `snk_rng_barrel` Barrel: Heat per shot -1% per rank. Base 60k, ×1.4 per rank, cap: -40% total.

#### Ranged · Ordnance — *Prepare the field, then cause a disaster.*

**What the player does differently:** Place things before enemies arrive: mines via dashes, Coordinates via cursor, then herd enemies into the timers.  
**HUD:** COORD 2/3 plus mine count; telegraph circles are the language.

| # | id | ring | type | name | effect | needs | excl | base cost |
|---|---|---|---|---|---|---|---|---|
| 1 | `rng_ord_01` | 1 | small | Blast Radius | (3 ranks) Ordnance blast radius +8% per rank. · *requires* rng_core |  |  | 150 |
| 2 | `rng_ord_02` | 1 | mechanic | Impact Fuse | Every fifth ranged hit drops a Shell at the impact point (0.6 s delay, radius 80, 1.8x, generation 1, ORDNANCE, NO_ORDNANCE_TRIGGER). · *requires* rng_ord_01 | pooled Shell scene: telegraph + delayed blast |  | 2.5k |
| 3 | `rng_ord_03` | 1 | small | Shorter Fuse | (2 ranks) Shell delay -0.1 s per rank. · *requires* rng_ord_02 |  |  | 150 |
| 4 | `rng_ord_04` | 2 | mechanic | Caltrops | Dashing drops a Mine at the start point (arms in 0.5 s, radius 70, 1.5x, 12 s life, max 6). · *requires* rng_ord_02 | pooled Mine scene |  | 4k |
| 5 | `rng_ord_05` | 2 | small | Magazine | (2 ranks) Max mines +2 per rank. · *requires* rng_ord_04 |  |  | 300 |
| 6 | `rng_ord_06` | 2 | mechanic | Fracture | Blast hits apply Fractured: +6% damage taken per stack (max 5, 5 s). · *requires* rng_ord_03 | per-handle Fractured status |  | 4k |
| 7 | `rng_ord_07` | 2 | mechanic | Secondary Detonation | A killing blast spawns one follow-up Shell at the victim (generation +1, budget 2). · *requires* rng_ord_06 |  |  | 4k |
| 8 | `rng_ord_08` | 3 | small | Heavier Shells | (3 ranks) Blast damage +10% per rank. · *requires* rng_ord_07 |  |  | 600 |
| 9 | `rng_ord_fork_a` | 3 | fork A | Saturation Coordinates | Every 3 s the densest cluster (6+ enemies within 100 px, scanned at 10 Hz) is auto-designated: 3 Shells over 1 s. · *requires* rng_ord_08 | cluster density scan | rng_ord_fork_b | 50k |
| 10 | `rng_ord_fork_b` | 3 | fork B | Walking Barrage | While moving, a Shell lands 120 px behind you every 0.8 s. · *requires* rng_ord_08 |  | rng_ord_fork_a | 50k |
| 11 | `rng_ord_key` | 3 | keystone | Beacon Doctrine | Elites hit by three blasts become Beacons: a Shell strikes them every 1.5 s until death (max 3 Beacons). **Price:** Mines and Impact Fuse deal -50% to normals. · *requires* rng_ord_06; ≥5 nodes in subtree | per-handle Beacon status |  | 35k |
| 12 | `rng_ord_act` | 3 | active | Designate | Q: place a Coordinate at the cursor (max 3, 15 s). Press on an existing one: it receives 4 Shells over 1.6 s at 2.0x. **Bounds:** 12 s cooldown from firing. · *requires* rng_ord_04; ≥4 nodes in subtree | Coordinates list |  | 60k |
| 13 | `rng_ord_mut1` | 3 | mutation | Saturation | 4 -> 7 Shells, scattered over 160 px. · *requires* rng_ord_act |  |  | 25k |
| 14 | `rng_ord_mut2` | 3 | mutation | Guidance | Coordinates track the nearest elite; 4 -> 3 Shells at 3.0x. · *requires* rng_ord_act |  |  | 25k |
| 15 | `rng_ord_mut3` | 3 | mutation | Cascade | Each Designate kill adds a Shell to the sequence (max +6). · *requires* rng_ord_act |  |  | 25k |
| 16 | `rng_ord_cap` | 4 | capstone | Fire for Effect | Coordinates persist after firing; cooldown 12 -> 8 s. · *requires* 2 of: rng_ord_mut1, rng_ord_mut2, rng_ord_mut3 |  |  | 80k |
| 17 | `rng_ord_rev` | 4 | revelation | TOTAL FIRE MISSION | V: 1.2 s grid telegraph over the screen, then 24 Shells over 4 s on a density-biased stratified grid (3.0x, radius 110, 0.16 s stagger). **Bounds:** 90 px player-safe radius per Shell; bosses capped at 12% max HP total; 75 s cooldown. **Operating cost:** 6% of current Followers (min 20) plus 1 per Cascade Shell. · *requires* rng_ord_act; ≥8 nodes in subtree |  |  | 300k |

### Magic

#### Magic · Invocation — *Bring impossible things into existence.*

**What the player does differently:** Choose where to fight: near Sigils. Feed them kills, cast through them, Consecrate to reposition the arena.  
**HUD:** SIGILS 3/5 plus Echo pips per Sigil.

| # | id | ring | type | name | effect | needs | excl | base cost |
|---|---|---|---|---|---|---|---|---|
| 1 | `mag_inv_01` | 1 | small | Wider Sigil | (3 ranks) Magic impact radius +6 px per rank. · *requires* mag_core |  |  | 150 |
| 2 | `mag_inv_02` | 1 | mechanic | Leave a Sigil | Every fourth impact leaves a Sigil (8 s, max 3) that pulses a 0.35x 48 px impact every 1.0 s (generation 1, SIGIL, NO_SIGIL_SPAWN). · *requires* mag_inv_01 | pooled Sigil scene |  | 2.5k |
| 3 | `mag_inv_03` | 1 | small | Endure | (3 ranks) Sigil life +3 s per rank. · *requires* mag_inv_02 |  |  | 150 |
| 4 | `mag_inv_04` | 2 | small | Congregation | (2 ranks) Max Sigils +1 per rank. · *requires* mag_inv_03 |  |  | 300 |
| 5 | `mag_inv_05` | 2 | mechanic | Fed by Death | Kills within 90 px of a Sigil grow it: +5% pulse damage and +2 px radius (max +100% / +40 px). · *requires* mag_inv_02 | Sigil growth record |  | 4k |
| 6 | `mag_inv_06` | 2 | mechanic | Echo Shrine | Casting within 70 px of a Sigil stores an Echo (max 3), released as full impacts when it expires or is triggered. · *requires* mag_inv_05 | Echo store |  | 4k |
| 7 | `mag_inv_07` | 2 | small | Warm Circle | (2 ranks) +6% magic damage per rank per Sigil within 150 px (max 3 counted). · *requires* mag_inv_04 |  |  | 300 |
| 8 | `mag_inv_08` | 3 | small | Pulse Rate | (2 ranks) Sigil pulse interval -0.1 s per rank. · *requires* mag_inv_06 |  |  | 600 |
| 9 | `mag_inv_fork_a` | 3 | fork A | Autonomous Invocation | Sigils aim: pulses become 0.5x impacts thrown at the nearest enemy within 220 px. · *requires* mag_inv_08 |  | mag_inv_fork_b | 50k |
| 10 | `mag_inv_fork_b` | 3 | fork B | Recursive Ritual | A fully grown Sigil splits once: a child at 60% (generation 2, budget 1, cannot split) at the nearest cluster within 200 px. · *requires* mag_inv_08 |  | mag_inv_fork_a | 50k |
| 11 | `mag_inv_key` | 3 | keystone | Inherit the Word | Sigil pulses run apply_to_magic_impact and fire player_hit_landed as yours, so item on-hit rules trigger (0.5 s ICD per Sigil). **Price:** Your direct casts deal -25%. · *requires* mag_inv_07; ≥5 nodes in subtree | as-player hook proxy with SIGIL origin |  | 35k |
| 12 | `mag_inv_act` | 3 | active | Consecrate | Q: place a Sigil at the cursor (within 260 px) now and pulse every Sigil immediately. **Bounds:** 7 s cooldown. · *requires* mag_inv_05; ≥4 nodes in subtree |  |  | 60k |
| 13 | `mag_inv_mut1` | 3 | mutation | Great Sigil | The Consecrated Sigil has 1.5x radius and damage and counts as 2 toward the cap. · *requires* mag_inv_act |  |  | 25k |
| 14 | `mag_inv_mut2` | 3 | mutation | Beacon of Ruin | Consecrate also releases every stored Echo. · *requires* mag_inv_act |  |  | 25k |
| 15 | `mag_inv_mut3` | 3 | mutation | Wandering Sigil | The Consecrated Sigil follows you at 120 px/s (one at a time). · *requires* mag_inv_act |  |  | 25k |
| 16 | `mag_inv_cap` | 4 | capstone | Liturgy | Cooldown 7 -> 4 s; Consecrated Sigils never expire while you are within 200 px. · *requires* 2 of: mag_inv_mut1, mag_inv_mut2, mag_inv_mut3 |  |  | 80k |
| 17 | `mag_inv_rev` | 4 | revelation | THE HOST | V: for 6 s every Sigil duplicates once (60 px offset, generation 2, cannot grow or split, dies with the Host) and all Sigils pulse at 3x rate; Host copies release their Echoes on end. **Bounds:** Cap 12 Sigils on the field; bosses capped at 10% max HP total; 70 s cooldown. **Operating cost:** 4% of current Followers (min 15) plus 1 per Sigil duplicated. · *requires* mag_inv_act; ≥8 nodes in subtree |  |  | 300k |

Sinks in this wedge (repeatable, geometric):
- `snk_mag_invocation` Invocation: Sigil life +0.5 s and pulse damage +2% per rank. Base 60k, ×1.35 per rank, cap: none.

#### Magic · Distortion — *Reality behaves incorrectly around you.*

**What the player does differently:** Gamble on purpose: flip the Coin before committing, cash Debt timing, let enemy projectiles fail.  
**HUD:** DEBT 412 pending damage plus coin state.

| # | id | ring | type | name | effect | needs | excl | base cost |
|---|---|---|---|---|---|---|---|---|
| 1 | `mag_dis_01` | 1 | small | Improbable | (3 ranks) Luck +6% per rank. · *requires* mag_core |  |  | 150 |
| 2 | `mag_dis_02` | 1 | mechanic | Twice | 12% chance (Luck-scaled, cap 20%) that an impact bursts again 0.15 s later at 50% (generation 1, NO_TWICE). · *requires* mag_dis_01 |  |  | 2.5k |
| 3 | `mag_dis_03` | 1 | small | Lingering Wrong | (2 ranks) Durations of statuses you apply +10% per rank. · *requires* mag_dis_02 |  |  | 150 |
| 4 | `mag_dis_04` | 2 | mechanic | Misfire | Enemy projectiles within 90 px have a 15%/s chance each to be consumed (10 Hz poll, random subset). · *requires* mag_dis_02 |  |  | 4k |
| 5 | `mag_dis_05` | 2 | small | Denial | (2 ranks) Misfire chance +5% per rank. · *requires* mag_dis_04 |  |  | 300 |
| 6 | `mag_dis_06` | 2 | mechanic | Causal Debt | Each hit re-applies 20% of its damage after 2.0 s (deferred ledger, max 3 pending per enemy; voided on death). · *requires* mag_dis_03 | deferred damage ledger |  | 4k |
| 7 | `mag_dis_07` | 2 | small | Interest | (3 ranks) Debt +5% per rank. · *requires* mag_dis_06 |  |  | 300 |
| 8 | `mag_dis_08` | 3 | mechanic | Contradiction | An enemy holding two or more of burn, stun, slow, Fractured, Primed, Read or Debt takes +15% from you. · *requires* mag_dis_05, mag_dis_07 | per-handle status registry |  | 12k |
| 9 | `mag_dis_fork_a` | 3 | fork A | Revision | Once per 12 s a hit of 25%+ max HP is undone (healed back, 0.5 s i-frames). **Price:** 1 Follower per Revision. · *requires* mag_dis_08 |  | mag_dis_fork_b | 50k |
| 10 | `mag_dis_fork_b` | 3 | fork B | Inheritance | Pending Debt on a dying enemy transfers to the nearest enemy within 120 px (generation +1, budget 2). · *requires* mag_dis_08 |  | mag_dis_fork_a | 50k |
| 11 | `mag_dis_key` | 3 | keystone | Loaded Dice | Lucky Crit cap 8% -> 16%, multiplier 1.5x -> 2.0x. **Price:** Every failed Luck roll costs 1% max HP (0.2 s ICD). · *requires* mag_dis_07; ≥5 nodes in subtree | Lucky Crit cap and multiplier as parameters |  | 35k |
| 12 | `mag_dis_act` | 3 | active | Coin | Q: a 50/50 flip (Luck-biased up to 65/35). HEADS: 3 s of guaranteed Lucky Crits and Debt timers at 0.3 s. TAILS: -10% current HP and +40% magic damage for 3 s. **Bounds:** 9 s cooldown. · *requires* mag_dis_04; ≥4 nodes in subtree | LuckResolver force-success window |  | 60k |
| 13 | `mag_dis_mut1` | 3 | mutation | Weighted | HEADS bias +10%. · *requires* mag_dis_act |  |  | 25k |
| 14 | `mag_dis_mut2` | 3 | mutation | Double or Nothing | TAILS may be re-flipped within 1 s; a second TAILS costs 20% HP. · *requires* mag_dis_act |  |  | 25k |
| 15 | `mag_dis_mut3` | 3 | mutation | House Edge | Either result consumes all enemy projectiles within 160 px. · *requires* mag_dis_act |  |  | 25k |
| 16 | `mag_dis_cap` | 4 | capstone | Rigged | Cooldown 9 -> 6 s; HEADS refunds 25% of the Revelation cooldown (once per 30 s). · *requires* 2 of: mag_dis_mut1, mag_dis_mut2, mag_dis_mut3 |  |  | 80k |
| 17 | `mag_dis_axiom` | 3 | axiom | Effects Have Memory | Statuses you apply under any style have a 20% chance to reapply once at 50% duration when they expire. **Price:** Base status durations -15%. · *requires* mag_dis_03; ≥6 nodes in subtree |  |  | 40k |
| 18 | `mag_dis_rev` | 4 | revelation | CONSENSUS FAILURE | V: for 4 s every Luck check you make succeeds, Twice always fires, Debt applies instantly, enemy projectiles within 220 px are consumed, and enemy melee against you misses. **Bounds:** Explicitly excluded: cooldown resets, item internal cooldowns, boss arena mechanics; generation budgets enforced. 90 s cooldown, then 6 s of forced Luck failure (banks Misfortune for Broken Providence on purpose). **Operating cost:** 8% of current Followers (min 25). · *requires* mag_dis_act; ≥8 nodes in subtree | evasion override |  | 300k |

Sinks in this wedge (repeatable, geometric):
- `snk_mag_consensus` Consensus: Luck +1% and Revelation Follower cost -1% per rank. Base 60k, ×1.5 per rank, cap: cost floor 50% of base.

#### Magic · Dominion — *The battlefield obeys.*

**What the player does differently:** The cursor becomes a second body: decide where enemies go, compress them into impact radius, link them so one hit is many, hold ground.  
**HUD:** LINKS 8 plus Sovereign zone timers.

| # | id | ring | type | name | effect | needs | excl | base cost |
|---|---|---|---|---|---|---|---|---|
| 1 | `mag_dom_01` | 1 | mechanic | Gravity Well | Impacts pull enemies in a 120 px ring inward by 40 px and slow them 30% for 1.5 s. · *requires* mag_core | apply_knockback inward |  | 2.5k |
| 2 | `mag_dom_02` | 1 | small | Heavier | (3 ranks) Pull +10 px per rank. · *requires* mag_dom_01 |  |  | 150 |
| 3 | `mag_dom_03` | 1 | small | Lingering Weight | (2 ranks) Slow +0.5 s per rank. · *requires* mag_dom_01 |  |  | 150 |
| 4 | `mag_dom_04` | 2 | mechanic | Collision | Pulled enemies ending within 14 px of each other take 0.4x impact damage each (once per pull, max 20 pairs). · *requires* mag_dom_02 | pairwise collision check |  | 4k |
| 5 | `mag_dom_05` | 2 | mechanic | Bind | Enemies hit by one impact become Linked (up to 6, 6 s): Linked enemies share slows and stuns. · *requires* mag_dom_03 | Link registry |  | 4k |
| 6 | `mag_dom_06` | 2 | small | Longer Chain | (2 ranks) Link +2 s per rank; rank 2 also raises members 6 -> 8. · *requires* mag_dom_05 |  |  | 300 |
| 7 | `mag_dom_07` | 2 | mechanic | Collective Burden | 25% of damage dealt to a Linked enemy is copied to each partner (generation 1, NO_LINK_SHARE, max 5). · *requires* mag_dom_05 |  |  | 4k |
| 8 | `mag_dom_08` | 3 | small | Crushing | (2 ranks) +5% magic damage per rank per enemy within 60 px of the impact centre (max +40%). · *requires* mag_dom_04, mag_dom_07 |  |  | 600 |
| 9 | `mag_dom_fork_a` | 3 | fork A | Singularity | An impact on 6+ enemies collapses them to its centre with a 0.3 s stun. · *requires* mag_dom_08 |  | mag_dom_fork_b | 50k |
| 10 | `mag_dom_fork_b` | 3 | fork B | Forced Orbit | Pulled enemies orbit you at 110 px for 2 s, unable to attack (velocity override). · *requires* mag_dom_08 | enemy velocity override | mag_dom_fork_a | 50k |
| 11 | `mag_dom_key` | 3 | keystone | Sovereign Ground | Standing still for 1 s leaves a 90 px zone (max 2, 6 s): enemies inside are slowed 50% and take +20% damage. **Price:** Move speed -10%, dash cooldown +0.4 s. · *requires* mag_dom_06; ≥5 nodes in subtree | Sovereign zones | mel_mom_key | 35k |
| 12 | `mag_dom_act` | 3 | active | Compel | Q (aimed): a 200 px cone; every enemy in it is dragged 140 px toward the cursor point and stunned 0.4 s. **Bounds:** 8 s cooldown. · *requires* mag_dom_04; ≥4 nodes in subtree | pull-to-point velocity override |  | 60k |
| 13 | `mag_dom_mut1` | 3 | mutation | Compel: Ring | Compel becomes a 220 px circle around the cursor. · *requires* mag_dom_act |  |  | 25k |
| 14 | `mag_dom_mut2` | 3 | mutation | Compel: Chain | Every pulled enemy is Linked together (cap 12 for that batch). · *requires* mag_dom_act |  |  | 25k |
| 15 | `mag_dom_mut3` | 3 | mutation | Compel: Repulse | Hold to invert: shove 260 px; 0.6x on collision. · *requires* mag_dom_act |  |  | 25k |
| 16 | `mag_dom_cap` | 4 | capstone | Absolute Compel | Cooldown 8 -> 5 s; pulled enemies are Subjugated (+10% damage taken, 3 s). · *requires* 2 of: mag_dom_mut1, mag_dom_mut2, mag_dom_mut3 |  |  | 80k |
| 17 | `mag_dom_rev` | 4 | revelation | KNEEL | V: every normal on screen is pulled to the cursor point at 900 px/s for 0.8 s and held 2.0 s; elites are slowed 70% and held 1.0 s. **Bounds:** Bosses unaffected; max 300 targets; released with a 0.5 s no-attack stumble; 60 s cooldown. **Operating cost:** 5% of current Followers (min 15) plus 1 per 25 pulled. · *requires* mag_dom_act; ≥8 nodes in subtree |  |  | 300k |

Sinks in this wedge (repeatable, geometric):
- `snk_mag_dominion` Dominion: +2% impact radius per rank. Base 60k, ×1.35 per rank, cap: +50% total.

### Edge: Witness, bridges, Ascendant (per style tree)

| id (as shown on the tree) | type | gutter | name | effect | requires |
|---|---|---|---|---|---|
| `wit_magic@melee` | witness | execution|momentum | Witness of the Sign | Grants the magic core impact as a tree-triggerable secondary attack (never input-triggered). Needs any Revelation of your style and a peak congregation of 5,000,000.  |  any of mel_exe_rev, mel_mom_rev, mel_bas_rev |
| `brg_mel_mag@melee` | bridge | execution|momentum | INCARNATE | Every third slash spawns a MagicImpact at the arc's far edge (0.7x); every impact that hits 3+ enemies fires a 0.5x slash arc from you toward its centre. Bridge attacks carry origin BRIDGE, generation 1, budget 1, never emit weapon_fired, and count as the other style only for the bridge-open nodes listed.  |  any of mel_exe_rev, mel_mom_rev, mel_bas_rev + all of wit_magic@melee |
| `wit_ranged@melee` | witness | momentum|bastion | Witness of the Shot | Grants the ranged core projectile as a tree-triggerable secondary attack (never input-triggered). Needs any Revelation of your style and a peak congregation of 5,000,000.  |  any of mel_exe_rev, mel_mom_rev, mel_bas_rev |
| `brg_mel_rng@melee` | bridge | momentum|bastion | TOTAL OFFENSIVE | A slash hitting 2+ enemies fires one projectile per extra enemy (max 3) at the farthest; a ranged kill within 100 px of you triggers a 0.5x slash arc. Bridge attacks carry origin BRIDGE, generation 1, budget 1, never emit weapon_fired, and count as the other style only for the bridge-open nodes listed.  |  any of mel_exe_rev, mel_mom_rev, mel_bas_rev + all of wit_ranged@melee |
| `brg_asc@melee` | ascendant | bastion|execution | ASCENDANT | Every primary attack carries all three style tags for the bridge-open nodes; each bridge-open list fires at most once per source attack; chains get budget 2 total. Prize: a second Revelation from a different subtree may be slotted on V (both share the longer cooldown). Needs both bridges of your style and a peak congregation of 50,000,000. **Operating cost:** 1 Follower per 50 bridge-generated attacks, charged per segment. |  + all of brg_mel_mag@melee, brg_mel_rng@melee |
| `wit_melee@ranged` | witness | precision|barrage | Witness of the Blade | Grants the melee core slash as a tree-triggerable secondary attack (never input-triggered). Needs any Revelation of your style and a peak congregation of 5,000,000.  |  any of rng_pre_rev, rng_bar_rev, rng_ord_rev |
| `brg_mel_rng@ranged` | bridge | precision|barrage | TOTAL OFFENSIVE | A slash hitting 2+ enemies fires one projectile per extra enemy (max 3) at the farthest; a ranged kill within 100 px of you triggers a 0.5x slash arc. Bridge attacks carry origin BRIDGE, generation 1, budget 1, never emit weapon_fired, and count as the other style only for the bridge-open nodes listed.  |  any of rng_pre_rev, rng_bar_rev, rng_ord_rev + all of wit_melee@ranged |
| `wit_magic@ranged` | witness | barrage|ordnance | Witness of the Sign | Grants the magic core impact as a tree-triggerable secondary attack (never input-triggered). Needs any Revelation of your style and a peak congregation of 5,000,000.  |  any of rng_pre_rev, rng_bar_rev, rng_ord_rev |
| `brg_rng_mag@ranged` | bridge | barrage|ordnance | ARCANE BALLISTICS | A projectile that expires or exhausts its pierce bursts as a 0.6x MagicImpact; an impact fires one projectile outward per 3 enemies hit (max 3). Bridge attacks carry origin BRIDGE, generation 1, budget 1, never emit weapon_fired, and count as the other style only for the bridge-open nodes listed.  |  any of rng_pre_rev, rng_bar_rev, rng_ord_rev + all of wit_magic@ranged |
| `brg_asc@ranged` | ascendant | ordnance|precision | ASCENDANT | Every primary attack carries all three style tags for the bridge-open nodes; each bridge-open list fires at most once per source attack; chains get budget 2 total. Prize: a second Revelation from a different subtree may be slotted on V (both share the longer cooldown). Needs both bridges of your style and a peak congregation of 50,000,000. **Operating cost:** 1 Follower per 50 bridge-generated attacks, charged per segment. |  + all of brg_mel_rng@ranged, brg_rng_mag@ranged |
| `wit_melee@magic` | witness | invocation|distortion | Witness of the Blade | Grants the melee core slash as a tree-triggerable secondary attack (never input-triggered). Needs any Revelation of your style and a peak congregation of 5,000,000.  |  any of mag_inv_rev, mag_dis_rev, mag_dom_rev |
| `brg_mel_mag@magic` | bridge | invocation|distortion | INCARNATE | Every third slash spawns a MagicImpact at the arc's far edge (0.7x); every impact that hits 3+ enemies fires a 0.5x slash arc from you toward its centre. Bridge attacks carry origin BRIDGE, generation 1, budget 1, never emit weapon_fired, and count as the other style only for the bridge-open nodes listed.  |  any of mag_inv_rev, mag_dis_rev, mag_dom_rev + all of wit_melee@magic |
| `wit_ranged@magic` | witness | distortion|dominion | Witness of the Shot | Grants the ranged core projectile as a tree-triggerable secondary attack (never input-triggered). Needs any Revelation of your style and a peak congregation of 5,000,000.  |  any of mag_inv_rev, mag_dis_rev, mag_dom_rev |
| `brg_rng_mag@magic` | bridge | distortion|dominion | ARCANE BALLISTICS | A projectile that expires or exhausts its pierce bursts as a 0.6x MagicImpact; an impact fires one projectile outward per 3 enemies hit (max 3). Bridge attacks carry origin BRIDGE, generation 1, budget 1, never emit weapon_fired, and count as the other style only for the bridge-open nodes listed.  |  any of mag_inv_rev, mag_dis_rev, mag_dom_rev + all of wit_ranged@magic |
| `brg_asc@magic` | ascendant | dominion|invocation | ASCENDANT | Every primary attack carries all three style tags for the bridge-open nodes; each bridge-open list fires at most once per source attack; chains get budget 2 total. Prize: a second Revelation from a different subtree may be slotted on V (both share the longer cooldown). Needs both bridges of your style and a peak congregation of 50,000,000. **Operating cost:** 1 Follower per 50 bridge-generated attacks, charged per segment. |  + all of brg_mel_mag@magic, brg_rng_mag@magic |

Per-subtree composition:

| subtree | nodes | small | mechanic | fork | keystone | active | mutation | capstone | axiom | revelation |
|---|---|---|---|---|---|---|---|---|---|---|
| magic · distortion | 18 | 4 | 4 | 2 | 1 | 1 | 3 | 1 | 1 | 1 |
| magic · dominion | 17 | 4 | 4 | 2 | 1 | 1 | 3 | 1 | 0 | 1 |
| magic · invocation | 17 | 5 | 3 | 2 | 1 | 1 | 3 | 1 | 0 | 1 |
| melee · bastion | 18 | 4 | 4 | 2 | 1 | 1 | 3 | 1 | 1 | 1 |
| melee · execution | 18 | 4 | 4 | 2 | 1 | 1 | 3 | 1 | 1 | 1 |
| melee · momentum | 17 | 4 | 4 | 2 | 1 | 1 | 3 | 1 | 0 | 1 |
| ranged · barrage | 18 | 4 | 4 | 2 | 1 | 1 | 3 | 1 | 1 | 1 |
| ranged · ordnance | 17 | 4 | 4 | 2 | 1 | 1 | 3 | 1 | 0 | 1 |
| ranged · precision | 18 | 5 | 3 | 2 | 1 | 1 | 3 | 1 | 1 | 1 |
<!-- NODE_TABLES_END -->

### 5.2 Axioms

| Axiom | Home | Rule | Price |
|---|---|---|---|
| Violence Propagates | Execution | Spillover applies to kills of any style you can produce | spill range 90 → 60 px for non-melee kills |
| Nothing Is Wasted | Precision | any projectile or impact that hits nothing retargets once within 200 px (generation +1, NO_RETARGET) | base range −10% |
| Effects Have Memory | Distortion | statuses you apply have 20% to reapply once at 50% duration on expiry | base status durations −15% |
| Pressure Is Power | Bastion | any damage taken fills Force; ranged and magic attacks may spend it at half rate | Force cap −20 |
| Heat Is Universal | Barrage | slashes and casts add +4 Heat; Heat tiers speed every style's cooldown | the Jam applies to every style |

### 5.3 Witnesses, bridges, Ascendant

A bridge attack counts as the other style **only** for that wedge's bridge-open nodes; every other node ignores it. Bridge-open lists: Melee `mel_exe_02` (threshold), `mel_mom_04` (Primed); Ranged `rng_pre_02` (Read), `rng_bar_07` (Ricochet), `rng_ord_02` (Impact Fuse); Magic `mag_inv_02` (Sigil), `mag_dom_01` (Gravity Well), `mag_dis_02` (Twice). Bridge attacks carry origin BRIDGE, generation 1, budget 1, no-self {BRIDGE, AFTERIMAGE, SPILLOVER} and never emit `weapon_fired`.

- **INCARNATE** (Melee + Magic): every third slash spawns a MagicImpact at the arc's far edge (0.7×); every impact that hits three or more fires a 0.5× slash arc from you toward its centre.
- **TOTAL OFFENSIVE** (Melee + Ranged): a slash hitting two or more fires one projectile per extra enemy (max 3) at the farthest; a ranged kill within 100 px triggers a 0.5× slash arc.
- **ARCANE BALLISTICS** (Ranged + Magic): a projectile that expires or exhausts its pierce bursts as a 0.6× MagicImpact; an impact fires one projectile outward per three enemies hit (max 3).
- **ASCENDANT** (both bridges of your style): every primary attack carries all three tags for the bridge-open nodes; each bridge-open list fires at most once per source attack; chains get budget 2 total. Prize: a second Revelation from another wedge may be slotted on V, both sharing the longer cooldown. Upkeep 1 Follower per 50 bridge-generated attacks, charged per segment.

---

## 6. How it meets the rest of the game

- **Items** keep defining ordinary combat: rolled mods, sets, on-hit rules, polarity, merges. The tree never adds a stat that items already give in quantity; its Smalls are conditional (while moving, at range, near a Sigil). Two explicit compounders: Inherit the Word runs item on-hit rules through Sigils; Momentum's meter is the same one items fill.
- **NEG builds**: Bastion (Martyr's Ledger, Pressure Is Power) and Distortion (Loaded Dice's HP price, Consensus Failure's forced-failure hangover that banks Misfortune for Broken Providence) are written to reward Litany of Wounds and Debt Collector style builds; Tithe Bones and the tithes scale with Reach so they stay felt.
- **Luck**: Distortion owns it (Improbable, Twice's Luck scaling, Loaded Dice raising the Lucky Crit cap and multiplier, Coin's bias, Consensus Failure's forced success window). Nothing else in the tree reads Luck, so Luck items and Fortune manifestations remain the way to feed that wedge.
- **Followers**: the tree is the sink; Revelations are the operating sinks; belief Power rewards the peak; the reconstruction floor and the 20% tax keep holding dangerous. Reach keeps the shop, wagers and tithes priced in the same units.
- **Doctrine** (segments 3/6/9) stays free, forced, style-agnostic and tested; it appears as the three sockets at the tree's centre and its rules stay in `attempt_doctrine_rules`. Node defs may `requires_doctrine_ids` for authored duos (a Revelation that needs a specific Doctrine) later.
- **Threat / power contrast**: buying a Keystone, Active, Revelation or bridge emits `power_threshold_crossed(&"ascension_<ring>", title)` so the ThreatDirector opens its contrast window; peak titles are the later Attention hook.
- **The loop**: the Hub is where identity is chosen; Wardstones are where tactical top-ups happen; the Exit Rite pays an `exodus` reward that funds the next Hub.

---

## 7. UI / UX

Geometry, glyphs and colour: rings at 150/290/440/600/760 with widening gaps; node glyphs by type (small circle 22 px, mechanic diamond 30, fork half-circles 34 facing each other with a dashed chord and ⊗, keystone octagon 56, active 64 with an outer ring, mutation hexagon 20 on a sub-arc 70 px outside its active, capstone 44, axiom triangle-in-circle 40, revelation 60, witness 36 and bridge vesica 44 on the gutter, sink square 36 with a rank counter, ascendant 60). Stroke colour leaves warmth as it leaves mortality: bone-grey → bronze → amber → gold-white with glow → cold white-violet; glyphs go from small-cap initials to geometric marks to sigils; ring labels MORTAL / BELIEVER / PROPHET / ICON / ASCENDANT sit on the top gutter.

States: purchased (filled amber core, luminous outline, glow on rings 4–5), affordable (breathing halo), partial (Small with ranks left), locked (dim outline), gated (wedge count), peak-gated, sealed (struck through), floor-blocked (⚠), hub-only (at a Wardstone). Purchase: an amber pulse travels parent → child, the node pops and a halo fades over 600 ms.

Interaction: hover shows the cheapest chain of unpurchased prerequisites and its total; click buys a frontier Small / Mechanic / Mutation / Sink instantly; Keystone, Active, Fork, Axiom, Capstone, Revelation, Witness, bridge, any multi-node path and anything over 25% of the balance open a confirm panel with the consequence text ("Renounces Thousand Cuts", "This can never be refunded"); affordability respects the reconstruction floor, drawn hatched on the balance bar; right-click or hold refunds a leaf at the segment's share; filters dim rather than hide (spatial memory); search glides the camera; arrows / stick walk to the best node inside a 60° cone scored by distance over cosine, graph-adjacent nodes preferred; wheel zoom ×1.12 about the cursor clamped 0.28–2.4; drag pans; minimap 180 px with the viewport rectangle; Fit on F.

Tooltip template: NAME (type glyph right) / ring · type · wedge · rank / effect / Price / Bounds / Operating cost / Needs (implementation budget, dev builds only) / Cost with path total / Requires (any-of, all-of, wedge count, peak) / Renounces / hint line with the key.

Controller: left stick or d-pad walks, A buys, X (hold 600 ms) renounces, B closes, LB/RB step along the ring, LT/RT switch wedge, Y jumps to the nearest affordable node, right stick pans, Start fits, Back opens filters.

Empty and locked messaging: a ring with nothing affordable shows a subtitle ("PROPHET — reach Believer first"); the edge band is hatched with "ASCENDANT — awakens after a Revelation" until an ICON node is owned; sealed bridges name the Witness they need; a fresh style shows "Belief begins at the centre."

---

## 8. Integration (names; no code yet)

**Runtime**
- `AscensionRunner` (child of the player, beside `ManifestationRunner`): rebuilds an `AscensionContext` from the owned set on `refresh()`; exposes the standard runner surface (`get_power_multiplier`, `get_haste_multiplier`, `get_move_speed_multiplier`, `get_damage_taken_multiplier`, `apply_to_melee_slash`, `apply_to_magic_impact`, `apply_to_managed_hit_profile`, `consume_attack_bonus`) plus `get_rule(key, fallback)` and one new poll `dash_cooldown_multiplier`; demand-driven `RunEvents` wiring like the manifestation runner; child `AscensionActive` nodes per owned active implementing the HUD contract (`active_cd_changed`, `active_failed`, `get_active_state()`, `hud_priority`, `hud_key_text` "Q" / "V", `active_action`, `set_level`, `reset_cooldowns`); routes cooldowns through `Global.doctrine_active_cooldown()` and calls `notify_active_augment_used`.
- `AscensionState` (sibling of `ManifestationState`): Force, Heat, Verdict threshold, Debt ledger, Sigil / Coordinate / Link registries, the 10 s damage-taken ledger, and a per-enemy status registry with expiry (Sentenced, Primed, Read, Fractured, Beacon, Linked, Subjugated). Momentum is claimed on the existing state, not duplicated.
- `ProcTag` on MeleeSlash, MagicImpact and managed projectiles (origin, generation, allowed children, budget, no-self).
- The owned set is the only state; everything else is derived on refresh. Mutations sync by clearing every `asc_*` key in `attempt_mutations` and re-adding, so the inline `has_mutation` reads in the spawn functions keep working and refunds need no revert bookkeeping.

**Data**: `AscensionNodeDef` (Resource, mirroring `MajorChoiceDef`: id, title, description, icon, ring, node_class, subtree, base_cost, prerequisites any-of / all-of / min, gate_nodes, requires_peak, requires_doctrine_ids, exclusive_with, hub_only, permanent, max_rank, ratio, gift / price / consequence text, build_tags, effects), `AscensionEffect` (`can_apply`, `contribute(ctx)`, `get_preview_lines`) with `ASE_StatMul`, `ASE_StatAdd`, `ASE_AddMutation`, `ASE_SetRule`, `ASE_GrantActive`, `ASE_MutateActive`, `ASE_Repeatable`; `AscensionDB` loading `data/ascension/**/*.tres` and running the same validation as the builder. The JSON in `tools/design/ascension_tree.json` is the authoring source the `.tres` files are generated from.

**Global / save**: `attempt_peak_followers`, `attempt_followers_gross`, `attempt_ascension_nodes: Dictionary` (id → {rank, paid, segment}), `attempt_ascension_spent`, `attempt_ascension_refunded`, `attempt_ascension_sealed`, `attempt_ascension_slots` ({q, v}), `attempt_ascension_version`; `reach(seg)`, `tithe_unit()`, `round_stochastic(x)`, `compute_kill_reward(...)`, `can_spend_followers(amount)`, `ascension_node_cost(id)`, `try_purchase_ascension_node(id, at_hub)`, `refund_ascension_node(id)`, `ascension_refund_fraction(seg)`, `pulpit_available`. All reset in `start_new_attempt` and `on_attempt_failed_die_die`; mirrored in `SaveData.gd` as Dictionary / int fields beside the `attempt_doctrine_*` block (Dictionary, not a typed Resource, per the save-compatibility audit).

**Player composition**: `stat_ledger_step("ASCENSION · N NODES", s)` after DOCTRINE and before BELIEF; the runner's multipliers join the other runners in `_fire_weapon`, `get_effective_move_speed` and `_take_damage`. BELIEF row text becomes "BELIEF · PEAK N".

**Inputs**: `ascension_active` (Q, hold-capable) and `ascension_revelation` (V) plus `ascension_open` (T), added to both `project.godot` and `InputActionCatalog.gd` so the parity tests pass. E is left to the bag toggle; if that binding is ever dropped, E becomes the Revelation key.

**Feedback**: reasons `ascension_purchase` ("ASCENDED · −N"), `ascension_refund`, `ascension_upkeep` (aggregated), `witness_burst` ("WITNESSED · +N"), `objective_recruit`, `exodus`, each with a line in `FollowerFeedbackUI`.

**Telemetry**: `RunEvents.ascension_node_purchased(id, ring, cost)`, `RunEvents.peak_followers_changed(value)`; flight-recorder events under `progression`: `followers_income` (per minute, by reason), `ascension_purchase`, `ascension_refund`, `ascension_upkeep`, `peak_followers`, `reach_segment`; `BuildIdentity.compose` gains an `ascension` input (dominant wedge, Revelation) so the Run Sheet sentence names the investment; Revelation, Keystone and bridge purchases are recorded as doctrine-style events on the Observations page.

**Implementation budget** (what the nodes need beyond the runner; the per-node `needs` column in §5.1 is the itemized list): the per-enemy status registry; `extra_projectiles`, spawn-from-point, on-hit retarget, expire callback and bend on the managed projectile path; pooled Shell, Mine and Sigil scenes; dash charges and `dash_cooldown_multiplier`; a player displacement hook; a cooldown-refund API; teleport-with-i-frames; enemy velocity override (orbit, pull-to-point); camera-rect gather; a boss damage-cap helper; `LuckResolver` force-window and Lucky Crit cap / multiplier parameters; local time scale for designation.

**Tests** (headless `.tscn` suites): `AscensionEconomyTest` (Reach table, stochastic rounding expectation, peak tracked only through `transaction_followers`, scaled floor, `can_spend_followers`), `AscensionTreeDefTest` (unique ids, resolvable prerequisites, symmetric exclusives, costs monotone by ring, permanent / hub_only by class, every Revelation has bounds and an operating cost), `AscensionPurchaseTest` (escalation, fork sealing, wedge and peak gates, floor refusal, refund fraction by segment, permanent rejection, connectivity rule), `AscensionRunnerTest` (ledger row before BELIEF, rules recomputed after refund, `asc_*` mutations synced), `AscensionPulpitTest` (tab gated by `pulpit_available`, hub-only classes disabled, bag pause owns the tree), `AscensionLayoutTest` (same JSON → identical positions, no overlaps), plus updates to `RunSheetLedgerTest` (peak-keyed BELIEF), `FollowerFeedbackPresentationTest`, `HudContextPresentationTest` / `IdlePollGateTest` (catalog parity), `InterfaceThemeConsistencyTest` (the new screen's variations) and `BuildIdentityTest`.

**Build order** (the brainstorm's §36, kept): 1. income audit and the economy correction (Reach, peak, belief, floor, kill-reward helper) with its tests; 2. tree framework (defs, purchase / refund ledger, save, the screen with zoom / pan / tooltip, Hub button, Wardstone tab); 3. node classes; 4. Melee · Execution complete; 5. full Melee; 6. Ranged and Magic; 7. one bridge (Melee + Magic) with the recursion tags; 8. Ascendant and sinks.

---

## 9. Load-bearing vs tunable

| Decision | Load-bearing | Starting value | Tunable range / by what |
|---|---|---|---|
| Income scales geometrically with segment | yes (shape) | ×1.35 from segment 3 | 1.30–1.40; telemetry Q1, Q12 |
| Belief keyed to peak, capped | yes | 0.02 · log2(1 + peak/25), cap 0.30 | coefficient and cap; Q9 |
| Fixed capital costs with per-class escalation | yes (shape) | table §3.5 | every base; Q4, Q5 |
| Revelation escalation ×2 | yes | 300k, 600k, 1.2M | base; Q4 |
| Peak gates ≈ 1.7–2× the ring's first cost | yes | §3.6 | absolute values; Q5 |
| Wipes charge per target after resolution, partially applied | yes (shape) | 2 / 10 × reach | constants; Q8 |
| Actives cost cooldown only | yes | — | — |
| Sinks geometric, ratio > Reach, hard-capped | yes | 60k × 1.3–1.5 | bases and caps; Q10 |
| Refund share decays by segment, sworn classes never refund | yes | 0.50 × 0.90^(seg−2), floor 0.10 | start, decay; Q7 |
| Hub full tree, Wardstone limited | yes | Small / Mechanic / Mutation / Sink at the stone | whether Mutations stay; Q6 |
| One Q and one V slot | yes | — | — |
| Wedge composition (17–18 nodes, one of each big class) | yes | — | Small ranks and Mechanic count per wedge |
| Every Revelation's caps and boss rule | yes | per node | numbers; Q8, playtest feel |
| Every node's numbers | no | per node | all; Q2, playtest |
| Reach applied to shop and tithes | yes | same factor | none |
| Witness bursts | no | 8 kills / 0.6 s, +6 × reach | Q2 |

## 10. Telemetry and playtest questions

1. Followers per minute per segment 1–5 per style, by reason (`followers_income` events). Decides the 6,000 gross assumption and whether Reach starts at segment 3.
2. Share of income from ordinary kills vs bursts / elites / objectives. Target ordinary ≤55%; if bursts exceed 20%, lower the 6 × reach burst.
3. Deaths per segment and die-die rate after the Reach-scaled flat floor. Target die-die <5% of runs past segment 3.
4. Segment of the first Mechanic (target: Hub after s2) and the first Revelation (target: s16–17). If later than s19, halve the Revelation base or drop the gate to 400k.
5. Hoard ratio (on hand at the Hub / that segment's gross). Target 0.9–1.3; >2 means gates too high or costs too low; <0.6 means the floor or upkeep starves purchases.
6. Wardstone vs Hub purchase split (target ~30/70) and whether players open the bag inside a stone under pressure.
7. Refunds per run (target ≤2; more means the curve is too generous).
8. Upkeep as a share of segment income for wipe owners (target 15–30%).
9. Whether players notice the BELIEF row after the rescale, and its Power share vs the tree (belief should never exceed the Mortal ring's total).
10. Sink ranks per segment after s25 (target 0.7–1.2).
11. With the `maxi(1, …)` floor removed, does Overtime income decay toward zero without the Exit Rite feeling unpaid.
12. Does segment 10 feel ten times segment 2 (decides the Reach ratio).
13. Per wedge: did the player's inputs change (the §5 "the player now…" column), measured by the wedge's own counters (executions, dashes through enemies, Force banked, Reads, Heat time above 50, Shells placed, kills near Sigils, Coin flips, Compel pulls).

## 11. Open questions kept open

- Whether Mutations stay purchasable at a Wardstone (design says yes; Q6 decides).
- Whether E should replace V for the Revelation once the bag toggle no longer needs it.
- The "Schism" ritual respec: which world event grants it, and whether it also lifts a sealed fork.
- Attention: which peak titles trigger which world responses; this document only records the titles.
- Migrating `MajorChoiceDef` into `AscensionNodeDef` (v2).
