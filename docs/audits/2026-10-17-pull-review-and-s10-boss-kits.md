# Pull review and Segment 10 main-boss kits

Date: 2026-10-17. Branch `enemy-world-work`. This round pulled 48 commits (c35ce00..3eca625) from `origin/enemy-world-work` and `origin/feat/authoritative-enemy-world`. Each was reviewed by area, and confirmed defects were fixed in focused commits. Delivery steps 4 and 5 of the [boss overhaul](../design/2026-10-16-boss-overhaul-proposal.md) followed: the three-phase Segment 10 Bulldozer and Arcanist. So did the HUD and entrance parts of step 6. Health, rewards and the seeded 50/50 role choice are unchanged. The S5 teaching kits change only through two review fixes below and the arena speed fix.

## Pull review

Twenty-nine follow-up commits (401d0c5..233f7b5). Where a fix had a reproducible failure, its regression test was confirmed RED first. The pagination freeze and the reading-area height are examples. Performance changes were compared against the previous output and were bit- or pixel-identical where stated.

| Commit | Area | Defect | Now |
|---|---|---|---|
| 6009ff1 | Library | A cut between the two newlines of a paragraph break, followed by a short paragraph, made the short-tail scan spin forever: opening or reflowing that page froze the game. | The scan stops when it cannot move the cut. |
| 32524eb | Pause | A Binding closing during the pause menu's fly-out restored the world under the menu; Resume then restored a pause nothing owned and the game stayed frozen. | The menu adopts the pause. |
| 81eb6e2 | Game | A completion that `finish_segment_completion` refused (developer tools) left the player in a finished segment with the pause menu blocked. | The scene resumes through the saved route. |
| 146d415 | Balance | A terminal death routed to PeeP closed the capture as suspended; every human death looked like a quit. | Recorded as failed. |
| c1b9089 | Saves | Erasing the open chronicle left it in memory; the main menu's Development entry could then rewrite it. | Erasing the current slot forgets it. |
| 8e28ee1 | Augments | A Binding that refused its card fell back to applying the card directly, and the same offer was dealt again: one free grant per refusal. | Only a pick with no Binding applies directly. |
| 964925f, 26b2bfd | Reliquary | Corruption reported the roll, not the level the trained floor kept. A trained donor's refusal named the wrong level. | Both report the real level. |
| 26b2bfd, corrected later | Ascension | A Revelation's "complete segment N" line still read as owed after that segment was complete. 26b2bfd hid the line, but the city-pacing suite deliberately keeps the milestone on record. | The line stays and reads "(met)" once met. |
| d8b2736 | World | Carved district buildings above or left of a lane had no street door and no dug corridor. | Entrances face the street on both sides; the reachability test checks the open ring. |
| 7b32cc4 | Opening | Cards sized their reading area to the typed prefix, so long cards scrolled in a short strip; key prompts ignored rebinding. | Full text shaped first; prompts rebuild on `bindings_changed`. |
| 62519ae, 25f9497, e7f2e92 | Hub, pause | Escape over the shop's Augments/Inventory closed the whole merchant and skipped their save. The library stick kept its repeat delay. Each trackpad nudge zoomed a whole step. The corner Pause entry stayed visible where it could not open. | Each closes or scales as intended; the entry shows only when usable. |
| 279e48e, 5e46018, 59b1fb1 | Segment 1, audio, city | Two objective updates per security kill; combat music over the PeeP continuation; developer launches wrote permanent commitments and locked segment-gated purchases. | One update; the menu's music on every route; developer runs write nothing permanent. |
| 401d0c5, 396933a, 1c56e87 | Augments, ascension | The HUD tooltip lost its run context; non-damage offers promised payload growth; Reflect Shield overstated its parry; a swapped-out Blink Hex kept paying; Momentum's Prime never lapsed. | Each matches its text. |
| f0d5b3d, 90e0b54 | S5 bosses | The rush lane stopped one body radius short of the hit; the cosmetic rush stop wore damaging slam art; a ranged player beyond fan reach could stall the S5 Arcanist forever. | The lane reaches the leading edge; the stop is a small skid; the mage closes in beyond fan reach. |

Performance: mines are found by group and the beam no longer monitors overlaps (adaad68). Cast shadows are written in the proxy publish loops, about 10% faster at 600 proxies and 100 actors, with all 15,360 floats identical; elite batch keys are interned (8bff39e). Dressing materials are shared per atlas region and new RID-backed statics release at exit (8ae9ac6). Status captions, slash draws, bomber rings and projectile accents are cheaper (82d3b86). City multipliers read one rank (e882011). A library page turn draws a few meshes instead of about 44, and 20 turn frames are pixel-identical (556317a).

