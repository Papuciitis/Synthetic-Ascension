# V4 advancement tree — review and first combat prototype

**Reviewed:** `v4 audit and remake.zip` (Start Here, Full Tree, Tree JSON 350 nodes / 646 edges, Validation, Tree Browser, the V3 Idea Audit) on 2026-09-13, against the current `enemy-world-work` implementation.
**Verdict:** the design can deliver the intended experience, but not as written for its own flagship route, and not at its own fixture numbers. Three of its shared rules and four of its slice nodes need corrections before a combat prototype can tell us anything; after those, the Execution + Barrage + Distortion slice is the right first test.

Throughout, three labels are kept apart:
- **Existing** = what the code does today (cited by file).
- **V4** = what the package proposes (cited by node id or shared rule).
- **Recommendation** = my proposed change, with the smallest correction that keeps the payoff.

The earlier `docs/design/ASCENSION_TREE_SPEC.md` (2026-09-06) is a *different* proposal for the same slot. Where V4 contradicts it (flat prices vs Reach-scaled income, one Q vs slotted actives, wedge composition), this review treats V4 as the authored candidate and flags the disagreement rather than re-arguing it. Presentation is the one thing carried over on request: the radial center-out map stays; V4's browser is a graph inspector, not the in-game tree (§8).

---

## 1. Blocking findings (the prototype cannot answer its question with these in place)

### F1. Executions almost never happen at V4's own fixture numbers, or at the current game's

**Nodes / rule:** EX01 Finish ("execute normals left at or below 10% HP *after damage*"), and everything keyed on an *execution* rather than a kill: EX04 Bloodletting, EX05 Corpse Bomb, EX12 Clean Cut, EXQ7 Five Down, EXE2 Gavel Chain ("each fresh execution"), MM2 Death Debt ("executing a target"), MR2 Kill Feed ("fragment execution").

**Sequence (V4 fixture: D = 10, normals 2D = 20 HP):** native melee hit for 10 → 10 HP left (50%) → above the 10% line → no execution. Second hit for 10 → dead → an ordinary kill, not an execution. For a normal to sit in the execute band after a hit, its HP before the hit must be in (damage, damage + 10% max HP] = (10, 12] HP: a 2-HP window that a 10-damage weapon steps over. Kill Feed is worse: a 0.6D fragment (6) executes at half line (5% = 1 HP), so it only "executes" targets it would have killed anyway.
**Existing:** grunt 10 HP, runner 8, spitter 16 (`core/actors/enemy/EnemySpec_*.tres`) against a 15-damage melee hit (`base_weapon_damage 12 × MELEE_DAMAGE_MULT 1.25`): every normal dies in one hit; no band exists at all.
**Effect on the player:** Finish, Corpse Bomb, Bloodletting, Five Down, Death Debt and Kill Feed's extra fragment are bought and never fire against normals. The discipline's namesake verb is inert; only Spillover and Cleave (keyed on kills) do anything. Two of the three slice Fusions hang on the inert event.
**Smallest correction (revised after review discussion):** define **execution = a normal killed by an execution-enabled hit, whether by damage or by the line**. The permission starts with Finish's Melee Core hits; Chain Sentence extends it to Spillover, Corpse Bomb and Cleave payloads, and Kill Feed extends it to fragments, so those nodes keep their purpose. The *line* stays the thing that turns a non-lethal hit into a kill (so the line still matters for Gavel's doubled line, First Cut's wound, elites under Elite Sentence, and the sinks). Every execution-keyed node then fires on the kills the player is already making, and the line becomes the upgrade it reads as. Second, the enemy fixture must give normals room to be wounded: use 4–6D HP normals in the prototype, or scale the existing roster's HP ×3 behind a prototype flag, because at 1D HP every two-fragment chain is super-critical (F9).

### F2. The flagship route's Barrage third cannot run for a Melee native, so Wildfire never triggers in it

