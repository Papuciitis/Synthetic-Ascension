# The seven NEG archetypes against the Ascension tree, 2026-09-19

How each NEG archetype interacts with the nine disciplines, the sets, the
Manifestations, lifesteal, Luck and the economy: what is measured, what
is read from code, and which synergies are fun, nasty or broken. All
seven archetypes exist in code as of commit `feat(neg): build Equilibrium
Sigil, Litany of Wounds, Gambler's Rite and the Gravemarch polarity rule`.

## 1. Method

**Measured.** `docs/audits/2026-09-19-build-simulator/neg-archetypes/report.md`:
the 56 authored builds (37 presets, 16 authored, 3 routes, at their own
tiers) fought once per wardrobe with the same seed and crowd streams,
Gravemarch set pinned so the set is a constant:

| Wardrobe | What changes against the POS baseline |
|---|---|
| `cursed_set` | slots 0-2 NEG at their floors (-0.25 each): the A6 rule alone, no augment |
| `doctrine` | slots 0-3 NEG (-0.25) + Doctrine of Burden (A6 also active) |
| `sigil` | slots 0-3 NEG + Equilibrium Sigil: 4 NEG / 4 POS with the two accessories (A6 also active) |
| `litany` | slots 0-3 NEG + Litany of Wounds (A6 also active) |
| `engine` | Ashen Ballast (armour -95%) and Jinxed Coin (Luck -95%) in slots 1 and 5 + Corruption Engine |
| `lens` | Ashen Ballast in slot 1 + Inversion Lens |

Gambler's Rite has no combat effect and the simulator spawns no pickups,
so it is read from code only. The simulator's caveats apply (no
positioning; ranged and magic set payloads are lower bounds; single
fights can swing wildly on one early cascade).

**Read.** `AscensionRunner.roll`, the engines' `pay_health` sites,
`BarrageEngine.haste_multiplier`, `player._fire_weapon`'s haste chain,
`player.pay_health`, the lifesteal profile, `ManifestationCatalog`,
`BurdenResolver`, `SetRunner`, `GravemarchCursedBallast`.

## 2. What the numbers say

Per-Core medians at seg6, baseline -> wardrobe (enemy HP/s, HP lost,
deaths per fight):

| Wardrobe | Melee | Ranged | Magic |
|---|---|---|---|
| cursed_set | +17%, +29%, 0.09 -> 0.09 | -9%, +5%, 0.14 -> 0.27 | -3%, -11%, 0.42 -> 0.33 |
| doctrine | -10%, -1%, 0.09 -> 0.00 | -18%, -5%, 0.14 -> 0.00 | -8%, -4%, 0.42 -> 0.17 |
| sigil | -4%, +19%, 0.09 -> 0.05 | -14%, +2%, 0.14 -> 0.18 | -6%, -2%, 0.42 -> 0.42 |
| litany | -4%, +37%, 0.09 -> 0.09 | -17%, +1%, 0.14 -> 0.18 | -9%, +3%, 0.42 -> 0.42 |
| engine | -18%, +41%, 0.09 -> 0.05 | -31%, +23%, 0.14 -> 0.23 | -10%, -2%, 0.42 -> 0.50 |
| lens | -35%, -34%, 0.09 -> 0.00 | -34%, -30%, 0.14 -> 0.00 | -21%, -23%, 0.42 -> 0.17 |

### 2.1 A relic costs a set slot, and the set is most of melee's damage

The Engine and Lens wardrobes lost 70% of the output of every set-carried
melee build (Bastion pure 2,587 -> 755 / 726, Momentum pure 2,375 -> 713 /
689, Endless Lunge 2,419 -> 715 / 668), not because of the augment but
because the relics sit in slots 1 and 5 and break the Gravemarch
six-piece: melee's set share fell from 57% to 17%. Every relic is a
statistical-slot item, so "two catastrophic curses" for the Engine means
"at most a four-piece set". The archetypes that curse the set's own
pieces (Doctrine, Sigil, Litany, the cursed set) keep the six-piece and
lose only the rolled stats. This is the single strongest interaction in
the system and it is not written anywhere: the true price of a relic
build is Mass Arrest.

