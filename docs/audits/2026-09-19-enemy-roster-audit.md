# Enemy roster audit and proposed additions, 2026-09-19

Proposed changes only; nothing here is coded. The numeric roster table
lives in `docs/current_game_data.md` section 8 (still accurate against the
spec files today) and is not repeated; this document reads it against the
spawn table, the Threat Director, the encounter beats, the September 18
melee playtest and the build simulator's revision-2 campaign, and asks
what the roster does and does not do to a build.

Sources: `core/actors/enemy/EnemySpec_*.tres` (17 specs), `EnemySpec.gd`
defaults, `data/enemies/spawn/SpawnTable_Default.tres`,
`autoload/ThreatDirector.gd`, `core/systems/encounters/EncounterBeats.gd`,
`core/actors/enemy/EliteModifiers.gd`, `scenes/world/events/{Boss,MiniBoss}Arena.gd`,
`docs/audits/2026-09-18-gravemarch-playtest.md`,
`docs/audits/2026-09-19-build-simulator/campaign3-rev2/`.

## 1. What the roster is

- **11 behaviours** (`EnemySpec.AI`): chase, orbit, ranged, charge,
  bomber, summoner, splitter, tactical (cover-seeking; only as an elite
  override), leech, herald, sniper.
- **13 ambient-capable enemies**, of which **11 are in the ambient spawn
  table** (Brute only arrives through the Shield Wall beat; the Summoned
  Minion only through Summoners), **2 bosses** that also serve as the
  minibosses (Bulldozer = tank, Arcanist = mage, coin-flipped), 2 opening
  actors.
- **Ambient unlocks are a clock inside the segment**, not the segment
  number: Orbiter at 30 s, Spitter 60 s, Charger and Sniper 90 s, Bomber
  120 s, Leech 150 s, Summoner 180 s, Herald and Splitter 210 s. The
  playtest's segments ran 297-528 s, so every unlock happens every
  segment, but the first three minutes of segment 10 are the same
  roster as the first three minutes of segment 1, only multiplied.
- **Weights**: Grunt 6.0 (picked as 1-2), Runner 2.6, Orbiter 2.0,
  Spitter 1.8, Charger 1.2, Bomber 1.1, Leech 0.7, Summoner 0.6, Herald
  0.55, Splitter 0.32, Sniper 0.28. Grunt and Runner are 51% of every
  late-segment pick; the five specialists (Leech, Summoner, Herald,
  Splitter, Sniper) are 15% and capped at 2-8 alive each.
- **Multipliers**: `hp = 1 + 0.14 (seg - 1) x 0.22 + heat x 0.85 (+
  Overtime)`, `damage = 1 + 0.14 (seg - 1) x 0.12 + heat x 0.08 (+
  Overtime)`, speed at most x2, spawn interval x0.95 -> x0.55 with heat.
  At segment 6 near the exit (heat 0.85) that is HP x1.87 and damage
  x1.15; the simulator's tiers (x1.63-1.93 / x1.07-1.24) sit on this
  curve.
- **Elites**: 0.5-3.5% per ambient pick (Sniper 20%), + heat x 0.08, +
  Overtime up to 0.65; five modifiers (armoured, vampiric, shielded,
  splitting, fast), 0 / 0 / 1 / 2 of them per elite by segment phase.
- **Nine beats** (charger wedge, shield wall, sniper crossfire, nest,
  hunter, bomber carpet, leech ring, ritual interference, rite
  crossfire), phase-gated from disturbance onward, 90-180 s cooldowns.
- **Pressure on the player** is contact (10 x swarm up to 2.25 x
  multiplier every 0.5 s per touching enemy), Spitter bolts (5 every 1.4
  s), Herald bolts (3 every 2.2 s), Sniper lines (10, 0.9 s tell),
  Bomber blasts (12 in 105 px), Leech and Herald Follower drains.

## 2. Findings

### R1. The roster is paper against a mid-run build

