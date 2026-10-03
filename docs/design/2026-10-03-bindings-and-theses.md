# Bindings and Theses: augments and Doctrines above the tree, 2026-10-03

The user's brief: with the Ascension tree in the game, augments and the
choice moments (augment picks, Doctrines) feel weak beside it. Make them
more impactful than the tree, borrowing from RPGs, tabletop games and
horde survivors.

## 1. Why they were weak (read from code, 2026-10-03)

| | Augments | Doctrines | Tree |
|---|---|---|---|
| How often | 3 picks a run at most (fresh profile, after seg 2, after seg 7); veterans get 2 | 3 a run (after 3, 6, 9) | about one purchase or more every segment |
| Variety | uniform shuffle, no rarity; with full slots the offer is your own three augments | one card per role per stage: every run sees the same 9 cards | 350 nodes |
| Damage unit | `12 × k × (1 + Power)`: no style multiplier, no gear, dice terms add +2 at P 0.2 | n/a | D = your native hit (style × Power), everything a multiple of it |
| Scale at seg 6 | Magic Missile about 10 DPS at L1, about 32 at L5 | ±15-35% stat trades | 4.5-7.5k HP/s for the strong disciplines |
| Ceiling | level clamps at 5 (effects and the Doctrine level grant) | `force_augment_identity` does nothing in combat | Revelations, Fusions, Unions |
| After seg 9 | nothing | nothing | Evolution claims only |

Also found: an in-session restart (death, then Restart) kept the previous
attempt's Doctrine history, stat delta, augment levels and mutations.
With the old run's taken ids still present, the next seg-3 offer came
back empty and the Hub's departure stayed blocked. Fixed (section 7).

## 2. The shape we want

The tree is **bought**: steady, chosen node by node, priced in Followers.
Bindings and Doctrines are **given**: they are the run's spikes. Each
should be worth more than what the tree sells in the same segment:

- a Binding (augment pick) should outweigh that segment's purchase;
- a Transcendence should sit with an Evolution or a Revelation;
- a Doctrine should outweigh any single node, because the strongest ones
  multiply the tree (Q recovery, Revelation charge, native hit count,
  node prices) instead of competing with it.

Borrowed, and from where:

| Idea | From | Here |
|---|---|---|
| a choice after every stage | Vampire Survivors / Hades level-ups and boons | a Binding after every segment |
| rarity on offers | Hades boon rarity, D&D item rarity | Grades: Etched, Gilded, Sanctified, Apocryphal |
| max level + catalyst → evolution | Vampire Survivors evolutions | Transcendence at Lv.5 with a catalyst |
| reroll / skip for currency | Brotato, VS reroll and skip | Recast (pay Followers), Abstain (gain Followers) |
| full slots still offer something new | Hades (always new boons) | Swap card |
| dice damage | tabletop | dice expressions kept, now on D |
| pact with a price | Warlock patrons, Slay the Spire boss relics | Doctrines keep gift / price / consequence |
| set bonus for a path | Hades duo boons, D&D subclass features | Thesis (2 of a family), Canon (3) |
| more boons after the 3rd tier | D&D epic boons | Apocrypha stages after seg 9, every 3 segments |

Constraints kept from `docs/gamegoal.md` §27-28: no new slot system (still
three augment slots), no XP, rule changes over stat bumps, asymptotic
growth where a stat caps.

## 3. Bindings (the augment pick)

**Cadence.** A Binding is pending after every completed segment (was 2
and 7). It still shows when the next segment starts. The fresh-profile
intro pick and its NEG-archetype guarantee are unchanged.

**Cards.** Three cards; four with the Circuit Thesis or Open Circuit.
Each card is one of:

| Kind | When | Effect |
|---|---|---|
| NEW | a slot is free | binds an augment you do not have equipped |
| RANK UP | it is equipped | adds the grade's levels |
| SWAP | all slots full (one per offer) | binds a new augment over a slot you choose; the old one keeps its run level in the library |
| TRANSCEND | an equipped augment is Lv.5+ and its catalyst holds | transforms it (one per offer, always first) and adds a level |

**Grades.** Every card except TRANSCEND rolls a grade:

| Grade | Levels | Weight at completed segment s |
|---|---|---|
| Etched | +1 | 100 |
| Gilded | +2 | 30 + 6s |
| Sanctified | +3 | 6 + 3s |
| Apocryphal | +4 | 0.5 + max(0, s - 3) |

