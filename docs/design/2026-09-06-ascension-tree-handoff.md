# Ascension tree — handoff note (2026-09-06)

Written for whoever picks this up next. Everything below is designed and mocked up; **no game code changed**. Commit `086042a` on `enemy-world-work`.

## What exists

- **The design:** `docs/design/ASCENSION_TREE_SPEC.md` — research verdicts, economy with numbers, structure, all nine wedges as node tables, bridges, integration with the existing systems, UI, tests, a load-bearing vs tunable table, and the telemetry that settles each tunable.
- **The mock-up:** `tools/design/ascension_tree_mockup.html`. Double-click it; no server needed. Style tabs, a segment slider that drives Reach, the reconstruction floor and the refund share, editable Followers, Hub vs Wardstone mode, hover path preview with totals, click to buy (a confirm panel for sworn nodes), right-click to renounce, filters, search, arrow-key walking, wheel zoom, drag pan, a minimap and a validator panel. URL presets for screenshots, e.g. `#style=ranged&seg=20&balance=1500000&buy=rng_bar_rev&focus=rng_ord_act&zoom=1.5`.
- **The data:** `tools/design/ascension_tree_data.py` is the one source of truth for all 194 nodes. `python3 tools/design/build_ascension_tree.py` validates the graph and regenerates `ascension_tree.json`, the mock-up's data block and the spec's node tables, so the document and the prototype cannot drift. Edit the data file, run the script, commit all three.

## What was kept, changed, rejected, added (relative to the root brainstorm file)

**Kept:** nine wedges and their names, forks, Revelations as the screen wipes, ability mutation clusters, Axioms, authored bridges, per-target operating costs, endless sinks, peak vs current Followers, Attention deferred.

**Changed, and why:**
- The economy fix is income, not prices. Kill rewards are flat today, so any big price collapses within a few segments. Income now scales by **Reach** (×1.35 per segment from segment 3); prices stay fixed per class and ring and escalate per class owned, so a saving target never moves while you farm for it. Segments 1 and 2 are numerically unchanged.
- **Belief Power keys to peak Followers** instead of being deleted, so spending on the tree never lowers it and hoarding stops being the power source.
- **Peak-congregation gates** the outer rings (30k, 500k, 5M, 50M): you must once have been believed in, and holding that hoard is dangerous under the 20% death tax. That tension is the design.
- The four damage-shaped apexes are told apart by gate, not by number: Decimation is HP-fraction gated, Total Fire Mission is telegraphed and delayed, The World Breaks First scales with damage taken, The Host only multiplies what you placed. Kneel deals no damage. Consensus Failure has a whitelist and a hangover.
- Momentum claims the existing manifestation meter; Invocation's constructs become **Sigils** so "Manifestation" stays the item-layer word.
- The Doctrine picks at segments 3/6/9 stay free and forced and become the tree's centre.

**Rejected:** a crit stat and generic cooldown smalls (no such stats exist; Precision uses per-enemy Reads, Distortion owns Lucky Crit), Ordnance drones (Spiderlings exist), segment-inflated prices, a global per-purchase fee, per-segment Follower caps, Wolcen's rotating rings, Enshrouded-style cheap respec, "for a duration everything triggers everything" hybrids.

**Added:** Witness nodes as the hybrid gate, one slotted Q (Active) and one V (Revelation) instead of more hotkeys (E is taken by the bag), Heat Is Universal and Sovereign Ground, a per-enemy status registry (Sentenced, Primed, Read, Fractured, Beacon, Linked, Subjugated), Witness bursts, and a recursion tag on every generated attack.

## Numbers to keep in view

| Segment | Reach | Expected Followers on hand at the Hub |
|---|---|---|
| 2 | 1 | 5,700 |
| 5 | 2.46 | 16,000 |
| 10 | 11 | 73,000 |
| 20 | 222 | 1.5M |
| 40 | 89,300 | 590M |

First Mechanic after segment 2, first Revelation around segment 16, first bridge around 24. The brainstorm's own §38 example (1.84M on hand, eyeing a 750k Revelation and a 2.5M bridge) lands at segment 20 on this curve.

Costs: Small 150/300/600 by ring (+10% per Small owned), Mechanic 2.5k/4k/12k (×1.15 per owned), Mutation 25k, Keystone 35k, Fork 50k, Active 60k, Axiom 40k, Capstone 80k, Revelation 300k (×2 each), Witness 300k, Bridge 2.5M, Ascendant 25M, Sinks 60k × 1.3–1.5 per rank. Refund = paid × clamp(0.50 × 0.90^(segment−2), 0.10, 0.50), Small/Mechanic/Mutation only, Hub only; sworn nodes never refund.

## Still open (spec §11)

Whether Mutations stay buyable at a Wardstone; whether E replaces V once the bag no longer needs it; the Schism ritual respec; which peak titles trigger world responses.

## Build order (spec §8)

1. Income audit and the economy correction (Reach, peak tracking, belief rescale, scaled floor, one kill-reward helper) with tests.
2. Tree framework: node defs, purchase/refund ledger, save fields, the screen (zoom, pan, tooltip), Hub button, Wardstone tab.
3. Node classes.
4. Melee · Execution complete, then full Melee, then Ranged and Magic, then one bridge (Melee + Magic) with the recursion tags, then the Ascendant and sinks.