Enemy HP runs 8-60 (bosses 150-180). A median revision-2 build removes
1,300 HP/s at seg2 and 4,000-7,000 HP/s from seg6 (campaign 3, medians
over 296 builds); the melee playtest averaged 7.5 kills per second over
56 minutes. A Charger's 0.55 s wind-up, a Bomber's approach, a
Summoner's 4.5 s cadence and a Leech's attach all take longer than the
enemy lives once it is on screen. The simulator had to give its crowd
four times the authored HP to measure anything at all. The behaviours
that do get to run are the ones that act from range or on arrival:
Spitters (8-9 volleys per 8-second fight at every tier), Snipers, and
bosses. Contact ticks land 2-5 times per fight and fall with tier.

### R2. Ranged fodder does the damage; melee fodder is a Follower pinata

Campaign 3 medians, damage before defences per 8-second fight: 161
(seg2) to 207 (seg9), of which the scripted volleys are the majority
at every tier; deaths per fight fell from 0.68 (seg2) to 0.04 (seg12)
with the revision-2 items. Grunt, Runner and Orbiter contribute
Followers and set procs (Corpse Bomb, Spillover, Mass Arrest banks),
not danger. The playtest's seven deaths were all in the collapse phase
(Overtime damage additions), not from the roster's own numbers.

### R3. Unlock timing ignores the segment

Because `start_time` is seconds since the spawner started, segment 10's
opening three minutes present the segment-1 roster with bigger numbers,
and the specialists only ever share the last third of a segment. The
Threat Director already carries a segment phase (recon, disturbance,
ascension, collapse) that the beats use; the ambient table does not.

### R4. Reward per point of HP is upside down

Followers per HP at rank 0 (mid reward): Summoner 0.25 (10 HP by
default, never overridden, so the roster's most rewarding enemy dies to
one hit), Bomber 0.25, Leech 0.22, Herald 0.23, Runner 0.19, Orbiter
0.18, Spitter 0.16, Charger 0.16, Grunt 0.10, Brute 0.045, Sniper 0.04
(40 HP for 1-2), Splitter 0.008 (60 HP for 0-1, children 0-1 each).
The three enemies that take the longest to kill pay the least.

### R5. Specialists are rare, capped and late

Leech (max 8 alive), Summoner (7), Herald (6), Sniper (2), Splitter (4)
are 15% of picks and only after 150-210 s. The Splitter's elite chance
is capped at 0.003 by design. A player who clears segments in five
minutes meets a Herald a handful of times per segment.

### R6. Nothing on the roster speaks to the Ascension tree

The tree's resources (Force, Heat, Momentum, Read, Sigils, Wells, Debt,
Links) and its rules (execute lines, Weak Points, Coordinates) have no
enemy that tests them. The only resource interactions are Leech and
Herald draining Followers. There is no enemy that punishes standing
still (Bastion's Anvil, Dominion's Sovereign Ground and Precision's
Held Breath all reward it), none that shields allies from projectiles
(Barrage and Precision have no reason to change target), none that
heals or armours the crowd (no priority target for area builds), none
that removes placed objects (Sigils, Wells, Mines, Coordinates) and none
that breaks Links. The only mechanic enemies apply to the player is
damage.

### R7. The elite layer is an Overtime phenomenon

At 0.5-3.5% per pick plus 8% at full heat, an elite is rare until
Overtime adds up to 65%; with five modifiers and a two-modifier cap in
collapse, elites express mostly after the exit unseals. Hunter is the
only authored elite outside the arenas. Shielded (allies take half
damage within 180 px) and Vampiric (drain 10% of nearby allies to heal)
are the roster's only support behaviours and only elites carry them.

### R8. Two bosses, two roles, four jobs

Bulldozer (charge) and Arcanist (ranged) are both the segment boss and
the miniboss, chosen by coin flip. A ten-segment run meets the same two
bodies up to twenty times.

## 3. Proposed changes to the existing roster

