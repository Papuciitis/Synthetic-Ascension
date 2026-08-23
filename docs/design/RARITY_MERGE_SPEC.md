# Rarity & Merge Mass — spec v3 (2026-08-23, GREENLIT)

Status: baseline design, second designer pass complete. The core math
package is IMPLEMENTED with invariant tests (commit `merge-math v2`).
Remaining work is UI (K6), content and tuning — not foundational design.

The design promise (July, verbatim intent):

> Every duplicate has value forever, but items close to your current
> rarity are much more valuable.

## 0. The headline finding (unchanged)

The July model is **already ~80% implemented** in `ItemInstance` +
`RarityMath`: continuous `upgrade_meter`, unbounded `rarity`, gap
penalty `2^(gap)`, quality factor from the material's roll, overflow
retention, identity preservation, `potency = 1 + 0.45√R + 0.05R`.
This effort is therefore: make hidden math coherent, balanced and
visible — not design a crafting system.

## 1. The model (with decided values)

### 1.1 Merge value

```
mass  = quality(material) × 2^((R_material − R_destination) / H)
meter += mass
```

**H = 1.5 — LANDED** (first playtest value; revisit against real drop
frequency). Destination is always the higher-rarity instance —
auto-swap LANDED as a *payload* swap: the surviving object keeps its
equip slot, lock and UI identity while adopting the higher progression
(designer ruling: mathematical destination, never a literal object
swap). Identity is pinned by test.

### 1.2 Quality of material

```
quality = 0.75 + 0.50 × |roll| / authored_extreme      (0.75 … 1.25)
```

**DECIDED: keep the current band** (veto on widening to 0.60–1.40).
Rationale: a god-roll duplicate already transfers its roll to the
survivor (§1.5), so widening would triple-reward the same lucky drop —
and would make severe curses premium merge mass on top of everything
else. Optional later test: 0.70–1.30, nothing wider.

### 1.3 Thresholds and overflow — LANDED

One rank costs `meter = 1.0` in units relative to the current rank; on
crossing, leftover is re-measured against the next rank:

```
meter = (meter − 1.0) × 2^(−1/H)        (= ×0.63 at H = 1.5)
```

In code (`RarityMath.overflow_factor()`), with a test asserting the
ratio. Large merges can cross multiple ranks (E13).

### 1.4 Consuming a partially-fed duplicate — LANDED

Material's stored meter transfers as mass at the material's **own**
rank scale. **Path-independence is a hard invariant with a 1e-6
test**: merging a half-fed carrier yields exactly what feeding both
copies directly would have (the old `R+1` scale made carrier-first
pre-merging create 29–100% free mass).

### 1.5 Roll identity — **CHANGED per ruling D1, LANDED**

- Rank-up never rerolls (unchanged).
- POS merge keeps the strongest roll (unchanged).
- NEG merge now **stabilizes by default: the MILDEST roll survives** —
  normal progression refines a curse the way it refines a stat, so a
  deliberately mild Ballast curse can never be ruined by feeding
  duplicates.
