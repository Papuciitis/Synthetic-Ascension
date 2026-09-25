# Ranged V5 vs V4 — first matched simulator baseline (2026-09-26)

Phase 1 Checkpoint 5 evidence (handoff 2026-09-25). Headless build-simulator
runs through the real ledger, runner and combat services; **diagnostic, not
proof of final balance** (three seeds, two random walks per tier, 600 frames,
crowd 60, no human at the controls).

## Exact commands

```
SIM_OUT=tmp_sim/<tree>_<seed> SIM_TREE=<v4|v5_ranged> SIM_SEED=<101|202|303> \
SIM_SOURCES=authored,random SIM_STRUCTURE=0 SIM_BUILDS=2 SIM_TIERS=0,1,2 \
SIM_FRAMES=600 SIM_CORES=ranged \
  ~/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path . \
  res://tools/tests/BuildSimulator.tscn --quit-after 0
```

`SIM_TREE` and `SIM_SOURCES` were added for this comparison; V5 authored
builds replay their rank purchases through `can_buy` (each spent its exact
authored subtotal: P1 2,500 / B1 2,850 / B2 3,400 / O1 2,150 / O2 4,550).
Raw rows: `docs/audits/2026-09-26-v5-sim-baseline/*.jsonl`.

## V5 authored builds, mean of three seeds

| Build | Spent | Enemy hp removed | Kills | Player hp lost | p95 max |
|---|---:|---:|---:|---:|---:|
| P1 Precision control | 2,500 | 11,887 | 87.0 | 46 | 2.6 ms |
| B1 No-Heat Barrage | 2,850 | 9,772 | 76.7 | 141 | 2.6 ms |
| B2 Thermal machine gun | 3,400 | 17,498 | 142.3 | 187 | 3.0 ms |
| O1 Automatic Grenadier | 2,150 | 15,137 | 113.7 | 94 | 2.8 ms |
| O2 Explosive chain specialist | 4,550 | 14,011 | 94.0 | 182 | 2.0 ms |

Readings (prototype-level):

- **B1 vs P1 (the spec's essential A/B):** B1 delivers comparable output at
  triple the incoming damage — a brawler identity rather than a control
  identity, and it does this with **no Heat bar and no Jam**. It is
  competitive without dominating; the "dull basic gun" failure mode did not
  reproduce here, but only a human run can judge feel.
- **B2 opts into Heat and gets paid for it:** +79% enemy hp removed over B1
  at +33% more damage taken — the optional risk curve the redesign wanted.
- **O1 plays a real Grenadier without Mines or Coordinates** and takes less
  damage than the Barrage lines.
- **O2 underperforms O1 at this crowd density** despite double the spend;
  chain payoffs likely need denser packs than crowd 60 or a durable-elite
  scenario. Flagged for the human playtest, not tuned blind.
- **Performance:** p95 frame cost stayed ≤ 3.0 ms in every V5 run (V4 max
  2.9 ms); the overflow queue never engaged at these densities.

## Matched random walks (same seeds, both trees)

| Tier | V4 walk means (hp removed) | V5 walk means |
|---|---|---|
| seg2 / 3,000 | 12,925 / 8,946 | 13,123 / 14,348 |
| seg4 / 8,000 | 19,912 / 16,763 | 14,327 / 15,001 |
| seg6 / 16,000 | 25,373 / 40,217 | 38,586 / 36,164 |

Same-seed random ranged walks land in the same band on both trees: slightly
above V4 at seg2 (early rank investment pays), below at seg4, comparable at
seg6. Nothing pathological in either direction; two walks per tier is far
too small to tune from.

## Not covered here

Durable-target scenarios, hybrid seeds, the free-choice run, noticeability
evidence (can the player see a rank purchase), Spin Up uptime and grenade
telemetry per family, and every feel judgement — those need rendered play
and the balance recorder, which the handoff reserves for human sessions.