| # | Change | Why | Confirm |
|---|---|---|---|
| E1 | **Done.** Re-base HP to the role's time-to-act: Grunt 10 -> 12, Runner 8 -> 9, Orbiter 14 -> 18, Spitter 16 -> 22, Charger 22 -> 30, Bomber 12 -> 16, Leech 18 -> 24, Summoner 10 -> 28, Herald 28 -> 34, Sniper 40 -> 34, Brute 55 -> 70; keep bosses. | R1: the behaviour must survive long enough to run once; the Summoner at the default 10 HP is a data bug. Sniper down because it is the one specialist that already acts from safety. | Simulator with `SIM_HP_MUL` 1 and a per-spec lifetime column (section 5); playtest deaths by cause. |
| E2 | **Done** (`EnemySpawnEntry.min_phase`, `EnemySpawnTable.unlock_time_scale`, `SpawnUnlockTest`). Unlock by segment phase, not seconds: each entry gets `min_phase` (Grunt/Runner recon; Orbiter/Spitter/Charger disturbance; Bomber/Leech/Sniper ascension; Summoner/Herald/Splitter collapse) and `start_time` scales by `max(0.35, 1 - 0.08 (seg - 1))` so segment 8 reaches its full roster in a third of the time. | R3, R5. | Spawn table test: the roster at segment 8 minute 1 contains every phase-eligible entry. |
| E3 | **Done.** Weights: Grunt 6.0 -> 4.5, Runner 2.6 -> 2.2, Leech 0.7 -> 1.0, Summoner 0.6 -> 0.9, Herald 0.55 -> 0.8, Splitter 0.32 -> 0.5, Sniper 0.28 -> 0.4; Brute into the ambient table at 0.5 from disturbance, max 6 alive. | R5; the Brute is the only heavy body and is beat-only. | Same test; campaign kill mix by spec. |
| E4 | **Done.** Rewards by durability: Sniper 1-2 -> 3-4, Brute 2-3 -> 4-5, Splitter parent 0-1 -> 2-3 with children 1 each (elite bonus unchanged), Summoner 2-3 -> 3-4 after E1. | R4. | Follower economy probe's death-path rows. |
| E5 | **Done.** Elite base chance x2 across the table (Grunt 0.5% -> 1%, specialists 3-3.5% -> 6-7%, Sniper stays 20%) and one modifier already in disturbance. | R7: elites should be a mid-segment event, not a collapse one. | Campaign elite share by tier. |
| E6 | **Done** (`EnemyActor.apply_ward_buff`, `HeraldWardTest`). Give the Herald's pulse a second effect the tree can feel: allies inside the pulse gain 20% damage reduction for 1.8 s (a soft Shielded) instead of only speed. | R6, R7. | Ablation of Herald-heavy crowds in the simulator. |
| E7 | Minibosses draw from a third pool of elite specialists (an elite Summoner with two Heralds, an elite Sniper pair, an elite Splitter) before the two bosses are reused. | R8. | Arena test. |

## 4. Proposed new enemies

Each reuses an existing module so the cost is a spec, a scene and one
behaviour hook, and each answers a specific gap in R6. Numbers are
rank-0, before the Threat Director.

