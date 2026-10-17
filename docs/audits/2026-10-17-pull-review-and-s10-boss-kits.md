# Pull review and Segment 10 main-boss kits

Date: 2026-10-17. Branch `enemy-world-work`. This round pulled 48 commits (c35ce00..3eca625) from `origin/enemy-world-work` and `origin/feat/authoritative-enemy-world`. Each was reviewed by area, and confirmed defects were fixed in focused commits. Delivery steps 4 and 5 of the [boss overhaul](../design/2026-10-16-boss-overhaul-proposal.md) followed: the three-phase Segment 10 Bulldozer and Arcanist. So did the HUD and entrance parts of step 6. Health, rewards and the seeded 50/50 role choice are unchanged. The S5 teaching kits change only through two review fixes below, the arena speed fix and the second review's rush and mine fixes. A second review of all of this work, three independent verifiers per finding, followed, then a third and a fourth on the fixes themselves; their outcomes are under [Review follow-up](#review-follow-up).

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
| 279e48e, 5e46018, 59b1fb1 | Segment 1, audio, city | Two objective updates per security kill; combat music over the PeeP continuation; developer launches wrote permanent commitments and locked segment-gated purchases. | One update; the menu's music on every route; developer runs write no commitment and claim no Research (what they still keep: Owed, below). |
| 401d0c5, 396933a, 1c56e87 | Augments, ascension | The HUD tooltip lost its run context; non-damage offers promised payload growth; Reflect Shield overstated its parry; a swapped-out Blink Hex kept paying; Momentum's Prime never lapsed. | Each matches its text. |
| f0d5b3d, 90e0b54 | S5 bosses | The rush lane stopped one body radius short of the hit; the cosmetic rush stop wore damaging slam art; a ranged player beyond fan reach could stall the S5 Arcanist forever. | The lane reaches the leading edge; the stop is a small skid; the mage closes in beyond fan reach. |

Performance: mines are found by group and the beam no longer monitors overlaps (adaad68). Cast shadows are written in the proxy publish loops, about 10% faster at 600 proxies and 100 actors, with all 15,360 floats identical; elite batch keys are interned (8bff39e). Dressing materials are shared per atlas region and new RID-backed statics release at exit (8ae9ac6). Status captions, slash draws, bomber rings and projectile accents are cheaper (82d3b86). City multipliers read one rank (e882011). A library page turn draws a few meshes instead of about 44, and 20 turn frames are pixel-identical (556317a).

Tests that described superseded behaviour now measure the game as it is: EnemyProxyRolloutTest takes god mode, because terminal death now routes to PeeP, and HudContextPresentationTest keeps Segment 1's teaching detail (04d55e3). Three suites already failed before the pull: AscensionChainBurstBenchmark counted the pooled death puffs, PrimaryObjectiveTest skipped the rite's approach feed, and WorldTileIntegrationTest expected the sprites the splat map replaced (233f7b5).

## Segment 10 rules shared by both roles

