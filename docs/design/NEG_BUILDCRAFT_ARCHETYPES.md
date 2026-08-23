# NEG buildcraft — archetypes v3 (2026-08-23, GREENLIT)

Status: baseline design after two designer passes. A1 fully landed
(top-2, merge-deepening, asymptotic levels). The target state:

> Seven players look at the exact same NEG drop and value it for seven
> different reasons.

## Architecture concepts (new, from ruling D2)

Two separate properties, used consistently by everything below:

- **Polarity** — what the item intrinsically IS (`POS`/`NEG`). Never
  changes. Feeds: equilibrium counts, set polarity rules, ownership
  and acquisition history.
- **Active severity (burden)** — how much curse is currently affecting
  the character. Normally `|active_pct|`; an Inversion-suppressed item
  has active severity **0** while remaining NEG in polarity.

| Mechanic | Inverted NEG counts? |
|---|---|
| A1 Corruption Engine severity | No |
| A2 Burden count | No |
| A5 Litany scaling | No |
| A3 Equilibrium parity | Yes |
| Set polarity rules (A6) | Yes |
| Ownership / acquisition (A7) | Yes |

## Principles (unchanged)

1. Each archetype wants NEG for a DIFFERENT resource.
2. Luck biases polarity odds but never eliminates NEG — the ≥20%
   floor is clamped in code (LuckResolver); the audit test asserts NEG
   stays possible at extreme Luck (a dedicated floor test is a cheap
   follow-up).
3. Fantasy register: synthetic magic — rites, sigils, doctrine. Never
   terminals/hacking/neon.
4. Every archetype names its degenerate case and guard.

## The archetypes