**Nodes / rule:** BR01 Heat ("native Ranged input adds 8, Witness: Shot adds 4 … after 0.35 s without firing, cool 25/s"), BR04 Hot Rounds ("above 50 Heat"), RM5 Wildfire ("Burn kills … Hot Rounds Burn"), BRV SUPPRESSION ("mirror native shots"), BRQ Burst / BRE2 Bullet Hell (only the equipped Q's Evolution operates; the route equips Gavel Chain), Witness rule ("once per fourth native input").

**Sequence (Three-Core avalanche, native Melee):** melee inputs at 0.55 s → Witness: Shot every ~2.2 s → +4 Heat (Witness does grant Heat; the rule is honoured) → cools 25/s in the gap → Heat never reaches 50 → Hot Rounds never explodes → no Burn status exists → Wildfire has no burn kill to roll on. SUPPRESSION's edge guns mirror native shots; a melee native makes none. Burst is unequipped; Bullet Hell is a dead Evolution. Fragmentation fires only on the rare Witness/Ascendant-shot kills.
**Effect:** roughly 13,000 of the route's 71,000 Followers buy Revelation prerequisites, not play, and the package's promised fourth outcome ("Burn deaths roll for more burning fragments") cannot occur in the listed route. The user would build the flagship and see nothing from a third of it.
**Smallest correction:** three changes, all local. (a) Test each discipline on its **own native** and define the avalanche as three native-specific routes (the package already says pure builds isolate problems; make that the plan, §7). (b) For cross-core Heat, put **BRA Hot Blood** (already in V4: melee and magic strikes add 5 Heat) into any route that wants Barrage from a non-Ranged native, and count Witness/Ascendant foreign strikes as "firing" for the cooling clock. (c) Let SUPPRESSION mirror **any Ranged Core strike** (Witness and Ascendant included), not only native shots.

### F3. REWRITE's instant Debt maturity switches off every unpaid-Debt consumer, including the ones the flagship tells you to combine it with

**Nodes / rule:** DTV REWRITE ("new enemy Debt matures immediately"); consumers of *unpaid* Debt: MM2 Death Debt, DTE2 Loaded Coin, DTF2 Pass It On, DT09 Back Pay, RM8 Time Bomb, DTC Payday, DTV3 The Bill ("2% per enemy still carrying V-created Debt"). Route text: "Trigger REWRITE before DECIMATION to make the wipe operate the whole machine."

**Sequence:** cast REWRITE → every Debt deposited from now on matures instantly → cast DECIMATION → 40 executions → Death Debt finds no unpaid Debt → 40 × 0.5D floor pops instead of stored bills; Loaded Coin blasts fall to their 0.5D floor; Pass It On has nothing to pass; Time Bomb collects nothing; The Bill's per-enemy clause reads zero.
**Effect:** the paid combination removes its own payoff; the wipe is visibly weaker with REWRITE up, the opposite of the instruction.
**Smallest correction (revised):** a fixed delay does not save the pairing: the paired cast starts the second Revelation 0.25 s after the first and DECIMATION has a 0.4 s tell, so it lands at 0.65 s, after a 0.5 s window has paid. The rule must be explicit about pending Debt instead: **during REWRITE, a matured bucket is not erased; it stays on the ledger as "paid, collectable" for 1.5 s, and Death Debt, Loaded Coin and Time Bomb may spend it once, Pass It On copying shares first.** The Debt still pays now (the fantasy), the execution still collects it (the pairing), and the doubled value during the V is the intended amplification, to be measured rather than assumed.

### F4. Death Debt's only Melee-native producer is sparse and mistimed until an Axiom the route does not buy

**Nodes / rule:** MM2 Death Debt (requires EX01 + DT06), DT06 Causal Debt ("Magic Core hits save 25%"), DTA Late Payment (Axiom, 2,400 + five Distortion locals: melee hits deposit 12.5%), Witness: Impact (0.6D every fourth input), DTQ Coin Tails ("0.3D Debt per Core strike for 3 s", only while Coin is the equipped Q).

**Correction to an earlier draft of this finding:** Witness: Impact *is* a producer; it is a Magic Core strike and feeds Causal Debt. The problem is delivery: 25% × 0.6D = 0.15D deposited every four swings, on one target, due 2 s later, when the melee player's kills happen on other targets sooner than that.
**Sequence (Death Debt route, 20,600 Followers, native Melee, Gavel Chain equipped):** Execute that target → Death Debt explosion = max(0.15D, 0.5D floor) = a 5-damage pop in 1.5R. The route note admits "functioning but slower"; at these numbers it is the floor every time.
**Effect:** 1,600 (gate) + 400 (DT06) + 1,800 (MM2) = 3,800 Followers for an effect indistinguishable from nothing.
**Smallest correction (revised):** use the existing solution first: **add DTA Late Payment to the Death Debt route** (melee hits deposit 12.5%), so every swing loads the bill the next execution pays. "Executions deposit their overkill as Debt on survivors" is a new mechanic, worth a separate experiment, not a rule change to the Fusion.

### F5. "Critical" is undefined in a system that registers rolls and taxes failures

**Nodes / rule:** DTQ Coin Heads ("critical Core hits deposit 0.5D Debt immediately"), DTK1 Loaded Dice ("every actual failed named combat roll pays 1% maximum HP, at most once per 0.5 s"), DTK2 Snake Eyes ("every non-guaranteed named combat chance becomes exactly 50%"), shared rule "Critical chance uses the existing critical system, not this counter multiplier".
**Existing:** the only critical is Lucky Crit, `LuckResolver.lucky_crit_chance` ≤ 8%, ×1.5 damage, rolled on every attack.

**Sequence, if Lucky Crit is a registered roll:** Snake Eyes → 50% crit on every hit of every core (×1.5 damage, the strongest node in the tree by accident); Loaded Dice → every non-crit hit is a failed roll → 1% max HP per 0.5 s for any build that owns it, a hidden tax on attacking. **If it is not registered:** Heads' Debt clause fires on 8% of hits and is inert.
**Smallest correction (revised):** declare Lucky Crit **unregistered** for the tree's guarantee, reroll and health-tax rules, and **preserve its existing success and failure signals** (`RunEvents.player_lucky_crit(succeeded)`), which Manifestations already consume: Broken Providence banks Misfortune on those failures, so registering it would also double-count into Bad Luck. Coin Heads may still *observe* a real crit ("a critical Core hit deposits 0.5D Debt") without controlling its probability.

### F6. Evolutions arrive at segment 6; the tree promises a developed run at 20 minutes

**Nodes / rule:** Evolution reward rule ("guaranteed opportunities after segments 6 and 9, then every third segment"); the three slice Evolutions EXE2 Gavel Chain, BRE2 Bullet Hell, DTE2 Loaded Coin; economy section ("memorable developed run around 20 minutes").
**Existing:** segments run about 20 minutes; the game already offers augment picks after segments 2 and 7 and Doctrine cards after 3, 6 and 9 (`Global.on_segment_completed`).
**Effect:** at roughly 20 minutes per segment (the roadmap's figure; not independently measured) the first Evolution lands around two hours into a run; the slice's three transformed Qs are unreachable in any single playtest session except through the debug loader.
**Smallest correction:** offer Evolutions on the **existing augment-pick screens after segments 2 and 7** (the screens exist), and additionally at the next cleared encounter after the player's first catastrophe fires. Keep 6 and 9 as the guaranteed floor.

### F7. An automatic Coin can pay health without input

**Nodes / rule:** DTQ Tails ("pays 12% current HP"), automation rules ("Q cost and health risk still apply"; "Coin: ordinary face roll; Counterfeit uses the chosen safe-point default"), flagship loadout ("Loaded Coin Reaction Q on catastrophe").
**Sequence:** Red Mist fires → Reaction Coin flips → Tails → −12% HP at the densest moment, −24% with Two Coins, with 2× recovery.
**Effect:** unavoidable self-damage from a system the player is not touching; deaths read as the build killing you.
**Smallest correction (revised):** automatic and Reaction casts of Coin use a **deliberately selected outcome** (the Counterfeit default face) or a **separately tuned automatic version** (a smaller Tails payment for a smaller Tails bonus). Removing the payment while keeping the full Tails bonus would remove the tradeoff.

### F8. Fusion payloads have no Core tag, so which kill families they can start is undefined

**Nodes / rule:** shared rule "damage-Core tags let a real Ranged fragment kill qualify for Ranged on-kill rules"; MM2's explosion, MR1 Bloodshot, RM5's "burning fragments", DTE2's blast, EXQ3 Public Execution hits, EXC Red Mist sweep carry no tag. (MR3 Corpse Mortar is the model: "counts as a Shell".)
**Sequence:** Death Debt explosion kills three normals → do they Spillover (needs a Melee kill)? Fragment (needs a Ranged kill)? Deposit Debt (needs Magic eligibility)? Unstated; an implementer will pick one and the other two disciplines' players will disagree.
**Smallest correction:** one rule: **a Fusion payload carries the Core tag of the discipline whose effect it performs**, and the tag is printed on the node: Death Debt explosion = Magic; Kill Feed and Wildfire fragments = Ranged; Corpse Mortar = Ranged Shell; Bloodshot = Melee; Public Execution and Red Mist = Melee.

---

## 2. High findings (the experience is worse than intended, not impossible)

### F9. Chains are sub-critical at the fixture and super-critical in the real game; the tree does not say which regime it wants

**Nodes:** BR05 Fragmentation (two 0.6D fragments per Ranged kill), BR10 Pinball, MR2 Kill Feed, RM5 Wildfire, EX03 Spillover (0.5D floor), EX06 Cleave (0.8D).
**Fixture (2D normals):** a fragment (6) never kills a healthy normal; expected kills per seed ≈ 1/(1 − 2 × P(fragment kills)) ≈ 1–2 unless the crowd is already wounded. Buying Fragmentation at 400 Followers shows two sparks that hit and stop.
**Existing (8–16 HP normals, 0.6D of a 12-damage weapon ≈ 7–9):** each fragment nearly one-shots, two fragments per kill → reproduction ≈ 1.8 → one kill clears the screen. That is the fun chaos and also the "alternatives pointless" failure at 400 Followers.
**Recommendation:** treat the reproduction number **R0** as the tuning target and instrument it (kills caused per seed kill): about 0.8 at entry, above 1.2 after three or four purchases (Hot Rounds burn, Pinball, Kill Feed, Loaded Dice). Two levers: enemy HP (the prototype must fix it, F1) and **fragments seek the lowest-HP enemy in range**, which makes the early sparks finish wounded bodies instead of splashing healthy ones. Do not tune fragment damage before the HP fixture is chosen.

### F10. Revelation charge refills too fast for the ordinary machine to matter

**Rule:** 100 charge; a normal kill gives 1 with no rate ceiling; V descendants give none.
**Sequence:** the open horde (60 normals) gives ~60 charge; at 2–4 kills/s a wipe is ready every 30–50 s; DECIMATION empties the screen, spawns refill it, repeat. The chain engine the player built fires between wipes as a curiosity.
**Recommendation:** start at **normal kills 0.5 charge** (or 200 charge) and let telemetry find the cadence where players still want the machine between wipes. Keep the 4/s action-charge ceiling.

### F11. Payday's trigger is out of reach for a single-impact caster

**Nodes:** DTC Payday ("twenty enemy Debt buckets pending on camera"), DT06 (2 s due time), fixture Magic impact R/2 hitting 2–4 enemies at 0.65 s recovery.
**Sequence:** ~5 buckets alive per 2 s window → the catastrophe never starts without Twice + Bad Penny spam; the lone-boss clause (eight matured in 4 s) is closer than the crowd clause.
**Recommendation:** count **buckets deposited in the last 4 s** (or twelve pending). The catastrophe should be the reward for feeding a crowd Debt for a few seconds, not for an area spell the fixture does not have.

### F12. The Witness throttle makes the first foreign purchase feel inert

**Rule:** G1 grants one Witness strike per **fourth** native input (0.6D, P 0.6). Cost to the first Fusion for a Melee native: EX01 free → EX03 400 → EX10 800 → EXQ 800 → G1 1,600 → BR02 200 → BR05 400 → MR2 1,800 ≈ 6,000, reachable around segment 2 at current income.
**Effect:** after 6,000 Followers the player sees one weak foreign strike every ~2 s. The Fusion fires only through that trickle until Ascendant (71,000).
**Recommendation:** Witness every **second** native input until Ascendant (Ascendant already replaces it with one strike per input), and let the Witness Core's counters advance at full weight. The throttle was protecting Heat/Read/Sigil counters; F2 shows it starves them instead.

### F13. Execution has no boss loop

**Nodes:** EX09 Elite Sentence (+1D once per second below 25% boss HP), EXQ Gavel (3D per 7 s), EXV DECIMATION (5D + stagger). Everything else needs a death.
**Sequence (lone boss, 300D):** native melee at ~1.8 D/s plus Gavel → about 160 s of plain hitting with one decision (Gavel timing). Barrage (Overload every 8 s through Backfire) and Distortion (Payday's boss clause, Coin, REWRITE) have loops; Execution does not.
**Recommendation:** Bloodletting stacks also from **Melee hits on a boss below 50%** (each hit is a "cut"), and Gavel on a boss applies a Cracked-style **+15% from your next five hits** (BA09 already defines Cracked). That gives Execution a rhythm on bosses without executing them.

### F14. One equipped Q makes two of three Qs and their Evolutions dead purchases in multi-core routes

**Rule:** "Only the equipped Q's mutations and Evolution operate"; Reaction Q unlocks only at Ascendant. The flagship buys BRQ, BRQ4, BRF2 and Bullet Hell (2,000 + Evolution) and equips Gavel Chain; Burst never fires.
**Recommendation:** move **Reaction Q to G1** (the second Core comes with an automatic Q) instead of Ascendant. The flagship already plays that way; it just cannot until 71,000.

### F15. V4's determinism requirement contradicts the existing enemy scheduler

**Rule:** "fixed seed, same input recording and different rendering budgets produce identical targets, damage, rolls and deaths."
**Existing:** `autoload/EnemySimulationScheduler.gd` moves enemies between full / mid / far simulation tiers by measured physics cost with hysteresis; outcomes already vary with load by design.
**Recommendation:** require determinism of the **tree's own event resolution** (seeded roll registry, ordered queue, stable tie-breaks) and accept scheduler variance; test the tree by replaying recorded *hit events*, not recorded inputs.

### F16. Health payments need their own path or every curse hears them

**Rule:** "health payments bypass armor, cannot generate Force, cannot trigger damage retaliation."
**Existing:** `player.take_damage()` is the only entry and emits `RunEvents.player_damage_taken`, which HitFeel, Tithe Bones (Followers per HP bar), Litany of Wounds, Retaliation Writ and every `on_damage_taken` manifestation hook listen to.
**Recommendation:** add `pay_health(amount, reason)` with its own signal; decide per listener: Litany (HP fraction) naturally reacts, Tithe Bones and retaliation do not. Loaded Dice, Backfire, Coin Tails, Blood Rune, Martyr and The Bill all route through it.

### F17. V4's milestone picks collide with the existing Doctrine cards

**Nodes:** pick.M1–M3, D1–D3, P1–P3 ("segment 3 / 6 / 9 complete").
**Existing:** the Ascension Doctrine offers one card per role (amplify / transfigure / covenant) after exactly those segments, with nine authored resources and three test suites.
**Recommendation:** add V4's nine picks as **extra cards inside the existing offers** (one per role) rather than a parallel menu, and keep the existing rule bag (`attempt_doctrine_rules`) as their storage.

### F18. Resource numbers the tree "claims" from existing systems differ from the code

- **Momentum.** V4: 25 per L travelled, 15 per dash, decay 20/s after 0.75 s still. Existing (`ManifestationState.gd`): a full bar per 704 px travelled (≈ 34 per L), decays 85%/s while still, and has a Stability pole. V4 says to reuse the existing pool; then Afterimage at 60, Trail at 75 and Thousand Cuts at 75+ are tuned against the wrong curve. Re-tune thresholds after the adapter exists.
- **Mark.** V4: shared Mark, one target, then EXK2 wants eight. Existing: a single `marked_handle` consumed by Impact Scripture and Hex Blink. Eight marks need a small multi-mark registry and a precedence rule for who detonates what.
- **Misfortune.** V4 spends five; existing caps at 25 with Broken Providence and the pair rules as consumers. Compatible; note the cap.
- **Burn, homing, projectile consumption.** `BurnDot`, `MagicMissileProjectile` (node-owned homing) and `consume_enemy_projectiles_in_radius` exist. Fragments need homing; the managed projectile simulation is straight-line only, so fragments start as node projectiles with a pooled cap.

### F19. Economy: fixed prices meet flat income; the two proposals on the table disagree

**V4:** prices fixed by type (200 to 20,000), no escalation, "do not alter income to fit prices"; pure route 12–13.6k, first Fusion ≈ 6k, three-core 71k.
**Existing:** gross ≈ 6,000 Followers per segment from segment 2 (flat), ~4,000 on hand by segment 2–3, a 20% reconstruction tax on death, shop items ≈ 100, belief Power capped at 225 Followers (+15% Power for holding).
**Consequence:** a pure route completes around segment 3–4 if nothing else is bought, the first Fusion around segment 2, and Ascendant around segment 12 — outside Area 1. Belief Power still pays for hoarding, weakly.
**Recommendation:** prototype on V4's flat prices through the budget loader (1,200 / 4,000 / 12,000 / 30,000 / 80,000) and decide scaling with income telemetry. This is the open disagreement with the 2026-09-06 spec (Reach-scaled income, peak gates); it does not need settling to run the combat test.

---

## 3. Early purchases: are they enjoyable before the machine exists?

- **Execution:** Spillover (a visible bolt that can kill the next wounded body) and Cleave (a slash from every kill) are fun at 200–400. Finish and Mark are inert at fixture numbers (F1). Recommendation: make **Spillover or Cleave** the free starter, not Finish, until F1 lands.
- **Barrage:** good from the first purchase. Heat's tier bonuses show by the seventh shot; Fifth Shot is a visible extra volley; Crossfire puts a gun at the screen edge; Loose Chamber makes the Jam a payoff. This is the discipline to show first.
- **Distortion:** Twice (a visible 20% echo) and Misfire (shots vanishing) read immediately; Causal Debt is invisible without floating "DEBT 12 · 1.4 s" numbers, and Interest without Pass It On is a health bill the player did not see coming. Recommendation: Debt numbers on enemies from the first purchase, and Coin at two locals (it already is).

## 4. Do branches change how the player fights?

Yes, and the slice trio is well chosen: Execution changes **target selection** (finish the wounded, place Gavel on the weakest cluster), Barrage changes **fire discipline and position** (hold or vent Heat, stand where the edge gun crosses the pack, move through cooling patches), Distortion changes **timing and risk** (flip before the pack, hold shots for Debt to mature, stand in Misfire's radius against shooters). Outside the slice: Momentum draws routes, Bastion rewards holding ground, Precision rewards lines and bounces, Ordnance rewards preparation, Invocation rewards a field, Dominion rewards formations. Two overlaps worth merging are in §6.

## 5. Discoveries beyond the authored Fusions

Unauthored combinations that work once F1 and F8 are fixed:
- Bloodletting + Kill Feed + Five Down: fragment executions raise the line, which makes the next fragments execute; a positive-feedback loop through a crowd.
- Wildfire burn → Residue leaves a scar when the burn expires → Scar Tissue releases it → deposits Debt → Death Debt pays it on the next execution: three disciplines, no recipe.
- Coin Tails (Debt per Core strike) + Gavel Chain: every chain hop pays a bill.
- Hot Rounds burn + Elite Sentence on the durable pair: burn keeps elites in the half-line band.

Combinations killed by tags that the player will expect to work: Cleave kills (Melee) never fragment; Death Debt explosion kills start nothing until F8; Ranged kills never Spillover without the Overkill Axiom (EXA). The Axioms are the real hybrid glue and are priced like Revelation-tier content (2,400 + five locals). Recommendation: **price Axioms at 1,200** so the first cross-family discovery is a mid-run purchase.

## 6. Cuts and merges (specific redundancy, not scope trimming)

- **MO03 Kill Reset and EX12 Clean Cut's generated-execution clause** share one refund bucket and one verb; keep Kill Reset, drop Clean Cut's dash clause.
- **BR03 Heat Sink and BR07 Coolant** are both "cool by moving"; merge into Coolant and keep the patches as its visual.
- **20 sinks** at 1% × √rank change no decision; keep one per discipline in the prototype.
- **Seven Q mutations per Q** (57) with one Q slot: prototype three per Q — the Evolution catalysts plus one.
- **27 Revelation mutations**: none in the prototype; the V must be judged bare first.
- Duplicate names: DO10 and DOQ5 are both **Throw** (rename DOQ5 *Fling*); OR06 and ASC3 are both **Chain Reaction** (rename ASC3 *Twenty Bodies*); MOQ4 **Fork** is also the node type (rename *Split Wave*). The named list to preserve — Gavel, Bloodshot, Mine Runner, Spellshot, Time Bomb, Kill Feed, Death Debt, Wildfire — is untouched.

## 7. Do restrictions suppress the exciting interactions?

Mostly no; the hit-path seal with "a new real death may call each owned on-kill family once" is exactly right — deaths keep chains alive, on-hit loops cannot spin. The three that do suppress: the Witness throttle (F12), the single Q slot (F14), and Hot Rounds exploding only on the first impact of a volley (Burst's twelve rounds explode once). Keep V-descendant zero charge; keep Meat's "Spillover travels once per input"; keep the generation budgets.

## 8. Presentation

Keep the radial center-out map from the 2026-09-06 mock-up (`tools/design/ascension_tree_mockup.html`); V4's browser is a search-and-inspect tool. The V4 graph maps onto it: three 120° Core territories, each split into three 40° discipline wedges; ring 1 entries (EX01/EX02 …), ring 2 locals, ring 3 the Q with its mutation satellites plus forks and Keystones, ring 4 catastrophe and Axiom, ring 5 the Revelation with its mutations and the two Evolutions, sinks at the edge; the 27 Fusions sit on the three Core borders (nine per border, the Union at the border's edge), G1/G2 on the border spokes, Ascendant at the outer top. The JSON's `links` become edges and its `requires` strings ("4 of [...] AND …") need a small expression parser; layout stays computed from (core, discipline, ring, order).

---

## 9. First combat prototype: Execution, Barrage, Distortion

### 9.1 What it must establish

1. A recognizable engine within two purchases on each native, before any Q.
2. A chain the player can read (who died, what it started) with R0 measurable and steerable.
3. Each Q worth pressing for a reason specific to its discipline.
4. One catastrophe per discipline that fires from ordinary play and looks different from the other two.
5. One Fusion per border that is visibly stronger than either parent.
6. A boss loop for all three, and a moving fight where the machine has to follow.
7. A budget path: 1,200 → a Q route that changes combat; 4,000 → a fork or a Gate; 12,000 → a catastrophe or a Fusion.

### 9.2 Scope and catalyst check

| Piece | Nodes | Catalysts | Status |
|---|---|---|---|
| Execution loop | EX01, EX02, EX03, EX04, EX05, EX06, EX10, EXQ + EXQ3, EXF2, EXC Red Mist, EXV DECIMATION | Gavel Chain (EXE2) needs Gavel + Blood + Public Execution + Spillover | all Execution ✔ |
| Barrage loop | BR01, BR02, BR04, BR05, BR08, BR09, BR10, BR11, BRQ + BRQ4, BRF2, BRC Overload, BRV SUPPRESSION | Bullet Hell (BRE2) needs Burst + Backfire + Three Guns + Pinball (= Fragmentation + Ricochet) | all Barrage ✔ |
| Distortion loop | DT01, DT02, DT03, DT06, DT08, DT09, DT10, DT12, DTQ + DTQ6, DTF2, DTC Payday, DTV REWRITE | Loaded Coin (DTE2) needs Coin + Pass It On + Bad Penny + Back Pay | all Distortion ✔ |
| Kill Feed | MR2: EX10 + BR05 + EX01 | Melee↔Ranged gate | ✔ (F1 must land) |
| Death Debt | MM2: EX01 + DT06 | Melee↔Magic gate | ✔ (F4 must land) |
| Wildfire | RM5: BR04 + DT10 | Ranged↔Magic gate; needs Heat ≥ 50, so a **Ranged native** or BRA Hot Blood | ✔ with that caveat (F2) |

No cross-discipline catalyst is borrowed; the slice is self-contained. Ascendant (ASC) is out of the first slice: it needs all three Revelations, two Gates and a Fusion per border, and its foreign-strike-per-input rule changes every counter. Bring it in as phase C once the three natives work.

### 9.3 Mechanics the slice needs, and what exists

- **Shared:** attack root / family / Core tag / hit-path record (new); named roll registry with Luck, Snake Eyes, P and guarantee order (new; `LuckResolver` stays the Luck source); execute/overkill capture (new); per-enemy status registry with expiry (Fading, slow, Prime, Mark ×8, Cracked, Debt buckets, burn) — burn exists (`BurnDot`), the rest new; charge meters and Q/V inputs and HUD (new; the ability HUD contract exists); Gate/Witness strikes (new); health payment path (F16); `pay_health`.
- **Execution:** Spillover bolt, Corpse Bomb, Cleave, Reservoir, Gavel (windup strike at the aim point), Red Mist sweep, DECIMATION (camera-rect gather exists in `EnemyCombatService.gather_*`).
- **Barrage:** Heat pool with tiers/Jam/cooling; Fifth Shot counter; Hot Rounds explosion + burn; homing fragments (node projectiles; the managed simulation is straight-line); Crossfire edge gun (spawn-from-point); Loose Chamber radial volley; Ricochet (on-hit retarget) and Pinball; Bigger Magazine store; Burst; Overload; SUPPRESSION (mirror Ranged Core strikes, F2c).
- **Distortion:** Twice (repeat geometry), Second Chance, Residue + scars, Misfire, Causal Debt ledger (eight buckets per target, merge rule), Interest, Contradiction, Back Pay, Bad Luck (Misfortune exists), Scar Tissue, Compound Interest, Coin, Payday, REWRITE.
- **Shop and map:** the radial mock-up adapted to the V4 JSON (§8) with a budget loader and a route loader for the six routes below.

### 9.4 Routes to load (each on its own native; prices from V4)

| Route | Native | Purchases | Cost |
|---|---|---|---|
| Blood domino | Melee | V4's route (EX01 → … → EXE2) | 12,000 |
| Bullet Hell | Ranged | V4's route | 13,200 |
| Loaded Coin | Magic | V4's route | 13,600 |
| Kill Feed, ranged side | Ranged | Bullet Hell → G1 (melee) → EX01 → EX03 → EX10 → MR2 | ≈ 18,000 |
| Death Debt, melee side | Melee | Blood domino → G1 (magic) → DT01 → DT06 → MM2 → DT02 → DT03 → DT09 → DTA Late Payment | ≈ 20,800 |
| Wildfire, ranged side | Ranged | Bullet Hell → G1 (magic) → DT02 → DT10 → RM5 | ≈ 17,600 |

Each hybrid sits inside the 30,000 budget with room for items. Test each route at four stages: entry (two locals), first Q, first catastrophe, mature (Evolution + V). **Play every mature route with Revelations disabled first**: ordinary fighting has to produce the escalating chaos on its own; the V is then switched on to see whether it amplifies a working build or replaces it. Play the three pure routes on their **own** natives first; the Three-Core avalanche is a phase-C test after Ascendant exists, rebuilt per F2.

### 9.5 Encounters

Use V4's five graybox encounters with the existing roster standing in: open horde (grunts/runners, HP scaled per F1), mixed pressure (spitters as shooters, heralds as elites), moving fight (three groups 4L apart, objective every 8 s), durable pair (two brutes plus fodder), lone boss (the existing boss arena, no adds). Add one more: **wounded horde** — 60 normals pre-damaged to 40–60% by a scripted opening volley — because it is the one encounter that shows execution and fragment chains at their best and tells us whether the player can *create* that state themselves in the open horde.

### 9.6 What to record, and the pass/fail lines

Per route and stage: time to first chain; longest chain in fresh victims; R0 (kills caused per seed kill); ordinary vs triggered damage share; time between manual decisions; time to first V and V cadence; health paid to the build's own costs; death cause and whether the player names it; boss time-to-kill and the number of distinct actions used; frames over budget, kept separate from outcomes.

Pass: with Revelations off, the mature build still clears the open horde through chains; two purchases change where the player aims or moves; the first Q has a discipline-specific reason; the catastrophe fires from ordinary play in the open horde within two minutes; the Fusion route beats both parents on the same encounter; the boss fight has at least two distinct actions per discipline; a player can explain the last chain. Fail: the exciting part needs the Evolution; deaths are unreadable; the correct play is to wait for V; the Fusion is not distinguishable from its parents; one route requires a specific item to function.

### 9.7 Order of work

A. Shared contract, roll registry, status registry, execute/overkill, health payment path, enemy HP fixture, budget/route loader, radial map fed by the V4 JSON.
B. Barrage on a Ranged native (it is the discipline that is fun from purchase one), then Execution with F1, then Distortion with Debt numbers on enemies.
C. Gates, Witness at one-in-two, the three Fusions with F4 and F8, Reaction Q at G1; the three hybrid routes.
D. Ascendant and the rebuilt Three-Core route; Momentum/Precision next.

---

## 10. Summary of corrections requested before implementation

| # | Change | Where |
|---|---|---|
| F1 | execution = a normal killed by an execution-enabled hit (damage or line); Finish grants it, Chain Sentence and Kill Feed extend it; normals need HP room | EX01, EX10, MR2; fixtures |
| F2 | test natives separately; Hot Blood for cross-core Heat; foreign strikes count as firing; SUPPRESSION mirrors any Ranged Core strike | BR01, BRA, BRV, routes |
| F3 | REWRITE keeps matured Debt collectable for 1.5 s; consumers spend it once | DTV, MM2, DTE2, RM8, DTF2 |
| F4 | Late Payment joins the Death Debt route; overkill-as-Debt is a separate experiment | route, DTA |
| F5 | Lucky Crit unregistered but its signals preserved; Heads observes real crits | DTQ, DTK1, DTK2 |
| F6 | Evolutions on the segment 2/7 pick screens and after the first catastrophe | reward rule |
| F7 | automatic Coin uses a chosen face or a separately tuned automatic version | DTQ, automation table |
| F8 | every Fusion payload names its Core tag | all Fusions |
| F9 | fragments seek the lowest-HP enemy; R0 instrumented | BR05, telemetry |
| F10 | normal kills charge 0.5 | charge rule |
| F11 | Payday counts a 4 s deposit window | DTC |
| F12 | Witness one-in-two | G1 |
| F13 | Bloodletting from boss hits below 50%; Gavel cracks bosses | EX04, EXQ |
| F14 | Reaction Q at G1 | G1, ASC |
| F15–F18 | determinism scoped to tree events; `pay_health`; picks join Doctrine offers; Momentum/Mark adapters | integration |
| F19 | flat prices for the prototype; scaling decided by telemetry | economy |

---

## 11. Revisions after the 2026-09-13 discussion

Adopted from the reply to this review: execution as "a normal killed by an execution-enabled hit" with Finish granting and Chain Sentence / Kill Feed extending the permission (F1); an explicit pending-Debt rule for REWRITE because a 0.5 s delay still loses the 0.65 s paired cast (F3); Late Payment as the existing fix for Death Debt's sparse Witness delivery, with overkill-as-Debt demoted to an experiment (F4); Lucky Crit excluded from tree roll rules but its existing signals kept for Manifestations, Coin observing rather than controlling crits (F5); automatic Coin as a chosen face or a separately tuned version, never a free Tails (F7); Reaction Q at G1 kept as a test, not a rule (F14); the two-hour Evolution estimate marked as derived from the roadmap's segment length, not measured (F6). The plan now plays every mature route with Revelations disabled before enabling them (§9.4, §9.6).
