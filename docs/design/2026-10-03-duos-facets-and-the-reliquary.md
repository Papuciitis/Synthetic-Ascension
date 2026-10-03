# Duos, Facets and the Reliquary, 2026-10-03

The second pass on the augment layer (the first: `2026-10-03-bindings-and-theses.md`).
The user asked to build what was worth stealing from other games after
the Bindings landed. Seven pieces, each answering a weakness that review
named: thin content for frequent picks (Duos, Facets), Followers needing
more sinks that compete with the tree (Vouchers, Transfusion), the NEG
system wanting reasons to take curses (Burdened Bindings, Corruption's
scars), and catalysts being invisible (the Grimoire).

| Piece | Stolen from | Where it lives |
|---|---|---|
| Duos | Hades duo boons | a DUO card in the Binding |
| Facets | Hades' Daedalus Hammer, Path of Exile support gems | a FACET card in the Binding, then a choice of two |
| Burdened Binding | Slay the Spire's Neow, a Blades in the Dark devil's bargain | a BURDEN button on the Binding |
| Corruption | Path of Exile's Vaal orbs | the Reliquary (Hub) |
| Transfusion | Inscryption's sacrifice altar | the Reliquary (Hub) |
| Vouchers | Balatro | the Reliquary (Hub) |
| Grimoire | Vampire Survivors' collection, the Hades Codex | the Reliquary (Hub), profile-wide |

Numbers and words live in one place each:
`core/systems/augments/AugmentDuos.gd`, `AugmentFacets.gd`,
`AugmentRites.gd` (Corruption, Transfusion, the Burden),
`Vouchers.gd`, `Grimoire.gd`. Global owns the state and the flow.

## 1. Duos

A Duo is a rule two equipped augments unlock together. When both members
are equipped at Lv.3 (Lv.2 with the Concordance voucher) a Binding may deal
a DUO card for it; taking it activates the Duo for the run. A Duo acts
only while both members are equipped. Taking a Duo card adds no levels.

| Duo | Members | Rule |
|---|---|---|
| Lightning Rods | Magic Missile + Tesla Aura | every missile hit arcs to 2 more enemies (170 px) for 60% of its damage |
| Phantom Step | Blink Hex + Spirit Slash | every blink cuts the 3 enemies nearest the landing point with a free Spirit Slash (no cooldown spent) |
| Static Brood | Summon Spiderlings + Tesla Aura | every spiderling bite leaps to one more enemy (150 px) for the full bite and a 0.1 s stun |
| Bulwark Engine | Reflect Shield + Stamina Core | a perfect parry heals 6% of max HP and takes 2 s off Stamina Core's cooldown, at most once a second |
| Slipstream Coil | Sprint Servos + Tesla Aura | while you move, Tesla Aura pulses 50% faster |
| Loaded Dice | Lucky Charm + Gambler's Rite | a lucky crit with an enemy within 600 px recruits a Follower (at most one a second); the Rite's Follower chance +15 points |

## 2. Facets

Each combat augment has two Facets; an equipped one at Lv.3 (Lv.2 with the
Whetstone voucher) with no Facet yet may draw a FACET card, and taking it
asks which of the two. One Facet per augment per run; it stays with the
augment's run state if the augment is swapped out and back.

| Augment | Facet A | Facet B |
|---|---|---|
| Magic Missile | Salvo: +2 missiles a volley, each x0.75 | Lance: half the missiles (at least 1), each x2.2, seek radius x1.5 |
| Tesla Aura | Overcharge: 2 fewer targets (at least 1), zaps x1.7 | Static Field: radius x1.3, zaps stun 0.1 s, x0.85 |
| Spirit Slash | Hemorrhage: bleed per tick x2 and bleed lasts x2, the cut x0.8 | Executioner: x2 against enemies under 30% health |
| Blink Hex | Long Step: range x1.6, cooldown x0.75 | Deep Mark: +1 marked attack, mark damage x1.5 |
| Summon Spiderlings | Swarm: +2 spiderlings a cast, bites x0.7 | Venom Sacs: detonations x1.8, blast radius x1.4 |
| Reflect Shield | Riposte: reflected rounds x1.5 | Long Guard: parry window x1.6, cooldown x1.3 |
| Stamina Core | Second Wind: activating heals 15% of max HP | Iron Lung: cooldown x0.65, duration x0.75 |

## 3. Burdened Binding

From the second Binding on, once per Binding, while the run's bag has a
free place: BURDEN raises every graded card on the table one grade
(Apocryphal stays Apocryphal) and keeps raising them for the rest of that
Binding, so a Recast deals the new table raised too. The price, paid at
once: a random cursed relic (one of the `curse_*` items, NEG) is put into
the bag, and the district hunts you: +20 Threat debt for the segment just
started (the Burden Writ voucher waives the Threat). Doctrine of Burden
and Corruption Engine want the relic; everyone else has to carry or sell
it. (Gambler's Rite does not pay for it: the Rite counts curses picked up
in the world, and the relic is bound, not found.)

## 4. The Reliquary (Hub)