### 2.2 The Doctrine is the free archetype for set builds

Four mild curses on set pieces: output -8 to -18% (the Power piece is
cursed, -25% Power), deaths zero across every Core, armour 41 -> 61, HP
lost flat. Momentum pure -2%, Execution pure 0%. Nothing else keeps a set
build whole while making it safer.

### 2.3 The Lens is the survivability archetype, at a third of the output

Ashen Ballast suppressed returns +52% armour (41 -> 105) and the Luck
kicker; HP lost -30 to -34%, deaths zero. The output loss is the broken
six-piece (2.1), not the Lens: Distortion pure, which does not lean on
the set, reads +2% output and -34% HP lost under it.

### 2.4 The cursed set is a melee engine and an uncapped healer

Three cursed Gravemarch pieces (no augment): melee +17%, Bastion pure
+38% (the aura's drain is credited to the player, so it fills Mass
Arrest's bank and feeds Sunderstep), magic min HP -74% (the armour is
gone). The aura heals 30% of what it drains from every enemy in reach,
and reach is 120-400 px around a 60-body crowd: the drain is 2% of max
HP per second *per enemy*, so healing rose from a median 10 to 46 per
fight, and with a full crowd it is a heal engine with no cap. That is the
one broken number in the set: cap it (section 5).

### 2.5 The Litany and the Sigil do not pay for their curses yet

