# Build simulator

`tools/tests/BuildSimulator.tscn` is a headless batch runner that buys builds
through the real advancement-tree rules, installs them on the real runner and
fights them on the real combat services, then writes one JSON row per build
with the balance recorder's attribution. `tools/sim/build_sim_report.py` turns
a run into `report.md`, `builds.csv` and `node_stats.json`.

## Run

```
SIM_OUT=<dir> SIM_BUILDS=16 SIM_FRAMES=480 SIM_SHARD=0/4 \
  <godot> --headless --path . res://tools/tests/BuildSimulator.tscn --quit-after 0
python3 tools/sim/build_sim_report.py <dir> --out <dir>/report --label "..."
```

Environment: `SIM_OUT` (output directory, relative to the project or
`user://`), `SIM_BUILDS` (random builds per Core per tier), `SIM_FRAMES`
(frames per fight at 60 simulated fps), `SIM_SEED`, `SIM_SHARD` (`i/n`:
shards split one job list by index, so four shards in parallel finish four
times sooner), `SIM_PRESETS` (include every preset, authored build and
prototype route), `SIM_STRUCTURE` (the tree structure pass, shard 0 only),
`SIM_TIERS` (comma list of tier indices), `SIM_CROWD`, `SIM_HP_MUL` (crowd
durability). Never run it during a human playtest.

## What a build is

Authored jobs are the 37 presets, 16 authored builds and 3 prototype routes,
replayed in order through `AscensionLedger.can_buy` with milestones satisfied.
Random jobs are seeded walks per native Core and budget tier: every step
picks among the currently buyable nodes weighted only by kind, buys it, and
stops when nothing is affordable; a Gate opens a random closed Core; Q and V
are re-equipped at random among what is owned. Tiers pair a segment with a
Follower budget, a gear rank and the ThreatDirector's enemy multipliers at
that segment (`disturbance`, resonance 0.6): seg2/3,000/R1, seg4/8,000/R3,
seg6/16,000/R6, seg9/32,000/R10, seg12/64,000/R15. Gear is one random set's
six core items at the tier rank plus two random accessories, neutral rolls,
worn through the real stat recompute.

## The scenario

A 60-body crowd drawn from the enemy specs' authored HP and rewards
(grunts, runners, orbiters, chargers, leeches, spitters, brutes, heralds,
snipers, splitters; every fifteenth an elite), scaled by the tier's enemy HP
multiplier and a durability factor of 4 so the crowd's available HP stays
above what a build removes, refilled by up to 20 bodies every half second.
Scripted inputs: a native strike every fourth frame at the nearest living
body (a random one 30% of the time), Q whenever it is off recovery (held Qs
stay held), V whenever it charged naturally, a dash every 90 frames. Scripted
pressure through the player's real damage path: contact ticks from contact
enemies within 56 px (10 x swarm x enemy damage multiplier every half
second), spitter volleys within 300 px every 1.4 s, one sniper shot every
3 s. Enemies do not move or act otherwise.

## What a row holds

Purchases and spend, equipment, gear, player stats, enemy HP removed and
kills (totals and per second), HP lost, deaths, minimum HP and 1 Hz HP
samples, healing, combat income, casts, generated attacks, chain
telemetry, damage by origin class and by tree node (attribution emitters
whose root is the node), engine counters, attribution coverage and frame
cost percentiles. The structure pass (`structure.json`) gives every node its
reachability, requirement closure and a guided-walk unlock cost (an upper
bound on the cheapest unlock), cross-checked against authored routes.

## Reading the report

Distributions per tier and Core; damage share by origin class; node pick
rates in random walks (a structural fact about buyability, not preference);
nodes that never attributed damage while owned (filtered to payload kinds,
still needs a human read: defensive and enabling nodes are silent by
construction); nodes by mean damage share; outliers within a tier; node
pairs enriched among the top decile; every authored build; the structure
summary; simulation cost. Lifts are correlational within one scripted
scenario. Campaign reports live under `docs/audits/2026-09-19-build-simulator/`.