| # | Name | Behaviour (module) | What it tests | Counter-play | HP / speed / reward / drop | Where it spawns |
|---|---|---|---|---|---|---|
| N1 | **Built** (`EnemySpec_Warden`, `front_shield_*` on the actor, absorbed in `EnemyCombatService._apply_damage`; `WardenTest`; the Warden Line beat). **Warden** | Slow bulwark (CHASE) with a frontal 160-degree shield that consumes ordinary player projectiles and impacts (the Bastion Guard sector rule, mirrored); the shield drops for 1 s after it absorbs 8 hits or when struck from behind. | Ranged and magic builds that never re-aim; Barrage's straight lines; Precision's one line. | Flank, pierce with Weak Points, melee, or bait the 8-hit drop. | 48 / 52 / 3-4 / 0.25, R1-2 | Ambient from disturbance, weight 0.6, max 6; beat "Warden line" (3 Wardens + 2 Spitters behind). |
| N2 | **Built** (`EnemySpec_Chanter`, `EnemyChanter.tscn`, ambient from ascension at weight 0.6; no flee yet). **Chanter** | Support caster (HERALD structure): no attack; every 2 s heals allies within 200 px for 8% of their max HP and grants 15% damage reduction for 2 s; flees to 300 px (TACTICAL retreat) when hurt. | Area builds that ignore the crowd's composition; execute lines (healing pulls bodies back above the line). | Priority target; pull it out of the pack (Dominion, Compel); Marked/Read it. | 26 / 80 / 4-6 / 0.35, R2-3 | Ambient from ascension, weight 0.5, max 4; beat "choir" (1 Chanter + 6 Grunts + 2 Brutes). |
| N3 | **Built** (`EnemySpec_Lurker`, charge gated on a still player, dormant 1.5 s, holds 360 px; ambient from ascension at 0.5; `LurkerTest`). **Lurker** | Ambusher: spawns dormant at the screen edge (invisible to targeting rules for 1.5 s), then charges (CHARGE) only when the player has stood still for 1 s or is channelling; 0.4 s tell; 1.5x contact on the hit. | Anvil, Sovereign Ground, Held Breath, Deadshot's stop, the Exit Rite channel: everything the tree pays the player to stand still for. | Keep moving between commitments; kill it in its tell; Plate and Guard absorb it. | 20 / 150 / 3-4 / 0.2, R1-2 | Ambient from disturbance, weight 0.4, max 3, elite 8%; replaces Hunter as the authored elite beat ("stalker": elite Lurker, fast). |
| N4 | **Weaver** | Linker: tethers itself to up to three allies within 220 px (visible threads); tethered allies share 40% of damage taken with each other and are dragged when one is moved; the Weaver is a slow ranged caster otherwise (RANGED, 3 damage every 2.5 s). | Dominion's Bind and Collision (the player's own links versus the enemy's), knockback and pull builds, single-target builds (damage leaks into the group). | Kill the Weaver (threads snap and stun the tethered for 0.5 s); use the threads (pull one, pull all). | 30 / 66 / 5-7 / 0.35, R2-3 | Ambient from ascension, weight 0.45, max 3; beat "loom" (1 Weaver + 4 Orbiters). |
| N5 | **Built** (`leech_drains_meter`, `AscensionRunner.drain_discipline`; the placed-object part is not built; `SiphonTest`). **Siphon** | Resource eater (LEECH): while attached it drains the equipped discipline's meter instead of Followers (Force, Heat, Momentum, Read or Aim -8 per 0.75 s), and walking over a Sigil, Well, Mine or Coordinate consumes it (Sigil growth feeds it: +4 HP each). | Every placed-object and meter build; the "leave my stuff alone" reflex. | Kill on sight; Sigil Endure and Immovable resist it; it never drains Followers, so the Leech keeps its job. | 22 / 100 / 3-5 / 0.24, R1-2 | Ambient from disturbance, weight 0.6, max 6; beat "siphon pair" off-route near placed objects. |

One elite modifier to add alongside: **Warded** (the elite ignores the
first Revelation payload that hits it and is stunned by it instead),
collapse-only, so Revelations keep their value but stop being the
answer to elites.

## 5. Measurement before any of this ships

- Add per-spec outcomes to the simulator rows: kills by spec id,
  time-to-death by spec (spawn frame to `enemy_defeated`), damage taken
  by source role. The rows carry `by_origin` for the player's damage but
  nothing per enemy; R1 is argued from HP versus output, not measured
  lifetimes.
- Give the simulator an unmultiplied crowd mode (`SIM_HP_MUL=1`) per
  tier and report the share of spawned enemies that ever reach the
  player.
- Record deaths by damage source in the balance recorder's extended
  capture (contact, bolt, sniper, blast, drain, Overtime) and read the
  next playtest by it; the melee playtest only says "all seven in
  collapse".
- N1-N5 are design proposals: each needs a rendered playtest before
  its numbers mean anything, and N3 and N5 change how the tree's
  stand-still and placed-object nodes feel, which is a designer's call.