### A1 — Corruption Engine (concentrated severity) — LANDED (v2 form)
"A conversion chamber with two intake valves."
Only your **two most severe** active curses feed it: Power per 100%
combined severity at an asymptotic level rate — 24% x L/(L+1), so
L1 = 12%, later levels approach but never reach 24%, no dead levels —
output capped at +30%. **While
equipped, NEG merges DEEPEN: the more severe roll survives** — the
augment changes what item progression means (see rarity spec §1.5).
Wants: two horrifying curses; the rest of the wardrobe is free.
Guard: top-2 rule keeps it from converging with A2's "wear many"
shopping list (that was v1's hidden flaw).

### A2 — Doctrine of Burden (count of real curses)
"A frame under burden grows dense."
(Renamed from "Ballast Doctrine" — Gravemarch already ships a tier
named "Ballast Frame" with the same armor headline.)
+Max HP and +Armor per equipped NEG item whose **normalized severity ≥
10% of its authored NEG range** (ruling D3: one global floor, tuned
from playtesting — never per-item authoring, never raw stat pct).
Numbers deliberately NOT locked (v1's +7%/+2 was illustrative only;
six pieces would be +42%/+12 — playtest first).
Wants: many mild-but-real curses. The default merge rule (stabilize
toward mild) IS this build's progression system.
Guards: the severity floor kills near-zero-curse cheese, and the
total contribution is CAPPED like A1 (exact cap from playtesting) —
see the stacking section.

### A3 — Equilibrium Sigil (parity) — KEEP AS WRITTEN
"The lattice holds when the ledger balances."
While equipped POS count == NEG count (≥2 each): +12% Power, +12%
Haste. Exact parity, all-or-nothing — brittle on purpose ("this is a
fantastic POS drop and I don't want it"). Inverted items still count
as NEG here (polarity, not burden).
Behavior requirement (review finding): pickups AUTO-EQUIP into empty
matching slots on contact, and the loot magnet pulls from 110px — a
parity player with an empty slot gets it filled without consenting.
While Equilibrium Sigil is slotted, auto-equip is disabled and
pickups route to the bag; the player curates the wardrobe by hand.
Future (explicitly deferred): items/sets reacting to BREAKING
equilibrium. Not in v1 of the augment.

### A4 — Inversion Lens (conversion) — flagship weird-build augment
"Read the curse backwards."
Your single most severe equipped NEG item (stat slots 0–5 only):
penalty suppressed to active severity 0, grants +35% (+5%/level,
**hard cap 60%** — levels are uncapped in code, and uncapped
conversion crosses 100% at level 14, making a suppressed curse
strictly better than any POS item) of its severity as its slot's
POSITIVE stat. The item REMAINS NEG in polarity — you haven't
purified it, you've reverse-engineered it so it can't hurt you. Which
is very Syn'Tek.
Wants: one apocalyptic curse (−90% becomes the build's crown jewel).
Guard (D2): suppressed severity counts for NOTHING burden-based — no
double-dipping into A1/A2/A5.

### A5 — Litany of Wounds (health bar as resource) — REWORKED
"He walks better bleeding."
Below 60% HP, NEG active severity converts to Haste on a continuous
ramp: conversion grows as HP falls, reaching maximum at 20% HP
(e.g. at 20% HP: +Haste = 25% of total active severity, cap +25%).
No on-hit window, no binary threshold camping — the question is
"lifesteal back to safety, or hover at 25% because I'm a blender down
here?" Style lifesteal becomes part of the archetype naturally.
Wants: severity AND deliberate low-HP play — the health bar is the
resource, which distinguishes it from A1 (v1's version was correctly
rejected as A1-with-extra-steps, and its NEG-max-HP rationale was
mathematically wrong).
Guard: the ramp bottoms at 20% — no extra reward for flirting with
1 HP; cap keeps haste physics intact.
Implementation note (review finding): the existing recent-damage
timer is melee-only, but the v2 ramp needs no timer at all — deliver
the bonus through the ItemEffectRunner get_haste_multiplier
aggregation, reading hp/max_hp and the severity sum directly.

### A6 — Gravemarch polarity rule (set mutation) — CHANGED per ruling
If 3+ equipped Gravemarch pieces are NEG: the tier-2 "Ballast Frame"
armor grant becomes a life-drain aura, and **the combined active
severity of those specific pieces drives a secondary characteristic**
(radius or pulse rate — NOT raw damage).
**Local merge mutation (designer ruling — strongest veto of the v2
round):** while the cursed mutation is active, **NEG Gravemarch
pieces deepen when fed another NEG Gravemarch copy** — only those
pieces. Without this, the default stabilize rule made A6 progress
BACKWARDS (feeding duplicates weakened the aura) unless Corruption
Engine was equipped: cross-archetype synergy is good, cross-archetype
dependency is not. A6 alone can now pursue cursed-set progression;
A1 + A6 still synergizes (Power from the now-horrific pieces).
Wants: specific set pieces cursed — a wardrobe-slot reason no augment
provides.
Implementation note (review finding): the polarity census already
exists — `Inventory.get_set_polarity_composition()` (audit-tested).
Define the census over set-tier slots 0–5, and the replaced bonus is
specifically the tier-2 "Ballast Frame" armor grant.

### A7 — Gambler's Rite (acquisition, Luck) — RESONANCE RULE CHANGED
"The crowd loves watching him court disaster."
- Follower proc: every legitimately NEW NEG instance acquired grants
  a Luck-scaled chance (15% + up to +20% from Luck) of +1 Follower.
- Resonance: **only the FIRST acquisition of each distinct NEG base
  item per segment** grants +0.5%, **capped at +4% total per segment**
  (designer ruling: without a cap, future content growth silently
  rebalances the Exit Rite — 80 items would mean 40% Resonance from
  collecting alone; Resonance is pacing and stays bounded; Followers
  keep proccing indefinitely — that is the economic identity).
  "Explore and collect different forbidden things", not "murder rats
  until twelve cursed boots fall out."
Implementation notes (review findings): the reward fires at the
moment a copy is actually CONSUMED (equipped/fed/bagged), and the
acquired-once flag is evaluated before auto-feed destroys the
instance. Scope v1 to instance drops (MODE A): id-based pickups
(MODE B) roll polarity per copy INSIDE the pickup, so there is no
visible curse to detour for until MODE B pre-rolls polarity — which
is the same change the rarity spec's divergence #1 already requires.
Wants: to FIND curses, equipping optional. NEG meets exploration,
Luck, Followers and greed — no combat stat involved.

## Cross-system summary (the ecosystem in one table)

| Build | Wants from a NEG drop |
|---|---|
| Corruption Engine | one of two catastrophic curses; deepen it via merges |
| Doctrine of Burden | one more mild-but-real curse; stabilize via merges |
| Equilibrium Sigil | parity math — polarity is all that matters |
| Inversion Lens | THE most severe curse in the world, to switch off |
| Litany of Wounds | severity to convert while bleeding |
| Gravemarch (set) | these specific pieces cursed, then deepened |
| Gambler's Rite | the finding itself; never needs to equip it |

## Stacking these augments (review finding)

There are exactly 3 augment slots and levels are uncapped. A1+A2+A5
in one build triple-dips a single all-NEG wardrobe. Rules:
- Every NEG-fed augment carries its own hard cap (A1 +30%, A2 capped
  TBD, A4 60% conversion, A5 +25% Haste) — the slots compete on cap
  efficiency instead of multiplying one another without limit.
- Triple-dipping is ALLOWED under those caps: three capped payoffs
  for three slots is a legitimate all-in identity, not an exploit.
- **Shared asymptotic level formula (designer ruling — standardized
  BEFORE the remaining augments are authored):** a capped augment's
  level-scaled quantity is scaled(L) = max_rate x L / (L + S), with
  S = 1 by default — approaches the ceiling, never reaches it, every
  level worth something, no linear-ramp-into-a-wall dead levels.
  Corruption Engine already uses it in code (24% x L/(L+1)).

## Prerequisite content: severity variance must exist

Review finding: across all 22 shipped item defs, authored NEG floors
sit between −0.10 and −0.50, with 17 of 22 at −0.20/−0.25. The
"few brutal vs many mild" axis (A1 vs A2) barely exists in data.
This proposal includes 3–5 deep-curse items — **authored INDIVIDUALLY,
per stat family** (designer ruling: never a blanket −60…−95% band;
−95% movement speed is furniture, −95% max HP is sneeze-death, −95%
of a stat a build lacks is nothing). Severity is normalized to the
stat family, and some should be genuinely build-warping combos —
massive Power with a catastrophic Max-HP curse, superb Haste under an
atrocious movement burden. The acceptance test: an unbuilt character
looks at one and thinks "absolutely not", while an Inversion player
goes "GIVE ME THAT". Corruption Engine's merge-deepening partially
substitutes (curses can be FED deeper), but discovering a natural
−0.80 horror should be possible.

## Rollout order (cheap → expensive)

1. A2, A3 — .tres + the existing recompute polarity loop.
2. A7 — pickup hook + follower/resonance calls + per-segment registry.
3. A5 — HP-ramp conversion in the same stat pass.
4. A4 — slot resolver + the active-severity concept (D2) formalized in
   code (a helper on ItemInstance or the inventory).
5. A6 — set-polarity census + aura effect scene, with the next
   set/content pass.

## Decisions resolved

- D1: NEG merges stabilize by default; Corruption Engine deepens.
  LANDED with tests.
- D2: polarity vs active severity split, table above.
- D3: global normalized-severity floor for Doctrine of Burden,
  starting at 10% of the item's authored NEG range; the HP/Armor
  values and total cap come from playtesting, never from this doc.
- Level scaling: shared asymptotic formula (stacking section). LANDED
  for Corruption Engine.
- A7 Resonance: per-segment cap +4% (ruling above).
- A6: local Gravemarch deepen rule replaces the A1 dependency
  (ruling above).