- **Phases.** One health bar. Phase 2 begins at 65% and phase 3 at 30% (`BossPhases`). Phases only advance, so return healing never re-opens one or its once-only arrival. A threshold crossed during an attack waits until it settles, and several thresholds crossed at once make one transition. Each transition is a 0.8 s beat: the boss braces in place, stays damageable and starts nothing, while a phase accent, the intro sound 6 dB down and the boss bar's mark announce it.
- **Tempo.** Cooldown resets scale by 1.0 / 0.9 / 0.8 across the phases. Tells and footprints never shorten. Shared moves keep their S5 tells and footprints, with two Arcanist differences: the Announced Blink's opening is 0.9 s (S5: 1.2 s), and its bolts, sweep and mines scale with the phase (below).
- **Selection.** A seeded weighted order (attempt seed, segment, boss home, pattern counter); the last attack is down-weighted while another is available.
- **Walk-out guard.** `BossEscapeOracle` checks each main-boss attack from where the player stands, before it commits: every Bulldozer attack and the Arcanist's fans, sweeps and Convergence. The Announced Blink carries no hazard, and the mine patterns keep their corridor rule instead (Arcanist, below). The model, as reworked after the reviews:
  - the player keeps its current motion through a 0.15 s reaction, then walks straight in one of the eight directions a keyboard gives, or stands still;
  - at the speed it keeps up (`get_sustained_move_speed`): its stat speed (race, style, flat equipment) under every slow it cannot shed at will, such as a cursed ring, a weapon's burst or an automatic guard, capped at the 100 px/s the tells were tuned for. So a Dragonborn Melee (80 px/s) is never offered a slam it cannot walk out of, and a slow makes the boss wait. Boosts that may lapse neither count nor hide a slow, and a guard held at will does not count, or holding it would pacify the boss;
  - while a dash or a shove carries the player much faster than it walks, nothing is certified; moving into a body it touches, or reaches within the reaction, the player closes to contact (its capsule's radius, plus as much of its length as lies toward the body) and slides along it;
  - the exact 70 × 70 Hurtbox, or the r25/h58 capsule for body contact, turned the way the player turns: facing its motion while reacting, then its walk;
  - the boss's body as an obstacle, cleared by the capsule's crosswise reach (29 px), and the world along both legs of the route (the drift, then the walk): the centre line on loaded, walkable ground, and the capsule's radius less 2 px swept against the walls themselves, so a player resting against a wall can still walk along it or away;
  - for the Arcanist, every bolt it or its pylons still have in the air.

  Circles, rushing bodies and bolts are solved exactly. Sectors and beams are sampled at 1/60 s with a margin for the motion between samples, so a safe verdict is never optimistic. The oracle reproduces the S5 audit's slam threshold: a 1.3 s tell escapes from body contact and 1.15 s does not. An attack with no route is not committed, and if nothing qualifies the controller retries 0.2 s later. It models a straight walk the player can keep up, not analog angles, dashes or swerves.
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

Both arena tiers run the committed controller on the physics clock. The old timer kit now drives only an Arcanist outside both arenas (test and developer spawns), which blinks, drops mines and fires the 0.22 s nine-bolt fan; its boss-tier sweep and pylon branch could never run there and is removed. Main-boss mines fuse on the physics clock.

| Phase | Move | Tell and geometry | Payload and opening |
|---|---|---|---|
| 1+ | Focused Fan | 0.95 s; five drawn lanes over 46°, 320 px/s for 1.625 s | 7 raw × phase factor; 0.9 s recovery; resets 2.6 s |
| 1+ | Announced Blink | 0.8 s; validated 195 px destination | 0.9 s recovery; resets 5.5 s |
| 1–2 | Mine Constellation | 0.6 s; three nodes with a checked escape corridor | 1.4 s fuse, r95, 15 raw × phase factor; resets 4.6 s |
| 2+ | **Split Fan** | 1.1 s; ten lanes every 8° within ±48° of the aim, all drawn, leaving one 32° gap 24° to a seeded side; 300 px/s for 1.75 s | 7 raw × phase factor; 0.9 s recovery; resets 4.2 s |
| 2+ | **Arc Sweep** | 1.1 s showing both the start lane and the end lane; 70° in 1.6 s; 520 × 34 px; rooted channel on the physics clock | 16 raw × phase factor per 0.2 s of contact; 1.0 s recovery; resets 6.5 s |
| 2, 3 | **Pylon Pair** | One pair per phase, 240 px on opposite sides of the player, both in clear, leashed ground | 40 HP each, 14 s life; expires at the next phase change, boss death or reset; never replaced within its phase |
| 3 | **Convergence Sequence** | The Split Fan releases at 1.1 s; the sweep, whose lanes show from the start, begins 1.0 s later | 1.2 s recovery; resets 8.5 s; the whole two-beat plan must keep a walk out |
| 3 | Mine arc | Replaces the constellation: four nodes at ±50° / ±130° around the escape axis, corridor kept | As the constellation |

Phase factors keep the legacy scaling: bolts and sweep × (1 + 0.25 per phase step), mines × (1 + 0.2 per step).

Mine patterns are not oracle-gated: the player's own spot is safe by construction (nodes 210 px out, r95). Each needs a 240 px escape corridor clear of walls and every mine and, when chosen, one that does not close on the boss's body; a corridor may start beside the boss or run along it.

Clear space between patterns: once a pattern has fully resolved (its bolts and mines gone), a neutral beat of 0.8 s × tempo precedes the next. Pylons hold fire through each major pattern's tell and release, through the recovery after it (not a blink's) and while its bolts or mines are in play; a shot already charging when a pattern commits is withheld. They fire in the neutral beats. Pylon bolts still in the air when the next pattern commits are part of its walk-out check, so the route it certifies clears them too.