A Hub screen beside Augments, Ascension and Imprints, four tabs.

**Corruption.** Corrupt an equipped augment: free, irreversible, once per
augment per run. Outcomes (Luck moves up to 10 points from Sundered to
Exalted):

| Outcome | Weight | Effect |
|---|---|---|
| Exalted | 45 | +3 levels |
| Scarred | 35 | +2 levels; while it is equipped, Max HP x0.9 |
| Sundered | 20 | -2 levels (never below 1) |

**Transfusion.** Pour an owned, unequipped augment's run levels into an
equipped one: the recipient gains half the donor's level (rounded down,
and never past the Lv.20 cap; only levels it can take are paid for), the
donor returns to Lv.1. Costs 40 Followers per level gained; the donor
needs Lv.2 at least and must not be corrupted. Swap cards leave levelled
augments in the library; this is where they pay out.

**Vouchers.** Two vouchers are offered each Hub visit (seeded, kept in the
save), 250 + 50 x segment Followers each, each once per run:

| Voucher | Effect |
|---|---|
| Fourth Seal Draft | every Binding deals one more card |
| Recast Indulgence | Recasts cost half |
| Gilded Ink | Gilded and rarer Binding cards x1.4 as likely |
| Catalyst Primer | augments Transcend one level sooner (never below Lv.3) |
| Concordance | Duo cards from Lv.2 |
| Whetstone | Facet cards from Lv.2 |
| Burden Writ | a Burdened Binding raises no Threat |
| Tithe Sermon | Abstain pays x1.5 |

**Grimoire.** Profile-wide (it survives death): every Transcendence, Duo,
Facet, Thesis and Canon the profile has ever reached. Undiscovered entries
show their hint (a Transcendence's catalyst, a Duo's pair, a Facet's
augment, a Thesis' family) and hide their name and rule. A Transcend, Duo
or Facet card the profile has never taken is marked NEW on the Binding.

## 5. What review changed

Each part had an adversarial review, then a cross-cutting one with three
lenses (state and save, economy, UI flow) and a skeptic per finding:

- **A free-levels loop (high).** The meta library lets any owned augment
  be equipped in the Hub; a spare corrupted at Lv.1 (where Sundered costs
  nothing) and then drained by Transfusion took a main augment to Lv.18-20
  at the first Hub visit. A corrupted augment can no longer be a donor.
- **Invulnerability chains.** Uncapped levels and Long Guard let Reflect
  Shield's window outlast its cooldown (Lv.6 with the Facet, Lv.8 without);
  Stamina Core's 3 s invulnerability met its old 3 s cooldown floor, and
  Bulwark's refunds drained it faster. Both now keep the cooldown at
  least the invulnerability plus a gap (0.1 s shield, 1.5 s core), and a
  refund never undercuts it. Bulwark Engine is limited to once a second.
- **Burden then Recast** threw the raise away after the price was paid; the
  Burden now covers the whole Binding. With a full bag the relic went to
  the profile stash; BURDEN now needs a free place in the run's bag.
- Riposte boosted the perfect zap as well (it now strengthens only the
  round); Static Field's stun dropped under the aura's pulse floor; Loaded
  Dice needs an enemy near; Transfusion near the cap overcharged; the
  Grimoire learns a loaded run's existing Transcendences and Theses; the
  tooltip no longer names undiscovered Duos.
- UI: the Reliquary scrolls by pad and keyboard (follow-focus, the
  Grimoire's scroll takes focus), its status and focus survive a rebuild,
  and a visit that spends nothing keeps the Exchange's trade undo; the
  Binding's choosers release a card backed out of and disarm Abstain or
  Burden when a card is taken; the Facet card is quicksilver, not a grade's
  green.

## 6. The Binding's deal

Special cards come first and take at most all but one card, so at least
one ordinary card is always dealt: TRANSCEND, then DUO, then FACET (the
first ready of each). A Duo or Facet card carries grade -1 and adds no
level.

## 7. Where it lives

- Rules: `AugmentDuos.gd`, `AugmentFacets.gd`, `AugmentRites.gd`,
  `Vouchers.gd`, `Grimoire.gd` (core/systems/augments).
- State and flow: `autoload/global.gd` (duos, facets, corruptions,
  burden, vouchers, grimoire); save fields in `SaveData.gd`.
- Effects: facets via `set_facet()` from AugmentRunner; Duo hooks in the
  effect scripts ask `Global.augment_duo_active()`.
- UI: `ui/augments/AugmentSelect.gd` and `AugmentCard.gd` (DUO / FACET
  cards, the Facet chooser, BURDEN); `ui/screens/ReliquaryScreen.gd`
  (opened from the Hub's Reliquary button in `ui/screens/HubShop.gd`);
  Run Sheet and augment tooltip lines.
- Tests: `tools/tests/ReliquaryCoreTest`, `FacetDuoEffectsATest`,
  `FacetDuoEffectsBTest`, `BindingRitesUiTest`, `ReliquaryScreenTest`.
- Owed: a rendered look at the Binding's new cards and the Reliquary (no
  rendered Godot ran that day), and the first human run.