Tests that described superseded behaviour now measure the game as it is: EnemyProxyRolloutTest takes god mode, because terminal death now routes to PeeP, and HudContextPresentationTest keeps Segment 1's teaching detail (04d55e3). Three suites already failed before the pull: AscensionChainBurstBenchmark counted the pooled death puffs, PrimaryObjectiveTest skipped the rite's approach feed, and WorldTileIntegrationTest expected the sprites the splat map replaced (233f7b5).

## Segment 10 rules shared by both roles

- **Phases.** One health bar. Phase 2 begins at 65% and phase 3 at 30% (`BossPhases`). Phases only advance, so return healing never re-opens one or its once-only arrival. A threshold crossed during an attack waits until it settles, and several thresholds crossed at once make one transition. Each transition is a 0.8 s beat: the boss braces in place, stays damageable and starts nothing, while a phase accent, the intro sound 6 dB down and the boss bar's mark announce it.
- **Tempo.** Cooldown resets scale by 1.0 / 0.9 / 0.8 across the phases. Tells and footprints never shorten; shared moves keep their S5 values.
- **Selection.** A seeded weighted order (attempt seed, segment, boss home, pattern counter); the last attack is down-weighted while another is available.
- **Walk-out guard.** `BossEscapeOracle` checks every main-boss commitment from where the player stands, before it starts. The model:
  - the production walk of 100 px/s after a 0.15 s reaction, in 16 directions or standing still;
  - the exact 70 × 70 Hurtbox, or the r25/h58 capsule for body contact;
  - the boss's body as an obstacle, and the world corridor for each walk.

  Circles, rushing bodies and bolts are solved exactly. Sectors and beams are sampled at 1/60 s with a margin for the motion between samples, so a safe verdict is never optimistic. The oracle reproduces the S5 audit's slam threshold: a 1.3 s tell escapes from body contact and 1.15 s does not. An attack with no route is not committed, and if nothing qualifies the controller retries 0.2 s later. It models baseline movement only: slowed or immobilised builds are not guaranteed an escape.
- **Arena movement.** Both arenas' `speed_mult` (0.95 main, 0.92 S5) never reached movement, because the movement baseline is cached at setup. `EnemyActor.scale_move_speed` now applies it, and temporary buffs and slows still compose on top.
- **Damage caps in batches (proposal P1).** A projectile batch pooled a boss's per-hit cap as `cap × hit count`, so one huge hit could spend the budget of the pellets beside it. Example: with an 800 cap, hits of 5,500 and 55 landed 1,600 together but 855 one by one. `HitLedger` now keeps each hit's raw damage, and `EnemyCombatService` applies the per-hit rules hit by hit: the cap and an ARMOURED elite's plate, which pooled the same way and let a bounced pellet eat into the heavy hit beside it. A batch now lands exactly what its hits land one by one. Batch-level outgoing modifiers scale every hit alike. A bare total with no kept hits keeps the pooled form. The regression failed before the fix (1,600 vs 855; plate 70 vs 80). Whether percentage caps should stay at all is still the proposal's open balance question.

## Bulldozer

Both tiers run on the physics clock, and the legacy `_process` timers are gone, including the main tier's repeating Runner summons every 9 s. Ordinary contact stays suppressed in every committed state and recovery.