Weights above Etched are multiplied by `1 + 4 × LuckResolver.augment_quality_bonus(luck)`
(the helper existed and was never called: ×0.52-×1.48), by the
`binding_grade_mul` Doctrine rule (Black Archive ×1.6, Archive Thesis
×1.5). At seg 2 that is 65 / 27 / 8 / 0.3%; at seg 9 about 45 / 38 / 15 / 3%.

A NEW or SWAP augment enters at `stored level + grade − 1` (a Gilded new
augment is Lv.2). A RANK UP adds the grade's levels.

**Recast and Abstain.** From the second Binding on:

- Recast redraws the offer for `40 × s × (n + 1)` Followers (n = recasts
  this Binding); the Archive Thesis and Pilgrim Engine give one free.
- Abstain takes `75 × s` Followers instead of a card (Liturgy of
  Overclock's price sets it to 0; the Archive Canon doubles it).

Both compete with the tree for the same Followers, which is the point.
The offer and the recast count persist in the save, so reloading cannot
reroll for free.

## 4. Augment potency: the tree's unit

`core/systems/augments/AugmentScaling.gd` owns the numbers. Every combat
augment now pays in D, exactly as the tree does (`AscensionRunner.native_damage`):
`base_weapon_damage × style multiplier × (1 + Power)`, times the
augment-damage Doctrine multipliers.

- potency(L) = 1 + 0.35 (L − 1): Lv.5 = 2.4, Lv.10 = 4.15. Damage is not
  a capped stat, so this is linear on purpose.
- Levels cap at 20 (was 5). Counts (missiles, targets, spiders, dice)
  grow with min(L − 1, 8), cooldowns keep their floors.

| Augment | Lv.1 payload (× potency) | Other growth |
|---|---|---|
| Magic Missile | 0.45 D per missile, 2 per volley | +1 missile / 2 levels |
| Tesla Aura | 0.5 D per zap, 4 targets, tick 0.55 s ÷ Haste (new) | +1 target / 2 levels |
| Spirit Slash | 2.4 D × (3d6 ÷ 10.5), bleed 6% of the hit per stack per tick | +1 die / 2 levels |
| Blink Hex | +3 D × (2d8 ÷ 9) on each marked attack | +1 marked attack / 2 levels |
| Spiderlings | bite 0.5 D, detonation 1.4 D; at most 6 + levels alive (cap 14) | +1 spider / 2 levels |
| Reflect Shield | perfect zap max(0.35 × reflected, 1.2 D) | +targets |

Measured with `tools/tests/AugmentPowerProbe.tscn` (`--fixed-fps 60`, ten
seconds against 40 immortal dummies within 260 px, actives cast the moment
they are ready, D = 12): total damage over the crowd, in D per second.

| Augment | Lv.1 | Lv.5 | Lv.10 | Transcended Lv.5 | Transcended Lv.10 |
|---|---|---|---|---|---|
| Magic Missile / Choir of Needles | 1.1 | 5.2 | 14.6 | 13.0 | 34.5 |
| Tesla Aura / Storm Crown | 3.6 | 15.8 | 44.8 | 34.6 | 98.1 |
| Spirit Slash / Thousand Cuts | 2.6 | 10.3 | 24.2 | 24.6 | 74.9 |
| Summon Spiderlings / Brood Mother (no kills in the probe) | 2.0 | 7.9 | 15.8 | 7.1 | 20.1 |
| Blink Hex marks (analytic) | 0.5 | 5.0 | 20.2 | 6.7 + rifts | 24.3 + rifts |

The native weapon is about 4.5 D/s on one target (ranged), 3.3 D/s per
enemy in its arc (melee), 2.5 D/s per enemy in its blast (magic). So one
augment is a fraction of the weapon at Lv.1, one to three weapons at Lv.5
and several at Lv.10, and a Transcendence doubles or triples that. Two
numbers were tuned on the first probe: the Thousand Cuts d4 refund now
applies to pressed casts only (113 -> 75 D/s at Lv.10, it had compounded
with self-casting), and Blink Hex (1.8 -> 3 D) and Spiderlings (0.35 ->
0.5 D bite) rose because they were well behind the rest.

## 5. Transcendence

An equipped augment at Lv.5 (Lv.4 with Liturgy of Overclock or Perfected
Engine) whose catalyst holds offers a TRANSCEND card. Any one catalyst
is enough; the Circuit Canon and The Engine Prays waive them.

| Augment | Transcends into | Catalyst (any one) | New rule |
|---|---|---|---|
| Magic Missile | Choir of Needles | Lucky Charm; Haste ≥ +40%; a Precision or Invocation node | +1 missile; every hit splits into 2 shards (60%) that seek other enemies |
| Tesla Aura | Storm Crown | Sprint Servos; move speed ≥ 180; a Momentum or Distortion node | radius ×1.3; each zap chains 2 hops (×0.7, 170 px) and stuns 0.12 s; elites and bosses take double |
| Spirit Slash | Thousand Cuts | Litany of Wounds; Blink Hex; an Execution node | casts itself when ready; strikes the 3 nearest (+1 per 4 levels); a kill re-casts at once (3 chains) |
| Blink Hex | Hexgate | Sprint Servos; Spirit Slash; a Momentum or Dominion node | each blink tears rifts at both ends: 2.5 D in 120 px, 0.6 s stun; +1 marked attack |
| Summon Spiderlings | Brood Mother | Cult of Personality; Gambler's Rite; an Invocation or Dominion node | 30% of kills near you hatch a spiderling; spiders detonate when their life ends |
| Reflect Shield | Mirror Aegis | Stamina Core; Armor ≥ 40; a Bastion node | a ward opens itself every 1.6 s; reflections fan into 3; the perfect zap hits everything in range |
| Stamina Core | Undying Engine | Doctrine of Burden; Reflect Shield; a Bastion or Execution node | 6% lifesteal always; fires itself below 35% HP when ready |
| Lucky Charm | Fortune's Engine | Gambler's Rite; Cult of Personality; a Distortion node | lucky crit chance ×2, lucky crits ×2.5 (were ×1.5) |
| Sprint Servos | Velocity Engine | Tesla Aura; Blink Hex; a Momentum node | Power + 0.3 × (move speed ÷ 100 − 1), at most +60% |
| Corruption Engine | Heart of Ruin | Litany of Wounds; two curses worn; a vessel Doctrine | the three heaviest curses feed it; cap 30% → 75% |
| Doctrine of Burden | Martyr's Frame | Stamina Core; four curses worn; a Bastion node | +5% Power per qualifying curse (at most +40%) |
| Inversion Lens | Twin Lens | Lucky Charm; Equilibrium Sigil; an archive Doctrine | the suppressed curse returns 110% (was 55%); Luck kicker ×2 |
| Equilibrium Sigil | Perfect Balance | Inversion Lens; Lucky Charm; a Distortion node | Power and Haste cap 20% → 45%, rate ×2 |
| Litany of Wounds | Requiem | Corruption Engine; Spirit Slash; an Execution node | starts at 85% HP (full at 35%), cap 35% → 70%, also adds Power |
| Cult of Personality | Prophet | Summon Spiderlings; Gambler's Rite; 300 Followers held | recruit chance ×2 and +2 per recruit; belief Power cap 15% → 30% |
| Gambler's Rite | House Edge | Lucky Charm; Cult of Personality; a Distortion node | chance cap 35% → 70%, +2 Followers per NEG pickup |

A Transcended augment keeps levelling. Its name replaces the augment's
name on every surface (`Global.augment_display_name`).

## 6. Doctrines (Theses)

**Bigger gifts on the existing nine.** Open Circuit: cooldowns ×0.6 and
a fourth Binding card. Black Archive: Binding grades ×1.6. Choir of
Recurrence: augment damage +25% (levels no longer clamp at 5). Vessel
Without Mercy: +30% Max HP. Pilgrim Engine: one free Recast per Binding.
Perfected Engine: its no-op consequence became real: augments Transcend
at Lv.4.

**Nine new cards**, one more per role per stage, so each stage shows
three of six:

| Stage | Role / family | Card | Gift | Price |
|---|---|---|---|---|
| Method | amplify / circuit | Twin Seal Protocol | highest-level augment +3 levels; augment damage +25% | Recast costs double |
| Method | transfigure / vessel | Second Hand | the native attack lands as several full hits: Twin Cut 2 × 0.85, Scatter 3 × 0.75, Tri-Sigil 0.85 + 2 × 0.75; every part is a hit for every tree rule | Haste −10% |
| Method | covenant / archive | Census of Souls | belief Power cap 15% → 40%; kills +8% chance of one more Follower | reconstruction costs ×1.5 |
| Doctrine | amplify / circuit | Liturgy of Overclock | +1 level to every equipped augment; Transcend at Lv.4 with no catalyst | Abstain pays nothing |
| Doctrine | transfigure / vessel | Iron Liturgy | Q recovery ×0.6; every Q cast grants 6 Revelation charge | Max HP −20% |
| Doctrine | covenant / archive | Tithe Ledger | every Ascension node costs 25% less | tree refunds return nothing |
| Apotheosis | amplify / circuit | The Engine Prays | every equipped augment Transcends now; augment damage +50% | native weapon damage −25% |
| Apotheosis | transfigure / vessel | Second Revelation | Revelation charge ×3 | Max HP −25% |
| Apotheosis | covenant / archive | Mass Conversion | each elite kill: +40 Followers and +1 level to a random equipped augment (once per 20 s) | Threat ×1.25 |

**Offer.** Per role, a weighted draw (weight = base score + 1 per
matching build tag) replaces "highest score always wins", so the same
build sees different plates run to run.

**Thesis and Canon.** Holding two Doctrines of one family grants its
Thesis, three its Canon:

| Family | Thesis (2) | Canon (3) |
|---|---|---|
| circuit | +1 Binding card; augment damage +20% | every catalyst holds; augment damage +50% |
| vessel | +15% Power | every Max HP price moves halfway back to 1; +25% Power |
| archive | Binding grades ×1.5; one free Recast per Binding | every Binding card is Gilded or better; Abstain pays double |

Plates show the family count on one line ("CIRCUIT · 1 HELD · THESIS
NEXT"); focusing a plate puts what it would awaken on the screen's status
line ("SEAL READY · INSCRIBING THIS AWAKENS THE CIRCUIT THESIS: ...") and
in its hover text. A plate is a fixed 340 x 540 face, so
`ChoiceCopyFitTest` measures every plate and badge headlessly.

**Apocrypha.** After seg 9 the Doctrine continues every three segments
(12, 15, ...): one plate per role, drawn from every untaken card of any
stage.

## 7. Fixes on the way

- `start_new_attempt` and `on_attempt_failed_die_die` now clear the
  Doctrine history, offer ids, stat delta, augment levels, mutations and
  the new Binding/Transcendence state.
- `MCE_UpgradeEquippedAugments` no longer clamps to 5 (it pulled a Lv.7
  augment down to 5).
- Perfected Engine's consequence (`force_augment_identity`) only printed
  a Run Sheet line; it now also lowers the Transcendence level to 4.
- `build_stage_offer` returned an empty offer when any one role had no
  candidate; it now leaves that role out, and a stage with no plate left
  at all is never queued (`doctrine_stage_has_plates`), so a long run's
  Apocrypha cannot open an empty screen that blocks the Hub.
- Black Archive's Threat price multiplied instead of overwriting, so it
  stacks with Mass Conversion.
- The two kill paths (node and proxy) shared a copy-pasted Cult of
  Personality roll; both call `Global.bonus_kill_followers` now.

## 8. What is measured and what is not

Headless tests pin the rules and the arithmetic (section 9) and the
probe measures the augment output (section 4). Nothing is tuned from
play. A rendered pass could not be taken on 2026-10-03 (every rendered
Godot launch crashed at start-up with signal 11 on that session's
display, the existing ScreensShotProbe included);
`tools/dev/BindingShotProbe.tscn` renders the Binding and the plates
when a display works. The first rendered run should watch (a) whether
three Lv.5+ augments trivialise segs 6-9 against the Threat scaling,
(b) whether Abstain is ever taken, (c) Brood Mother and Choir of
Needles node counts on the UHD 620 budget, (d) whether Thousand Cuts
and Storm Crown at Lv.10 need the potency curve lowered
(`AugmentScaling.POTENCY_PER_LEVEL`).

## 9. Where it lives

- `core/systems/augments/AugmentScaling.gd`: D, potency, grades, costs,
  catalysts, Transcendence table.
- `core/systems/augments/AugmentBinding.gd`: offer construction and
  resolution (pure, seeded).
- `autoload/global.gd`: Binding state, Transcendence state, Doctrine
  families, Apocrypha stages, resets.
- Effects: `effects/augments/logic/*` (combat), `player.gd` stat pass and
  `BurdenResolver` (passives).
- Doctrines: `data/major_choices/doctrines/*.tres`.
- UI: `ui/augments/AugmentSelect.gd`, `AugmentCard.gd`,
  `ui/screens/MajorChoiceCard.gd`.
- Tests: `tools/tests/AugmentBindingTest`, `AugmentPotencyTest`,
  `AugmentTranscendenceTest`, `DoctrineThesisTest`, `AttemptResetTest`,
  `ChoiceCopyFitTest`; updated `AugmentOfferTest`,
  `AscensionDoctrineTest`, `AscensionDoctrineGameplayTest`,
  `EnemyHandleTargetingTest`.
- Probes: `tools/tests/AugmentPowerProbe` (output table, headless with
  `--fixed-fps 60`), `tools/dev/BindingShotProbe` (screenshots, needs a
  display).