Both lose 4-17% output and gain nothing measurable in survivability at
seg6, because the scripted player rarely sits below 60% HP for long
(Litany) and because the four curses land on stats the build uses
(Sigil's +12% cannot repay a -25% Power piece). The Sigil's real wardrobe
is curses on the stats a build ignores (Luck and movement for a
stationary Bastion), which no preset wears; the Litany's is deliberate
low-HP play, which the script does not do. Both need the human sessions
of the playtest spec.

### 2.6 Two swings to probe before believing

Distortion pure under the Engine took 11 damage instead of 236, and
Precision pure under the cursed set lost 23 HP instead of 201, with
healing unchanged in both. Nothing in either wardrobe explains a 10x
drop in damage taken; these are single fights and the ablation's noise
floor on HP lost is +/-7-49%. Rerun both on five crowd streams before
citing them.

## 3. Interaction matrix (code read)

Legend: **fun** = the archetype makes the discipline better in a way the
player can feel and steer; **nasty** = a loop or trap the player will hit;
**broken** = a number that needs a change; **dead** = no interaction.

| Archetype | Execution | Momentum / Bastion | Precision / Barrage / Ordnance | Invocation / Distortion / Dominion | Manifestations | Lifesteal and healing | Luck | Sets and economy |
|---|---|---|---|---|---|---|---|---|
| A1 Corruption Engine | **fun**: +30% Power multiplies D(), so Spillover, Corpse Bomb, Gavel and DECIMATION scale; execute lines are HP fractions and ignore Power, so the Engine is pure chain fuel. | **nasty**: the two relics break the six-piece (2.1); Bastion's prevention is per-source and separate from armour, so Ashen Ballast costs only contact mitigation. | Precision's One Bullet (3D) and Barrage's rounds scale with Power; Ordnance Shells too. Jinxed Coin's -95% Luck costs the tree nothing (see Luck). | Distortion: Debt is 25% of actual damage, so +30% Power is +30% Debt; the Engine and Loaded Dice stack. | NEG-heavy wardrobes roll more Manifestations (+8% per NEG slot); Broken Providence and Orbiting Testament die under Jinxed Coin (Luck <= 0 means 0% Lucky Crit). | dead | **dead by design**: `AscensionRunner.roll` reads only the engines' modifiers, never `Global.run_luck`; Luck only touches Lucky Crit (cap 8%), evasion, drops, Follower chance, prices, wager odds and Manifestation odds. | Relics sell like +95% items (price uses the absolute roll); the Engine's merge-deepening turns every duplicate curse into fuel. |
| A2 Doctrine of Burden | neutral: keeps the set; Execution pure 0%. | **fun**: the safe set build (2.2); Bastion's Force needs hits taken, Doctrine's armour reduces them, mild tension. | Precision -2%, Barrage -6%, Ordnance -24% (its Power piece). | Dominion -16%, Invocation -13%: casters pay the Power curse hardest. | Four curses = four extra Manifestation chances; Martyr Circuit and Scar Tissue both like a durable frame. | Scar Tissue refuses 55% of heals for armour: with the Doctrine's armour that is redundant. | Mild curses on the Luck slot cost Lucky Crits; the Doctrine does not care. | The stabilising merge law *is* the Doctrine's progression; the 10% floor kills near-zero curses. |
| A3 Equilibrium Sigil | neutral | Sigil + Bastion: curse Luck and movement (unused by a stationary Anvil build) for +12% Power/Haste on a whole six-piece: the one preset-shaped fun case, unmeasured. | Barrage's Haste and the Sigil's Haste stack additively in the stat pass; Heat per shot is constant, so more shots jam sooner. | Distortion +2% (already balanced-friendly). | All-or-nothing parity with eight slots: a Manifestation-carrying POS accessory can break parity, which the pickup gate exists to protect. | dead | Curse the Luck slot: the cheapest NEG for parity, at the price of Lucky Crits. | Pickups never auto-equip while slotted: with Gambler's Rite this is exactly what a collector wants. |
| A4 Inversion Lens | Execution pure -10% (six-piece broken by the relic). | **nasty for set builds** (2.1), **fun for Distortion** (+2% output, -34% HP lost). | Precision -8%, Barrage -26%: the six-piece again; a Lens on a Barrage-owned Luck curse would be free. | Dominion -29%. | Lens on Jinxed Coin: +52% Luck returned plus the kicker (+14% at L1) puts Lucky Crit at its 8% cap, which ignites Broken Providence and Orbiting Testament: **fun**. | dead | The only archetype that turns Luck *up*. | A suppressed curse still counts as NEG for A3 parity and A6's census: Lens + cursed Gravemarch is legal and the aura reads active severity, so the suppressed piece adds no radius. |
| A5 Litany of Wounds | Red Mist and Corpse Bombs do not read HP; Litany is Haste only. | **nasty loop**: Bastion Martyr (`BAQ5`) pays 2% max HP per second at zero Force and `pay_health` floors at 1 HP, so a guarding Bastion can sit at 1 HP with the full ramp forever; Momentum's No Brakes overflow (5% max HP) feeds the ramp too. | **nasty loop**: Barrage's `haste_multiplier` (tier rate, x2 in Burst) and the Litany's multiply in `_fire_weapon`; Heat per shot is constant, so faster shots jam sooner, Backfire pays 5% HP, which deepens the ramp. Overclock (no Jam) breaks the loop. | **nasty**: Distortion's Undo and Debt bills use `pay_health_lethal` (1% max HP per unpaid bucket, 12% for Undo): the one cost that can kill a Litany player who hovers at 20%. Invocation's Blood Rune (3% HP per placement) is a gentler ramp feeder. | Martyr Circuit (wounded = faster, near death = echoes) stacks with the Litany on the same trigger; Fever Litany and Third Litany add Haste on top: there is **no cap on the total haste multiplier** in `_fire_weapon` (`cd / max(haste_mul, 0.05)`), so Fever x Burst x Litany x Conduit Overclock can pass 4x fire rate. | Lifesteal (melee 2% of damage, capped per second) pushes HP back above 60%, so the Litany self-limits for melee; Slow Heart (heal-rate cap) keeps a Litany player low: a curse the Litany *wants*. Starving Crown's proposed reshape (double healing below 50%) fights it. | dead | A6 heal (2.4) fights it. |
| A6 Gravemarch polarity rule | Execution pure +4%: aura drain credits the player and feeds Mass Arrest's bank: **fun**. | Bastion pure +38%, Momentum 0%: **fun** for the stationary set build. | Precision +9%, Barrage 0%, Ordnance +1%: the aura is a melee tool. | Dominion -13%, Invocation +1%: casters lose the armour and gain a drain they do not need. | Scar Tissue turns the aura's healing into armour: a legitimate loop, bounded by the heal cap once it exists. | **broken**: healing scales with the crowd (2.4). | dead | Deepening without the Engine: feeding NEG Gravemarch duplicates now progresses the aura; every other set's NEG merge still stabilises. |
| A7 Gambler's Rite | dead | dead | dead | dead | Tithe Furnace burns a Follower every eighth attack: the Rite's income against the Furnace's spend is a legible trade. | dead | Luck adds up to 20 points to the Follower chance; Jinxed Coin lowers it, Lens raises it. | **fun**: Sour Providence (curse-drop bias 0.55) makes most drops NEG, so the Rite pays on nearly every pickup; the Resonance cap (+4% per segment) keeps that from moving the Exit Rite. Curses still sell at +95% prices (loot pass L-price proposal). |

## 4. The three findings that matter

1. **The set is the hidden cost of every relic build.** Two relics cost
   the six-piece, and the six-piece is 57% of melee damage in this
   scenario. Either relics need a home outside the six statistical slots,
   or the design accepts that the Engine and the Lens are four-piece
   archetypes and says so on the card.
2. **Healing scales with the crowd in the cursed set.** Cap it.
3. **Luck is invisible to the tree.** Every Luck curse and every Luck
   return is free or worthless for Distortion, Precision's Read, Barrage's
   Heat and every named roll; only Lucky Crit, evasion, drops and money
   see it. A small Luck term in `AscensionRunner.roll` would make the
   Jinxed Coin a real cost and the Lens's kicker a real gift.

## 5. Proposals

| # | Proposal | Why | Confirm |
|---|---|---|---|
| T1 | `GravemarchCursedBallast`: cap healing at 4% of max HP per second (`heal_share` applies up to the cap) and cap the drained damage per tick at 8 enemies' worth. | 2.4: uncapped heal engine with a crowd. | `NegArchetypesTest`: 60-enemy pulse heals no more than the cap; set probe rerun with `cursed_set`. |
| T2 | Either (a) two accessory relics (offhand and ring, -95% Luck-style) that the Engine may burn, so a relic build keeps the six-piece, or (b) the Engine's and the Lens's cards say "your two relic slots replace two set pieces". | 2.1. Decision for the designer; (a) contradicts the v3 "statistical slots only" ruling, (b) is honest and cheap. | Rerun the `engine` and `lens` wardrobes with accessory relics; melee output within 15% of the baseline. |
| T3 | `AscensionRunner.roll`: add `LuckResolver.effective(Global.run_luck) x 0.05` before the cap, so Luck moves named rolls by at most 5 points either way. | Finding 3. | `AscensionSharedRulesTest`: a -95% Luck wardrobe fails 5 points more often; Distortion pure under Jinxed Coin loses output. |
| T4 | A global cap on the shot haste multiplier in `_fire_weapon` (x2.5), applied after every runner multiplies in. | Fever Litany x Burst x Litany x Overclock has no ceiling. | Test: stacked multipliers clamp; Barrage pure output with all four unchanged below the cap. |
| T5 | Litany: while `pay_health` would leave the player at 1 HP, the ramp reads HP as 20% (no extra) and Martyr's upkeep counts as damage for the melee regen block. | The 1-HP Martyr parking lot is safe only because `pay_health` floors; no change to the Haste, only to the safety. | `NegArchetypesTest`: ramp at 1 HP equals ramp at 20% (already true) plus a Bastion Martyr probe. |
| T6 | Card text: Corruption Engine and Inversion Lens name the six-piece cost; Litany names the Barrage and Martyr loops as intended. | Observability before tuning (08-30 audit rule). | Text checks in `BurdenSystemTest`. |
| T7 | Rerun 2.6's two swings on five crowd streams before any conclusion about Distortion + Engine or Precision + cursed set. | Single-fight chaos. | Five-stream probe. |

## 6. Not covered

Gambler's Rite in play (needs pickups and a human), the Litany and the
Sigil under deliberate play (needs sessions S4-S5 of the playtest spec),
the shaped-curse reshapes of the expansion spec (unbuilt), and every
interaction with Fusions and Unions (unreachable in the simulator, see
the tree audit F1).
