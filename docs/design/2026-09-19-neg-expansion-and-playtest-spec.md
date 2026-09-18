# NEG system expansion and playtest spec, 2026-09-19

Design only; nothing here is coded. Builds on
`docs/design/NEG_BUILDCRAFT_ARCHETYPES.md` (v3, greenlit, 2026-08-23),
`docs/design/NEG_VERTICAL_SLICE.md` (what landed) and
`docs/audits/2026-08-30-neg-manifestation-observability.md` (what the
player cannot see). The bar is `docs/gamegoal.md` section 21: *"Normally
this curse would suck, but this build actively wants it."*

## 1. Where the NEG system stands

| Piece | State | Evidence |
|---|---|---|
| Polarity versus active burden | Landed: `BurdenResolver.resolve` is the one census every archetype reads; a Lens-suppressed item stays NEG for parity and feeds nothing. | `BurdenSystemTest` (13 checks), `LensRetargetFeedbackTest`, `ItemTooltipLensTest` |
| A1 Corruption Engine | Landed: top two statistical curses, `24% x L/(L+1)` Power per 100% severity, +30% cap, NEG merges deepen while owned. | `Augment_CorruptionEngine.tres`, resolver constants |
| A2 Doctrine of Burden | Landed: +16 armour and +9% max HP per qualifying curse (severity at least 10% of the item's own range), asymptotic by level, caps 96 armour / 54% HP. | resolver `doctrine_*` statics |
| A4 Inversion Lens | Landed: worst statistical curse suppressed, 55% of its severity returned as the slot's stat, +30% Luck kicker constant. | `INVERSION_RETURN`, `INVERSION_LUCK_KICKER` |
| A3 Equilibrium Sigil, A5 Litany of Wounds, A6 Gravemarch polarity rule, A7 Gambler's Rite | Designed, unbuilt. No augment, item or effect references them. | `NEG_VERTICAL_SLICE.md` "Not done"; grep of `data/`, `core/`, `effects/` |
| Deep curses | Five relics that only roll NEG (Ashen Ballast armour -95%, Jinxed Coin Luck -95%, Hollow Reliquary Power -80%, Starving Crown HP -60%, Leadfoot Vigil movement -45%) plus three shaped curses with behaviour (Slow Heart: heal-rate cap; Sour Providence: curse-drop bias 0.55; Tithe Bones: 22 Followers per health bar lost). All at drop weight 0.3, about 10% of item picks by weight. | `data/items/**/curse_*.tres`, `effects/items/logic/curses/` |
| Ordinary items | Every set and accessory item can roll NEG (floors -0.10 to -0.50, most at -0.20 / -0.25), at a 50% base positive chance bent by Luck (20-80%) and Sour Providence. NEG items get `NEG_CHANCE_BONUS` toward a Manifestation. | `ItemGenerator.roll_signed_range`, `ManifestationCatalog.slot_chance` |
| Revision 2 interactions | Set channels read the mean rank of *all* six pieces regardless of polarity; prices use `|roll|`, so a -95% relic sells like a +95% item; the simulator wears POS gear only, so no NEG build has ever been measured. | Task 4 / Task 5 code, `BuildSimulator._wear_gear` |
| Observability | Twelve "mistaken for bug" moments and eleven invisible truths ranked in the 08-30 audit; the top ones (Lens slot label, Engine intake identity, zero-curse state, deepen prompt scope) are still open. | that audit, sections 5-6 |

The system today has one argument (Engine versus Doctrine versus Lens)
and three curses with a shape. Seven of the eight curse relics are
numbers; five archetype-facing questions ("do I want this curse?") have
one answer each.

## 2. Expansion

### 2.1 The four unbuilt archetypes, with numbers

All four use the shared asymptotic level rule `scaled(L) = max x L /
(L + 1)` and a hard cap, so three NEG slots compete on cap efficiency
(the stacking rule of the v3 doc).

| Augment | Rule | Numbers (start) | Guards | Reads |
|---|---|---|---|---|
| A3 **Equilibrium Sigil** | While equipped POS count equals NEG count (at least 2 each, all eight slots, polarity not burden): +Power and +Haste. | +12% / +12% at L1 rising to +20% / +20% (`20% x L/(L+1)`); all-or-nothing. | While slotted, pickups never auto-equip (they route to the bag) so parity is curated by hand; a Lens-suppressed curse still counts as NEG. | `BurdenSnapshot.is_balanced()` (exists), `pos_count`, `neg_count`. |
| A5 **Litany of Wounds** | Below 60% HP, total active severity converts to Haste on a ramp that reaches its maximum at 20% HP. | conversion = `ramp x min(cap, 0.25 x total_active_severity)`, `ramp = clamp((0.60 - hp_ratio) / 0.40, 0, 1)`, cap +25% Haste (rising to +35% by level). | Ramp bottoms at 20%; no on-hit window; delivered through the item-effect Haste aggregation, no timer. Suppressed severity counts for nothing. | `snapshot.total_active`, `player.hp / max_hp`. |
| A7 **Gambler's Rite** | Every legitimately new NEG instance the player consumes (equipped, fed or bagged) rolls `15% + up to 20% from Luck` for +1 Follower; the first acquisition of each distinct NEG base item per segment adds +0.5% Resonance, capped at +4% per segment. | as stated (v3 rulings). | Fires when the copy is consumed, evaluated before auto-feed destroys it; per-segment registry of base ids; Followers uncapped, Resonance capped. | `RunEvents.item_generated` / `BalanceItemContext` "bagged" / "equipped" / "merged" events already carry polarity and origin. |
| A6 **Gravemarch polarity rule** | With three or more equipped Gravemarch pieces NEG (slots 0-5), the tier-2 Ballast Frame armour grant becomes a life-drain aura whose radius scales with the combined active severity of those pieces; NEG Gravemarch pieces fed another NEG Gravemarch copy deepen instead of stabilising. | aura: 2% of max HP per second drained from enemies within `120 + 160 x severity_sum / 3` px, healing 30% of it; radius cap 400 px. | Radius or pulse rate only, never raw damage; the deepen rule is local to those pieces; the census is `Inventory.get_set_polarity_composition` over slots 0-5 (exists). | set runner tier hook, `SetScaling` channels untouched. |

Rollout order stays the v3 order: A3, A7 (cheap: data plus one hook
each), A5 (stat pass), A6 (set effect scene).

### 2.2 Shaped curses per stat family (content)

Five of the eight relics are numbers. Each stat family should have one
curse with a *shape* (a rule the archetypes disagree about), matching the
three that exist:

| Curse | Slot | Floor | Shape | Who wants it |
|---|---|---|---|---|
| **Hollow Reliquary** (exists, reshape) | Power | -80% | Your weapon's damage is cut, but every payload *generated by an item or the tree* (sets, Manifestations, Ascension) is unaffected: the curse teaches "your items are the weapon". | Engine (huge severity), tree-heavy builds (payloads dodge it), Lens (the returned Power is enormous). |
| **Leadfoot Vigil** (exists, reshape) | Movement | -45% | While standing still for 0.5 s, gain the lost movement as armour instead (the Bastion Anvil shape): the curse converts a stat you are not using. | Bastion and Dominion builds; Doctrine (mild and real); nobody who kites. |
| **Starving Crown** (exists, reshape) | Max HP | -60% | Healing above 50% HP is blocked; below it, healing is doubled: the curse *is* a low-HP build's floor. | Litany of Wounds (A5), lifesteal styles; a terror for everyone else. |
| **Jinxed Coin** (exists, reshape) | Luck | -95% | Named combat rolls that fail add Misfortune twice (Distortion's Bad Luck reads it); Lucky Crits are impossible. | Distortion's Misfortune spenders; Lens (Luck returned at 55%); Gambler's Rite ignores it. |
| **Ashen Ballast** (exists, reshape) | Armour | -95% | Damage prevention is gone, but every hit taken banks 4 Force / 6 Heat / 10 Momentum for the equipped discipline. | Bastion and Barrage builds that want their meter; Engine; the definition of "absolutely not" for a Precision player. |
| **Cinder Debt** (new) | Haste | -50% | Attack recovery is slower, but each attack's damage is multiplied by the missing Haste share (a -50% roll is +50% damage per hit): fewer, heavier blows. | Execution (execute lines love big hits), Engine; poison for Barrage. |

Every reshape keeps the relic's floor and polarity-only roll; the shape
is an effect scene like the three existing curses. Acceptance: for each
curse, at least two archetypes value it and at least two refuse it, in
the playtest survey below.

### 2.3 Rules the expansion must settle

- **Set channels and polarity.** A NEG Gravemarch piece counts toward
  the set's mean rank like any other; A6 makes that a feature. For
  Lattice and Conduit, a NEG piece still contributes to the set count
  and rank. Keep it: sets are counted by polarity-blind membership, and
  the archetypes are where polarity matters.
- **Prices.** `compute_item_value` uses `|roll|`, so a -95% relic prices
  like a +95% item. A curse is worth less to the market and more to one
  player; price NEG items at 0.6 of the POS price (quality factor `0.9 +
  0.5 x |roll|` becomes `0.9 + 0.3 x |roll|` for NEG). Guard with
  `LootLoopTest` (buyback and merge-sell stay lossy).
- **Merge law.** NEG merges stabilise (`max(best_pct)` toward 0) unless
  the Engine (or A6 locally) deepens. Keep; this is A2's progression.
- **Drop share.** Curses are 10% of picks by weight (eight relics at 0.3
  against sixteen set items at 1.0 plus accessories). After 2.2 adds one
  relic, hold the share at 10% by weighting new relics 0.25.
- **Observability first.** Before any new archetype ships, the four
  cheapest fixes from the 08-30 audit: the slot label reads the
  suppressed state (its #1), the Engine's ledger line names its two
  intake slots (#7), the zero-curse state renders the section for an
  owned archetype (#11), and "Feeding DEEPENS" appears only on the two
  intake curses (#7). Every new archetype adds its own Run Sheet line
  with the arithmetic, in the existing BURDEN block.

## 3. Playtest spec

### 3.1 Questions the playtest answers

1. Does any player keep a curse equipped on purpose without an
   archetype augment? (If yes, the shaped curses work on their own.)
2. With an archetype, how many segments does a NEG build survive
   compared with the player's POS run at the same segment, and where
   do its deaths cluster (collapse phase, like the melee playtest's
   seven)?
3. Do the archetypes disagree in practice: when the same relic drops,
   do Engine, Doctrine and Lens players make different choices?
4. Are the caps reached (Engine +30%, Doctrine 96 / 54%, Lens 60%, A5
   +25%) and at which segment?
5. Which observability fix removed a "bug report" (the 08-30 list)?

### 3.2 Sessions

Three sessions of one run each (target segments 1-8), one archetype
slotted from the first Hub, same race and style across sessions, all
with the recorder's extended capture on:

| Session | Augment | Instruction to the player | Comparison |
|---|---|---|---|
| S1 | Corruption Engine | Feed your worst two curses; never stabilise them. | the 2026-09-18 melee playtest (POS, seg 1-10) |
| S2 | Doctrine of Burden | Equip every real curse you find; stabilise them. | S1 |
| S3 | Inversion Lens | Hunt one apocalyptic curse; refuse the rest. | S1, S2 |

Then, once built: S4 Equilibrium Sigil (parity), S5 Litany of Wounds
(low-HP play), S6 Gambler's Rite (a collector who never equips a curse).

### 3.3 What the recorder must capture (existing fields first)

| Metric | Source | Threshold or reading |
|---|---|---|
| NEG items equipped over time, by slot and severity | `BalanceItemContext` "equipped" / "unequipped" events carry polarity and roll; sample the burden snapshot per segment boundary (new: `burden` event with `entries`, `total_active`, `suppressed_slot`) | S1 should hold 2 deep curses by segment 4; S2 four or more mild; S3 one at -0.6 or deeper |
| Archetype payoff per segment | new `burden` event: Engine Power, Doctrine armour / HP, Lens return, A5 Haste at sample time | caps reached: Engine by segment 6, Doctrine by segment 8, Lens by segment 4 |
| Curses seen, taken, fed, sold | `item_generated` (polarity, source), "bagged", "merged" (`mass`, `swapped`), trade "sold" rows | choice divergence: the same relic id sold in one session and fed in another |
| Deaths by damage source and phase | summary `player_damage_by_source`, incidents' `death_context` (segment phase) | NEG deaths per segment no more than POS + 0.5 for S2, + 1.0 for S1 / S3 |
| Income and reconstruction | `followers_by_reason` | Tithe Bones' `hp_paid` versus income; a Gambler's Rite session's `combat_influence` share |
| Frame cost | summary frame percentiles | no new p99 above the POS run |
| Survey after each session | five questions: which curse did you want, which did you refuse, why, what did you not understand, what looked broken | every shaped curse named as wanted by at least one session and refused by at least one |

### 3.4 Simulator pre-check (before spending a human session)

Add `SIM_GEAR_POLARITY=neg:<count>` to the build simulator (`_wear_gear`
rolls that many statistical pieces NEG at the tier's authored floor) and
`SIM_AUGMENTS=<ids>` (the three archetype augments already resolve
through `Global.permanent_augment_ids`). Run the nine pure presets under
POS, Engine-with-two-relics, Doctrine-with-four-mild and Lens-with-one
apocalyptic at seg6, same seed. The check is coarse (no positioning,
lower-bound ranged/magic set shares) but answers "is any archetype
outright non-viable at its cap" for free, and `BurdenSystemTest` keeps
the arithmetic honest.

### 3.5 Acceptance for the expansion

- Three sessions produce three different wardrobes from the same drop
  tables (question 3), documented with the item ids.
- No archetype session ends before segment 5 (question 2).
- At least four of the six shaped curses are wanted by one session and
  refused by another (survey).
- The 08-30 audit's top four "mistaken for bug" moments do not recur in
  the surveys.

## 4. Out of scope

The Ascension tree's own NEG interactions (curse-reading nodes), the
NEG Manifestation odds (`NEG_CHANCE_BONUS`, untouched), and any change to
the polarity roll's base 50%: the expansion changes what a curse *does*,
not how often one appears.