The oracle sampled 15 positions (120–500 px, 0–30° off the aim). The legacy sweep left a walk out from 2 of them (1 under the first oracle); the rebuilt sweep leaves one from all 15.

## Presentation (part of step 6)

- **Boss bar phase marks.** Gold notches at 65% and 30% on the S10 bar, none on S5. A mark dims once its phase begins and glows briefly as it is passed (no glow with Reduced Motion). They follow `RunEvents.boss_phase_changed`, and another boss's phase is ignored.
- **Entrance.** A role-specific line replaces the shared "capstone guardian" line: "The ground shudders. The Bulldozer braces to charge." and "The air fractures. The Arcanist raises its array." (`BossArena` exports).
- **Staged captures.** `tools/dev/S10BossTelegraphPreview.tscn` builds every new cue through the production brain entry points in the actual Game at segment 10, its terrain, HUD and player included, and freezes each at 60% of its tell. The captures are in [2026-10-17-s10-boss-telegraphs](../art/reference/2026-10-17-s10-boss-telegraphs/). Inspected at both window sizes:
  - the cleave seal's apex and both edges;
  - the breach lane ending in its impact;
  - the six-node Fault Line;
  - the Bulldozer's phase beat;
  - the Split Fan's gap;
  - the sweep's two 34 px lanes;
  - the pylon pair's charge cues;
  - the phase 3 mine arc around the player, in its own panel;
  - the bar marks: one spent at phase 2, both spent at phase 3.

  These are still frames, not playability evidence. The first render ran in the Segment 2 world and missed the phase beat and the mine arc; the review caught both.

## Review follow-up