| Phase | Move | Tell and geometry | Payload and opening |
|---|---|---|---|
| 1+ | Committed Rush | 0.85 s; 280.8 px along a fixed lane drawn to the body's leading edge | 10 raw × Threat contact multiplier, once; 0.9 s recovery; resets 3.0 s |
| 1+ | Planted Impact | 1.3 s; r135 at the captured origin | 18 raw; 0.9 s recovery; resets 3.2 s |
| 1+ | Fault Line | r85 nodes at 140 / 280 / 420 px, all previewed; impacts 1.35 / 1.67 / 1.99 s | 10 raw per node; 0.9 s recovery; resets 4.6 s |
| 2+ | **Sweeping Cleave** | 1.1 s; 150° frontal sector, r125, chosen within 160 px; masked raster seal with fracture fill and edge strips | 16 raw once per Hurtbox over 0.18 s; 1.0 s recovery; resets 3.8 s |
| 2 | Runner call | Once, when phase 2 begins: the S5 call (1.0 s arrival tell, up to three Runners, consumed for the boss's lifetime) | Finite; unclaimed Runners expire after 15 s without rewards |
| 3 | **Breach Sequence** | 0.95 s rush tell; the r100 impact is shown at the lane's end from the tell's first frame; rush; 0.5 s beat | 18 raw impact; 1.2 s recovery; resets 6.0 s. A rush stopped more than 6 px short of its endpoint withdraws the impact instead of moving it |
| 3 | **Fault Line follow-up** | A second three-node line turned 35° to a seeded side, starting 0.6 s after the third node; all six previewed from the start; impacts 1.35 / 1.67 / 1.99 / 2.59 / 2.91 / 3.23 s | Used only when the six-node plan keeps a walk out, otherwise the plain line |

The main fight opens with rush, slam and Fault Line clocks of 1.2 / 1.0 / 1.8 s. The proposal's "bounded debris-lane variant" remains the existing cosmetic rush trail. No damaging debris was added: the proposal reserves damage for when debris creates a useful decision, which is a playtest question.

## Arcanist

Both arena tiers run the committed controller on the physics clock. The old S10 kit now drives only an Arcanist outside both arenas: the 0.22 s nine-bolt fan, the 110° sweep with a 0.55 s tell, and repeating pylons. Main-boss mines fuse on the physics clock.

| Phase | Move | Tell and geometry | Payload and opening |
|---|---|---|---|
| 1+ | Focused Fan | 0.95 s; five drawn lanes over 46°, 320 px/s for 1.625 s | 7 raw × phase factor; 0.9 s recovery; resets 2.6 s |
| 1+ | Announced Blink | 0.8 s; validated 195 px destination | 0.9 s recovery; resets 5.5 s |
| 1+ | Mine Constellation | 0.6 s; three nodes with a checked escape corridor | 1.4 s fuse, r95, 15 raw × phase factor; resets 4.6 s |
| 2+ | **Split Fan** | 1.1 s; ten lanes every 8° within ±48° of the aim, all drawn, leaving one 32° gap 24° to a seeded side; 300 px/s for 1.75 s | 7 raw × phase factor; 0.9 s recovery; resets 4.2 s |
| 2+ | **Arc Sweep** | 1.1 s showing both the start lane and the end lane; 70° in 1.6 s; 520 × 34 px; rooted channel on the physics clock | 16 raw × phase factor per 0.2 s of contact; 1.0 s recovery; resets 6.5 s |
| 2, 3 | **Pylon Pair** | One pair per phase, 240 px on opposite sides of the player, both in clear, leashed ground | 40 HP each, 14 s life; expires at the next phase change, boss death or reset; never replaced within its phase |
| 3 | **Convergence Sequence** | The Split Fan releases at 1.1 s; the sweep, whose lanes show from the start, begins 1.0 s later | 1.2 s recovery; resets 8.5 s; the whole two-beat plan must keep a walk out |
| 3 | Mine arc | Four nodes at ±50° / ±130° around the escape axis, corridor kept | As the constellation |

Phase factors keep the legacy scaling: bolts and sweep × (1 + 0.25 per phase step), mines × (1 + 0.2 per step).

Clear space between patterns: once a pattern has fully resolved (its bolts and mines gone), a neutral beat of 0.8 s × tempo precedes the next. Pylons hold fire through each major pattern, while its bolts are in flight and through its recovery, and they fire in the neutral beats: one spatial demand at a time.

The oracle sampled 15 positions (120–500 px, 0–30° off the aim). The legacy sweep left a walk out from 1 of them; the rebuilt sweep leaves one from all 15.

## Presentation (part of step 6)

- **Boss bar phase marks.** Gold notches at 65% and 30% on the S10 bar, none on S5. A mark dims once its phase begins and glows briefly as it is passed (no glow with Reduced Motion). They follow `RunEvents.boss_phase_changed`, and another boss's phase is ignored.
- **Entrance.** A role-specific line replaces the shared "capstone guardian" line: "The ground shudders. The Bulldozer braces to charge." and "The air fractures. The Arcanist raises its array." (`BossArena` exports).
- **Staged captures.** `tools/dev/S10BossTelegraphPreview.tscn` builds every new cue through the production brain entry points in the actual Game, real terrain, HUD and player included, and freezes it at 60% of its tell. The captures are in [2026-10-17-s10-boss-telegraphs](../art/reference/2026-10-17-s10-boss-telegraphs/). Inspected at both window sizes:
  - the cleave seal's apex and both edges;
  - the breach lane ending in its impact;
  - the six-node Fault Line;
  - the Split Fan's gap;
  - the sweep's two 34 px lanes;
  - the pylon pair's charge cues;
  - the bar marks: one spent at phase 2, both spent at phase 3.

  These are still frames, not playability evidence.

## Verification

| Suite | Result |
|---|---|
| BossEscapeOracleTest (new) | 23 passed / 0 failed |
| BossBulldozerMainTest (new): ownership, phases, cleave, breach incl. a wall-stopped rush, follow-up timings, oracle guard, arena speed | 49 / 0 |
| BossArcanistMainTest (new): phases and pylon pairs, hold fire, Split Fan lanes, neutral beat, sweep, Convergence, mine arc, sweep fairness | 46 / 0 |
| BossPhaseBarTest (new) | 15 / 0 |
| EnemyCombatServiceTest (+3 batched-cap and plate checks) | 42 / 0; 40 / 2 before the fix |
| AscensionCityPacingTest (+2 milestone checks) | 626 / 0; 623 / 1 while 26b2bfd hid the line |
| S5 teaching suites: Bulldozer, Arcanist, actual-Game escape matrix | 55 / 0, 44 / 0, 156 / 0 |
| Boss hazard geometry, pylon lifecycle, cast lifecycle, encounter ownership, attack audio, attack identity | 31, 36, 16, 35, 52, 25 / 0 |
| ElitePaletteVisualTest, on a real display | 19 / 0 |
| S10MainBossEscapeTest (new): actual Game, S10 court, production player, two seeds | 173 / 0; 28 of 28 paired cases, 96 s |

The full run after `--import` covered 301 scene suites and 26 script suites. All exit 0 with no failure, except five items that behave identically at the pre-pull baseline:
- BuildSimulator and ManifestationPlaytestProbe are long probes that reach the runner's 300 s limit;
- ElitePaletteVisualTest needs a display (above);
- SaveIntegrityTest and SaveSelectUnreadableSlotTest exit 0 but log the parse errors of their deliberately corrupt save fixtures.

Afterwards the player's save slot and settings were byte-identical to a pre-session backup. The suite rewrites four probe reports in the user data root, including the item balance baseline; those were restored from the backup.

### Actual-Game walking controls

`tools/tests/S10MainBossEscapeTest.tscn` builds on the S5 harness. It uses the actual Game at segment 10, the generated S10 court with its real `BossArena`, and the production player with native movement input.

Each case runs in a fresh boss. It arranges the attack's phase and parks the boss's other clocks. It then commits the attack through the same entry point that runs the oracle: `_try_main_attack` or `_try_main_pattern`. The harness rebuilds the oracle's route from the committed plan, with the same hazards, player shapes, body blocker and world corridor. Each case runs twice, with real damage and dash unavailable:
- **Stationary:** the player stands still and must be reached by the attack.
- **Walking:** the player walks the oracle's route after 150 ms at 100 px/s and must draw no boss damage-resolution attempt.

Seeds 16102026 and 16102027 cover both roles, 28 paired results in all:

| Attack | Arranged position | Stationary | Route walked |
|---|---|---|---|
| Sweeping Cleave | 15 px beyond body contact | struck once | straight away |
| Breach Sequence | 200 px in the lane | struck by the rush, which stopped short, so its impact was withdrawn | 67.5° off the lane; the boss arrives and the impact lands clear |
| Fault Line with follow-up | 200 px on the line; the follow-up line was committed | 3 nodes | perpendicular, away from the follow-up side |
| Split Fan | 300 px | 3 bolts | straight away: the 525 px reach expires short of the player |
| Arc Sweep | 300 px | 3 ticks | 112.5° (toward the boss and to the side) |
| Convergence Sequence | 300 px | 6 hits | straight away, past both reaches |
| Four-node mine arc | 260 px; all four mines and payloads observed | untouched (the centre is safe by design) | the committed corridor |

Both seeds produced the same routes, except that the mine corridor differed. With seed 16102027 the corridor pointed at the Arcanist: walking it to the end cost 10.9 HP of ordinary body contact. This is the S5 placement rule, and ordinary contact is a separate cost here as in the S5 audit. These are baseline-movement controls, not exhaustive angles, walls, crowds or slowed builds.

## Owed

- **Human playtest.** Readability in crowds, the 75–150 s pacing band for ordinary builds, the neutral beat's length, pylon pressure and the cleave's 160 px trigger all need a human run, with mixed S5-to-S10 roles.
- **Not built.** The Split Fan's "later, explicitly indicated rotated follow-up" was not built, because the Convergence Sequence carries phase 3's composition. A damaging debris lane was not built either.
- **Recovery hits.** S10 melee during recovery is covered by the S5 recovery controls, which use the same recovery rules, but has no S10-specific native-hit control.
- **Rest of step 6.** Still to do:
  - phase-intensifying music and the defeat/release cue;
  - distinct S10 portraits;
  - the guaranteed reward floor with a durable reward settlement (proposal P0);
  - Continue checks;
  - balance across both choices.
- **Art.** Final S10 forms and phase acting. The Arcanist's small casting accent keeps its render-clock lifetime, as in S5.