- **Corruption Engine, while equipped, inverts NEG progression: merges
  keep the MORE severe roll.** The augment doesn't just grant Power —
  it changes what item progression *means* ("fuck stabilizing it,
  feed the corruption"). LANDED in `ItemInstance.merge_from` with
  regression tests for both directions.

### 1.6 Stat scaling per rank — DECIDED: keep curve, add guardrails

```
potency(R) = 1 + 0.45·√R + 0.05·R
```

CORRECTED (review finding — the wiring is two different curves):
- **Item stats** use `rarity_base × (potency(R) − 1)` = zero at R0;
  the rarity-derived contribution at R10 is **3.85×** the R1 value
  (k: 0.5 → 1.92), not +95%.
- **Set strength** (`Inventory.get_set_strength`) uses full
  `potency(R)`, where R10 is +95% over R1 (1.50 → 2.92).
Both shapes are fine for their jobs — but they are different numbers,
and balance talk must name which curve it means.

**Guardrail requirement (new, from ruling):** the raw curve is only
safe for "big number" families (Max HP, damage/Power-flat, Armor).
Rate/percentage families — move speed, haste, lifesteal, evasion,
anything multiplicative with time — need per-family caps or transforms
before extreme rarity reaches them. Concrete example with today's
data: Conduit Greaves has `rarity_base.move_speed = 10`; at R100 that
is +95 flat speed on a 200 base (+47%) from ONE item. Rule of thumb:
any stat that already has a systemic cap (lifesteal budgets) keeps
its cap; speed/haste from `rarity_base` get a soft-cap transform when
items granting them are authored. Assume someone WILL build an R347
garbage item and try to break physics — that's appropriate for this
game; the guardrails decide which physics are breakable.

## 2. Knob table — final state

| # | Knob | Decision |
|---|---|---|
| K1 | Gap half-life H | **1.5** (accepted as first playtest value) |
| K2 | Quality band | **keep 0.75–1.25** (widening vetoed; 0.70–1.30 allowed as a later experiment) |
| K3 | Potency curve | **keep**, with per-stat-family guardrails (§1.6) |
| K4 | Same-rank avg merge ≈ +1 rank | **keep** |
| K5 | NEG merge direction | **vetoed as global rule** → default stabilizes; Corruption Engine deepens (§1.5, LANDED) |
| K6 | Meter visibility | **required** (§4) |

## 3. Worked examples (H=1.5, quality 0.75–1.25)

"avg roll" = 50% of authored extreme (quality 1.00); trash = 0%
(0.75); god = 100% (1.25).

| # | Case | Mass | Result |
|---|---|---|---|
| E1 | R0 + R0 (trash) | 0.75 | still R0 at 75% toward R1 — pure banked progress (stats don't change until rank-up unless §5 continuous power is adopted; the roll only improves if the material's beats the survivor's) |
| E2 | E1 + another trash R0 | +0.75 → 1.50 | **R1**, meter (0.50 × 0.63) ≈ 0.32 banked |
| E3 | R0 + R0 (avg) | 1.00 | **R1** exactly — today's tested feel preserved |
| E4 | R0 + R0 (god) | 1.25 | **R1**, ≈ 0.16 banked |
| E5 | avg R0 fed to R5 | 2^(−5/1.5) ≈ 0.099 | ~10 average copies per rank |
| E6 | avg R0 fed to R10 | 2^(−10/1.5) ≈ 0.0098 | ~1% of a rank — tiny but VISIBLE (see §4) |
| E7 | avg R8 fed to R10 | 2^(−2/1.5) ≈ 0.397 | ~40% of a rank — serious upgrade material |
| E8 | god R8 fed to R10 | 1.25 × 0.397 ≈ 0.50 | half a rank from one great near-peer |
| E9 | R10 + R10 (avg) | 1.00 | **R11** — peers are a full rank at any level |
| E10 | R10 + R10 (god) | 1.25 | **R11**, ≈ 0.16 banked |
| E11 | Overflow with banked meter: R4 at meter 0.90 + god R4 | 0.90 + 1.25 = 2.15 | → R5 at meter (1.15 × 0.63) ≈ **72%** |
| E12 | R3 (meter 0.50) merged into R5 | 0.397 + 0.50 × 0.397 ≈ 0.60 | stored progress transfers at the material's own R3 scale (corrected model, §1.4) |
| E13 | Multi-rank: R4 at meter 0.90 + half-fed god R4 (meter 0.90) | 1.25 + 0.90 = 2.15 → meter 3.05 | crosses twice: (3.05−1)×0.63 = 1.29 → (0.29)×0.63 ≈ 0.18 → **R6 at 18%** |

The relationship reads: **low rarity = scraps · nearby rarity =
serious material · same rarity = jackpot.**

## 4. Legibility (K6 — required, not polish)

- Tooltip + bag stack: `R5 → R6 ▓▓▓▓▓▓░░ 62%`.
- On feed, show the transaction:
  `Feed R3: +18% · Roll −14% → −19% stabilized to −14% · R5 → 80%`.
- Tiny contributions must PRINT tiny, honestly: `Feed R0: +0.98%` —
  that number is the design promise ("the game knows this is low-level
  garbage; no, it isn't worthless").
- NEG feeds must state the direction in force: "stabilizing (mildest
  survives)" vs "Corruption Engine: deepening (most severe survives)".
- **UX split (designer ruling):** the FULL transaction line lives in
  bag/tooltip/manual compare only. Combat auto-feeds show a compact,
  short-lived element — `Conduit Heart R5 ▰▰▰▰▰▰▰▰ 80% (+18%)` — and
  successive feeds of the same item aggregate into one element. The
  math is transparent when you want it, never screaming over a
  500-enemy screen.

## 5. Continuous rarity power — DECIDED YES, LANDED

Designer ruling: YES — it makes the original "R0 + R0 = stronger R0"
promise literally true, and distant-rarity feeding stops feeling
meaningless because the stat moves immediately. Landed with the three
required conditions:

1. **Rate-stat guardrails in the same patch** — speed/haste rarity
   contributions plateau (~R13, `RATE_STAT_POTENCY_CAP`). LANDED.
2. **Current HP unchanged when Max HP grows** — verified: the player
   only clamps HP downward (`hp = min(hp, max_hp)`); growth never
   heals. Pinned as intended behavior.
3. **Power computed only from the normalized post-merge state** —
   recompute runs once, after the rank-crossing loop. LANDED.

The model:

```
effective_rarity = rarity + upgrade_meter
potency(effective_rarity) applied on every merge
```

Concrete numbers with shipped items:

| Item (rarity_base) | R0 | R0 @ 60% | R1 | R5 | R5 @ 62% | R10 |
|---|---|---|---|---|---|---|
| Conduit Heart (20 max HP) | +0 | **+7.6** | +10.0 | +25.1 | **+27.0** | +38.5 |
| Conduit Greaves (10 speed) | +0 | **+3.8** | +5.0 | +12.6 | **+13.5** | +19.2 |
| Ring of Regeneration (5 max HP) | +0 | **+1.9** | +2.5 | +6.3 | **+6.7** | +9.6 |

Observations:
- Every feed becomes physically real (+1.9 HP from one merge on an R5
  Heart) — the meter stops being an XP bar, which fits the fantasy.
- No boundary weirdness: the ×0.5 overflow conversion keeps effective
  rarity monotone through rank-ups.
- Cost: `_recompute_flat_mods` on every merge (trivial), and the K6 UI
  should then show the stat delta per feed, which is even better
  legibility.
- Risk: fractional potency also drips speed/haste items constantly —
  the §1.6 guardrails matter more under this model.

The K6 UI (below) should now show the stat delta per feed — the meter
is real, so show what it did.

## 6. Divergences — ALL RESOLVED

1. **ALL roll-based feeds bypass the gap math**, not just equip-feed:
   `feed_roll()` fabricates the incoming at the destination's own
   rarity, and BOTH the equipped-item path and `BagInventory.add_roll`
   route through it. Only real-instance drops (MODE A) pay the gap
   penalty via `merge_from`. Fix: pickups carry real rarity; both
   paths feed at it. One economy everywhere.
2. **Bag stacks get free rank-ups**: `add_roll` force-raises a stack's
   rarity to the incoming's rarity (`if rarity > stack.rarity:
   stack.rarity = rarity`) with zero mass paid. Must become a normal
   merge (the higher-rarity incoming becomes the destination).
3. Stale "same id + rarity + polarity" comment in ItemPickup.
4. **Meter transfer over-credit**: `merge_from` transfers stored meter
   at `R_material + 1` scale — 2^(1/H) too generous (§1.4). Change to
   the material's own rank.
5. **Overflow constant**: `× 0.5` must become `× 2^(−1/H)` when H
   changes (§1.3) — they are the same number only at H = 1.
6. **Auto-swap does not exist anywhere** (review finding): both
   `Inventory.add_or_feed` and `BagInventory.add_instance/_consolidate`
   always merge the incoming into the existing instance regardless of
   rarity. At H = 1 this is accidentally value-neutral (the ×0.5
   rollover exactly matches the 2^-gap rate, so direction doesn't
   matter). At H = 1.5 the wrong direction DESTROYS ranks — a fresh R4
   merged into an R0 stack ends at R2. Auto-swap (higher-rarity
   instance becomes destination) is MANDATORY in the same commit that
   changes H.
7. Vendor/undo: snapshot deep-copies verified; the same-instance
   buy/sell spread is strictly lossy — but the RANK-UP loop (buy a
   peer, merge, sell the upgraded item) is approximately break-even
   and can go slightly positive at the R0→R1 boundary at high Luck
   for low-stat-value items (the audit test never covers the loop).
   Guard when implementing: assert `compute_item_value` growth across
   a rank never exceeds the cheapest peer's buy price at max Luck, or
   accept the tiny R0→R1 arbitrage as an intended Follower faucet and
   say so.

## 6b. OPEN D4 — the honest horizon of "value forever"

Exponential gap decay in an unbounded system means an R0 into an R20
is ~0.01% of a rank — "forever" is technically true and perceptually
false past a window. Options:
(a) **State the horizon honestly** (recommended): duplicates are
    designed to matter within roughly a 10–12 rank window; beyond
    that they are flavor + pennies. The K6 UI prints the honest tiny
    number either way.
(b) A mass floor (e.g. min 0.5% of a rank) — REJECTED as recommended
    path: at extreme ranks a floor makes 1,000 hoarded trash copies
    worth 5 ranks, reintroducing the farming loop the gap penalty
    exists to prevent.

## 7. Non-goals (unchanged)

No fixed tiers · no Legendary ceiling · no separate crafting UI · no
rerolls on rank-up · accessories use this exact path · POS and NEG
never merge with each other.