A second review covered everything above, from the pull to the S10 kits: eight areas (oracle, Bulldozer, Arcanist, HUD and arena, combat caps, tests, docs, and the pull-review fixes themselves). Each finding went to three independent verifiers; 49 were confirmed and 4 refuted. Every confirmed finding is fixed. Each behavioural fix and each test made able to fail was checked against the fault it names: with that fault put back, its suite fails. The [third review](#third-review) found eight of those checks still unable to fail, and a ninth, the dying channel, that its verifiers refuted but that could not fail either; each fails under its fault now. Four fixes have no suite that can see them: the sector seal's shader, the lookup performance change, the removed dead branch and a corrected comment.

| Area | Confirmed | Now |
|---|---|---|
| Oracle | 100 px/s for every race; an upright, unturned body; a player standing still through the reaction; 16 directions, half of which a keyboard cannot hold | The model above: own speed capped at 100 px/s, the turned body, the reaction's drift, eight directions, 29 px crosswise clearance |
| Bulldozer | A committed rush slid along walls, off its drawn lane; a player touching its back was struck as it charged away; the sector seal's shader darkened it by sampling twice; a selection comment promised no repeats | The rush stops where it stands and spares anyone behind its centre line; the seal draws once; the comment says "down-weighted" |
| Arcanist | Pylons fired through a sweep's recovery and from a windup begun before a commitment; a stun left them silenced; their bolts in the air were not in the next pattern's check; a mine corridor could lead into the boss; the boss-tier timer branch could never run | Held through the recovery after a major pattern; a charging shot withheld; a cancelled pattern releases them at once; their bolts join the walk-out check; a corridor into the boss is refused when chosen; the branch is removed |
| Continue | A cleared arena raised its boss again on Continue and paid out again | Clears are saved with the attempt; S10BossContinueTest walks a real kill, save and reload |
| Combat caps | Every hit looked up max health that only capped or plated targets need; the hit-ledger doc still gave the pooled cap | Looked up only when needed; the doc gives the per-hit rule |
| Tests | Twelve checks could not fail as written, one of them in an S5 suite: the Bulldozer's render-time checks, the Split Fan's lanes, the cleave's facing, the oracle's body rule, a dying channel, the pylons' kill credit, the legacy kit, one-sided durations and recoveries, the sweep's end lane, a pylon windup, the phase bar's Reduced Motion. Lookups could abort a case silently, and three items were not checks at all: the mine walk's label, a tally printed early, captures staged in Segment 2 | Each check now fails under the fault it names; the rest are corrected |
| Pull-review fixes | A developer run's Doctrine pick became a commitment on load; noise at a light stick push flipped library leaves; the Transfusion preview ignored the trained floor; the rite test passed on the approach feed alone; the chain benchmark ignored every pooled node; the data reference kept the old shield recast | Each fixed, with a test that fails without it where it is code |
| Docs | Nine overstatements in this audit, the roadmap and the proposal | Corrected here and there |

Refuted: the world corridor's 25 px circle (it already cleared the walk), boss slows stacking on the tuned speed (player slows never reach a boss), the Fault Line refusal's float edge (now decisive anyway, at a Warforged Melee's 90 px/s) and the dash check (kept).

### Third review

A third review covered the second round's 26 commits (9ace5c2..e7850c1), three verifiers per finding: 35 findings, 31 confirmed (2 major), 4 refuted. All are fixed (0a5edfb..f4067d5), and each code or test fix fails its suite with its fault put back.

| Area | Confirmed | Now |
|---|---|---|
| Oracle | Its 29 px world corridor overlapped any wall a player rests against, so every walk was refused and the boss stopped attacking; a dash's 800 px/s was carried 120 px through the boss; the walk ignored equipment speed multipliers | The world corridor narrowed to the capsule's radius less 2 px (which fixed only the physics half: see the [fourth review](#fourth-review)); nothing is certified during a dash, and the drift's own leg is checked against walls too; the walk speed reworked (as corrected in the fourth review) |
| Continue and developer runs | A developer attempt resumed by Continue still claimed Research, wrote its Doctrine as a commitment and paid the Binding echo; a restored S10 clear left the threat director in recon under a HUD reading COLLAPSE; the console's segment jump restored a boss already beaten as cleared | `is_developer_attempt` (session flags or the saved launch) guards all three; the director catches up with the segment before a phase is set (superseded by `begin_segment`, fourth review); a jump forgets that segment's clears |
| Window state | Script runs (`-s`) got the saved state two frames in, over the window they set (two findings); on Windows, a window minimized during the splash was restored | Script runs get it at once; the apply waits while the window is minimized |
| Tests | Eight second-round checks still could not fail: the rush's oblique wall and its stop on contact, the pylon bolts in flight, the mine corridor at the brain, the sweep's end lane (on the axis), the body rule (no crossing), the eight directions (16 passed) and the developer flag's load | Each fails under its fault |
| Arcanist | A sideways mine corridor beside the boss was kept or refused by float32 rounding | A hair either side of zero counts as sideways |
| Opening | Reduced Motion turned on while a still was read left its push-in running; every presentation built the stroke noise (about 17 ms), each hub letter included | The push-in stops; the pattern is made once per run |
| Docs | Ten claims: the stationary controls, routes of 67.5° and 112.5° the 8-direction oracle cannot walk, "permanent speed", "its suite fails" for fixes no suite sees, the proposal's open Continue checks, the count of checks, the boot icon's source, crossfades the opening never shows, a stale verification table, and 03281a4's message | Corrected (f4067d5 and here). Commit messages stay as written: 03281a4 lists the Fault Line refusal among checks that "pass whatever the code does", but the second review had refuted that; it was fragile (a float32 edge at 100 px/s), not unable to fail, and that commit made it decisive anyway |

Refuted: the "away" mine corridor planting the same mines as the "toward" one; a third still mid-crossfade dropping the painted still beneath (fixed anyway in 12eb5f1); the dying-channel check (it could not fail after all: 2c6b726 lets physics see the player before the sweep); and "baseline movement only" contradicting the oracle (reworded anyway).

### Fourth review

A fourth review covered the third round's 11 commits (e7850c1..f4067d5): 23 findings, 21 confirmed (4 major), 2 refuted; 15 distinct once duplicates merge. All are fixed (6aa97c6..7e8023c). Each code or test fix fails its suite with its fault put back, except the display adapter's keep-maximized condition, a real window's state that no headless suite can see.

| Area | Confirmed | Now |
|---|---|---|
| Oracle | The wall fix reached only the physics query: the walk's grid samples covered its whole width, and a wall's blocked 64 px cell reaches 20 px past its face, so within about 43 px of a real wall no oracle-gated attack was certified (the fixture's wall case had no procedural grid and could not see it). Bulwark's held guard (half speed) counted and pacified the Bulldozer at melee range. A passing boost hid a lasting slow (a cursed Crusher's Ring with Overclock walked 94.4 px/s, not 80). A player walking straight in counted as touching 3.4 px early, which could certify a Split Fan from that band | Walks are judged by their centre line on the grid and their body by the physics sweep (`walk_clear`), and the S10 harness rests the production player against a real court wall; the walk's speed is the one the player keeps up (above); a player closes to the contact it reaches, by the way it faces |
| Threat director | A segment rebuilt at the same number (Continue in the same session, the console replaying its own segment) kept the earlier pass's unsealed gate, Overtime and evac (pre-existing); Level1Builder never caught up, so a Segment 1 opened after another profile's later segment fell back to recon | Both builders call `ThreatDirector.begin_segment()` before they build and restore |
| Developer tools | A backward console jump, and the opening restart, left later fights settled; the jump's check never ran the jump; "a developer attempt writes nothing permanent" was false | A jump forgets the clears from its segment on and the restart all of them, through `prepare_segment_jump` and `prepare_opening_restart`, which the suite drives; the contract now says what is guarded (Owed, below) |
| Window state | On Windows a tool's saved windowed state could keep the window maximized, and a maximized window ignores the tool's resize; the minimized-splash wait had no check that could fail | A tool's state never keeps a maximized window; the wait runs behind a seam the suite drives |
| Tests and docs | The stroke pattern's checks could not see an eager or unshared build; this audit's third-review account was missing; the painted-opening audit's check count was stale; native melee was said to land three hits in each recovery | Each fixed |

Refuted: a scene run by its UID counting as a normal start (no tool scene has a UID, and the editor's run modes are classified correctly) and the third-still rule dropping a nearly painted newer still (a path the opening never takes).

## Verification

| Suite | Result |
|---|---|
| BossEscapeOracleTest (new) | 23 passed / 0 failed |
| BossBulldozerMainTest (new): ownership, phases, cleave, breach incl. a wall-stopped rush, follow-up timings, oracle guard, arena speed | 49 / 0 |
| BossArcanistMainTest (new): phases and pylon pairs, hold fire, Split Fan lanes, neutral beat, sweep, Convergence, mine arc, sweep fairness | 46 / 0 |
| BossPhaseBarTest (new) | 15 / 0 |
| BossMainInterruptionTest (new): death, stun, disengage and pause against the S10 cleave, breach tell and beat, Fault Line follow-up, Split Fan, sweep (telegraph and active), Convergence between beats, phase beats and pylons | 38 / 0; 24 / 14 with both cancellation layers removed (scope signal and controller check) |
| EnemyCombatServiceTest (+3 batched-cap and plate checks) | 42 / 0; 40 / 2 before the fix |
| AscensionCityPacingTest (+2 milestone checks) | 626 / 0; 623 / 1 while 26b2bfd hid the line |
| S5 teaching suites: Bulldozer, Arcanist, actual-Game escape matrix | 55 / 0, 44 / 0, 156 / 0 |
| Boss hazard geometry, pylon lifecycle, cast lifecycle, encounter ownership, attack audio, attack identity | 31, 36, 16, 35, 52, 25 / 0 |
| ElitePaletteVisualTest, on a real display | 19 / 0 |
| S10MainBossEscapeTest (new): actual Game, S10 court, production player, two seeds | 185 / 0; 28 paired escape cases and 4 native-melee recovery cases, 107 s |

The full run after `--import` covered 301 scene suites and 26 script suites. All exit 0 with no failure, except five items that behave identically at the pre-pull baseline:
- BuildSimulator and ManifestationPlaytestProbe are long probes that reach the runner's 300 s limit;
- ElitePaletteVisualTest needs a display (above);
- SaveIntegrityTest and SaveSelectUnreadableSlotTest exit 0 but log the parse errors of their deliberately corrupt save fixtures.

Afterwards the player's save slot and settings were byte-identical to a pre-session backup. The suite rewrites four probe reports in the user data root, including the item balance baseline; those were restored from the backup.

### Actual-Game walking controls

`tools/tests/S10MainBossEscapeTest.tscn` builds on the S5 harness. It uses the actual Game at segment 10, the generated S10 court with its real `BossArena`, and the production player with native movement input.

Each case runs in a fresh boss. It arranges the attack's phase and parks the boss's other clocks. It then commits the attack through the same entry point that runs the oracle: `_try_main_attack` or `_try_main_pattern`. The harness rebuilds the oracle's route from the committed plan, with the same hazards, player shapes, body blocker and world corridor. Each case runs twice, with real damage and dash unavailable:
- **Stationary:** the player stands still and must be reached by the attack (except in the mine arc, whose centre is safe by design).
- **Walking:** the player walks the oracle's route (the mine arc: its committed corridor, which is not oracle-gated) after 150 ms at 100 px/s and must draw no boss damage-resolution attempt; the mine walk must also never meet the boss's body.

Seeds 16102026 and 16102027 cover both roles: 7 attacks × 2 seeds, each a stationary control and a walk, 28 results in 14 pairs:

| Attack | Arranged position | Stationary | Route walked |
|---|---|---|---|
| Sweeping Cleave | 15 px beyond body contact | struck once | straight away |
| Breach Sequence | 200 px in the lane | struck by the rush, which stopped short, so its impact was withdrawn | 90° off the lane, a sidestep; the boss arrives and the impact lands clear |
| Fault Line with follow-up | 200 px on the line; the follow-up line was committed | 3 nodes | perpendicular, away from the follow-up side |
| Split Fan | 300 px | 3 bolts | straight away: the 525 px reach expires short of the player |
| Arc Sweep | 300 px | 3 ticks | 135° (toward the boss and to the side) |
| Convergence Sequence | 300 px | 6 hits | straight away, past both reaches |
| Four-node mine arc | 260 px; all four mines and payloads observed | untouched (the centre is safe by design) | the committed corridor |

Native melee recovery cases run once per role and seed. From body contact, the main boss commits a cleave (Bulldozer) or its focused fan (Arcanist). The oracle rightly refuses a Split Fan at contact range, where the Arcanist blinks first in play. Native melee then lands inside each earned recovery (three or four hits in the recorded runs; the suite requires one).

Both seeds produced the same routes, except that the mine corridor differed. With seed 16102027 the corridor first pointed at the Arcanist, and walking it cost 10.9 HP of ordinary body contact. A corridor that closes on the boss's body is now refused when chosen, for S5 and S10 alike, and both seeds' mine walks draw no contact. These are controls at the 100 px/s walk, not exhaustive angles, wall shapes, crowds or slowed builds.

**Wall rests.** Once per role and seed, the production player walks into a straight run of the court's real wall until it touches, and the boss stands 300 px straight out from it. These courts' walls lie at the edge of the boss's disengage radius, where it rightly leaves the fight, so its home moves 600 px out from the wall; the wall's grid cells and colliders stay the real ones. The same attack must leave a walk out in open ground, and the Bulldozer's Fault Line and the Arcanist's focused fan must commit. All four were refused before 6aa97c6.

## Owed

- **Human playtest.** Readability in crowds, the 75–150 s pacing band for ordinary builds, the neutral beat's length, pylon pressure and the cleave's 160 px trigger all need a human run, with mixed S5-to-S10 roles.
- **Not built.** The Split Fan's "later, explicitly indicated rotated follow-up" was not built, because the Convergence Sequence carries phase 3's composition. A damaging debris lane was not built either.
- **Rest of step 6.** Still to do:
  - phase-intensifying music and the defeat/release cue;
  - distinct S10 portraits;
  - the guaranteed reward floor with a durable reward settlement (proposal P0);
  - Continue checks;
  - balance across both choices.
- **Art.** Final S10 forms and phase acting. The Arcanist's small casting accent keeps its render-clock lifetime, as in S5.
- **S5 and slower races.** The S5 teaching tells were validated at 100 px/s, and the S5 kit has no oracle: from body contact, a Dragonborn Melee (80 px/s) cannot walk out of the S5 slam. A tuning question for the playtest; S10 refuses such commitments.
- **Unclaimed loot on Continue.** A cleared arena stays cleared, but loot left on the ground is still lost on Continue; it belongs to the reward settlement above.
- **Developer attempts** (debug builds only) claim no Research, write no city commitment and pay no Binding echo, but keep everything else as any attempt does: Bindings in the profile's permanent slots and owned library (so the next real attempt starts with them), the stash, Grimoire entries, story records, best Followers and the run count. Keeping Bindings out of the profile needs attempt-scoped slots.
- **Mines and blink beside a wall.** While the player rests against a wall, the Arcanist refuses its mine patterns and blink: their corridors are judged across their whole width on the grid from the player's own spot. Its other patterns carry on. Unchanged from the S5 kit.
