# Segment 1 complete design pass (2026-09-19)

What Segment 1 is today, read from the code, held against the vertical
slice's first three windows (`2026-09-19-vertical-slice-definition.md`
section 6) and the roadmap's three hits. Findings carry the numbers behind
them; proposals are design, not code, except where a line says a change
is code-ready and names its test. The story pass of 2026-08-23
(`SEGMENT1_STORY_PASS.md`) landed the ten beats; this pass asks whether
the beats do the slice's job.

## 1. Segment 1 as built

Segment 1 is handcrafted end to end. `game.gd` turns chunk generation off
at segment 1 and `Level1Builder` builds five regions of 64 px cells
(admissions 24x15, facility 42x35, courtyard 37x19, service 35x30,
approach 43x25) joined by three seals that open in order. None of the
procedural stack runs: no theme, no district plan, no primary objective
catalog, no miniboss or boss. Encounter beats can run (the director is
set up for every segment and gates on the mirrored threat phase), the
Cursed Vault cannot (the proc builder places it).

| Layer | Segment 1 today | Source |
|---|---|---|
| Opening | Full prologue on a fresh profile (HISTORICAL card, admissions walk with two beats, dialogue with three responses, three alignment stages, calibration, construct fight, officer arrest with 7 s patience, aftermath at 0.35 time scale, separation card); one alignment repeat and one card afterwards; skippable | `OpeningSequenceController.gd`, `global.gd` 2037-2043 |
| Route | admissions (start cell 9,43; veterans 15,25) to lab to archive to courtyard to service district to approach and gate plaza; wardstones at the archive and before the checkpoint; the Rite at (20,-50), hidden while locked | `Level1Builder.gd` 8-13, 117-121, 993-1000 |
| Objective ladder | synthesis, escape, courtyard, service, security (5 kills), wardstone 2, checkpoint, gate, rite | `Level1Builder.gd` 1354-1376 |
| Secondaries | three service rooms (loading office, warehouse with a four-enemy interior, maintenance kiosk): one item each, +0.02 resonance | `Level1Builder.gd` 339-390, 1246-1261 |
| Resonance | 0.93 from milestones, 0.002 per kill, 0.008 per elite, 0.0015 x rarity per pickup, 0.00025 per s; the final plaza tops the bar to 1.0 | `Level1Builder.gd` 29-43, 1136-1143 |
| Pressure | milestone-driven stages: off, then 4.6 s / 4 alive (Grunt), 3.8 / 6 (+Runner), 3.25 / 8 (+Orbiter), 2.8 / 11 (+Spitter, Charger), 2.15 / 15 (+Bomber, threat allowed), 1.35 / 20 at the Rite; elites only from the approach; threat phase mirrors the stage | `Segment1SpawnProfile.gd`, `spawner.gd` 510-521 |
| Heat | tutorial curve 0.30 at 0%, 0.85 at 60%, 0.35 at 90%, 1.00 at 100% of the segment | `ThreatDirector.gd` 37-41 |
| Followers | 0 until the assistant commits (kill income returns 0 before that), the assistant beat grants 1, kills pay 1-4, no payout for clearing | `global.gd` 423-424, 2044; `EnemyLifecycle.gd` 88-113; `game.gd` 357-365 |
| Reconstruction | max(10 x 1.7^deaths, 20% of the balance); survivable only above the cost | `global.gd` 2222-2243 |
| Build choice | the augment pick at the evidence store, fresh profiles only; veterans get a flavour tip; Doctrine picks start after segment 3; the tree is Hub-only | `Level1Builder.gd` 1228-1244; `global.gd` 2124-2135 |
| Items | drops rarity 0-1 with the segment term at 0 and drop chance 0.20 to 1.00 with resonance; ten caches at rarity 3-5; secondary rooms rarity 3-6; NEG polarity 50% from the first item | `EnemyDrops.gd` 176-242; `Level1Builder.gd` 477-535; `ItemGenerator.gd` 57-66 |
| Rite | hold 20 s, lapse 0.45/s after 1.5 s grace, 60% kept through death, three automatic pulses plus one safeguard per wardstone, narrative mode changes the tip text only; locked until resonance 0.999 and the plaza; LOCKED / LOCATED / READY checklist | `ExitRite.gd` 10-118, 755; `Level1Builder.gd` 1630-1692 |
| Hub | "SEGMENT 1 CLEARED", ten vendor slots at R1-R4, refresh 3 x 1.75^n, Augments / Ascension / Inventory / Continue; no pick scheduled by completing segment 1 | `HubShop.gd` 389, 1415-1458, 1662-1732; `global.gd` 2076-2122 |

No capture of a human segment 1 exists: the four balance captures on
disk are lab baselines at segment 5, half a minute each. Every timing
statement below is therefore a reading of the code, not a measurement.

## 2. Findings

**F1. Veterans get no build decision in segment 1.** The only choice is
the evidence-store augment pick, and it pends only on a profile with zero
augments. From the second attempt on, the 3-6 minute window has items
(caches, rooms) but no decision the player makes on purpose: the first
Doctrine pick is three segments away and the tree is behind the Hub. The
slice asks for "POS versus NEG, first Manifestation, first merge, vendor or
risky pickup" in that window.

**F2. A curse can arrive before anything wants it.** Polarity is 50% NEG
from the first drop, and no NEG archetype is in play unless the fresh
profile picked one. A rarity 3-5 cache item with a -30% curse in minute
four is loot the player learns to sell, which is the outcome
`gamegoal.md` section 21 forbids.

**F3. Followers are near zero for the first two regions.** Kill income is
suppressed until the assistant beat (courtyard), and the beat grants one
Follower. The economy audit puts segment 1 income around 1,400, almost all
of it from the service district onward. The first Hub then sells ten
R1-R4 items whose prices are far below the wallet, so the slice's A10
("one purchase weighed") has nothing to weigh at the first Hub.

**F4. Secondaries pay resonance that does not matter.** Milestones give
0.93, the three rooms 0.06, and arriving at the final plaza tops the bar
to 1.0 regardless. The rooms' real reward is one item each; the announced
+0.02 is cosmetic. Kills and pickups feed the same bar with the same
result.

**F5. Punctuation is authored twice, then absent.** The security clear
(a three-enemy wave over 2.25 s) and the warehouse interior (four
enemies) are the segment's two authored encounters. After the courtyard
the threat phase is "disturbance", so the encounter director may place a
charger wedge, a shield wall or a crossfire from the segment 1 roster,
but nothing guarantees one before the approach, and the segment 1 roster
has no Sniper, Brute, Leech, Summoner or Herald, so the "hunter" and
"summoner nest" beats cannot appear. Whether a beat fires in a 6-9 minute
segment at 60-90 s intervals from a 45 s first delay is a coin flip that
no capture has recorded.

**F6. The heat valley before the plaza is deliberate and unmeasured.**
Heat 0.85 at 60% then 0.35 at 90% is the authored breather before the
Rite's 1.0. The story pass filed "heat-valley ownership" as a tuning
decision; the recorder's pressure section can now show whether the valley
reads as relief or as a lull.

**F7. The Rite at segment 1 is the mechanics without the answer.** Hold,
lapse, pulses and safeguards are all there and the stage runs 1.35 s / 20
alive with threat allowed. The world's answer (rite specialists) exists in
the director for every segment, but Overtime and its reward decay begin
only when the gate unseals, which at segment 1 is the plaza window. The
climax is short by construction; whether it is a climax is question A5.

**F8. Timing is unknown.** The full opening alone is a dozen cards and
three dialogue choices before the first enemy; the slice budgets the whole
segment at 6-9 minutes. Nothing records when each beat is reached. As of
this pass the balance recorder logs every objective title change, every
secondary completion and every Rite checklist transition with the
gameplay clock, so one human run answers this without a stopwatch.

**F9. The parts that work as designed.** Exploration beats combat for loot
(caches R3-5 against drops R0-1): the vision's "exploration-driven" holds
at segment 1. The wardstone loop (2 s capture, restore, pulse, stability
field, one Rite safeguard each) teaches the Rite's safeguards before the
Rite. Reconstruction is cheap and death keeps 60% of the hold. Kill income
withheld until the assistant makes the "followers first" card land on the
first Follower rather than the fortieth.

## 3. Proposals

Ordered by what the slice's first three windows need. Type: D = design
decision, T = tuning, C = code (with the test that would pin it).

| # | Proposal | Type | Why | Size |
|---|---|---|---|---|
| S1 | **Done** (a veteran profile gets one instrument rolled blessed and deeply cursed as two "take one" pickups, `ItemPickup.choice_group`; re-offered after a quit; `ChoicePickupTest`). The evidence store always offers a choice: the augment pick on a fresh profile, otherwise two items rolled from one seed as a POS / NEG pair of the same base (one blessed, one cursed at the deep end), take one. | C: `Level1Builder._begin_evidence_choice`, a two-item variant of the pickup offer; `Level1StoryTest` pins that a veteran profile is offered exactly one of two | F1, F2: the 3-6 window's decision exists for every profile, and the first curse arrives as a choice, not a drop | medium |
| S2 | **Done** (`AugmentSelect.ensure_neg_archetype`; `AugmentOfferTest`). First-run Doctrine preview: when the fresh profile's pick fires, the offer contains at least one NEG archetype (Engine, Doctrine or Lens) and the card says what a curse does for it. | T: the pick's candidate filter | F2 | small |
| S3 | **Done** (15 / 25 / 20 through `secondary_objective`; the resonance stays as a small feed). Secondaries pay Followers, not resonance: 15 / 25 / 20 for the office, warehouse and kiosk; drop the +0.02. | C: `Level1Builder._on_secondary_completed`; `Level1StoryTest` pins the payout and that the Rite still unlocks | F3, F4: the first Hub gets something to weigh and the rooms' reward is honest | small |
| S4 | Clearing segment 1 pays a purse (60 Followers) at the Rite, announced on the completion card. | D then C: `game.complete_segment` | F3; also the only place the run says "believers came" | small |
| S5 | **Done** (`charger_wedge_small` after the security clear, `sniper_pair` at the checkpoint; `SegmentOneBeatsTest`). Guarantee one beat: after the security clear, request a charger wedge (three chargers on the service street) through the director; at the checkpoint, a spitter crossfire on the approach. | C: `Level1Builder` calls `EncounterDirector.try_spawn_beat`; `EncounterBeatsTest` covers the segment 1 roster variants | F5: the 6-9 window's "stop autopiloting" moment is authored, not rolled | small |
| S6 | **Done**. Add the Sniper to the approach stage's roster (interval 2.15 s / 15 alive unchanged). | T: `Segment1SpawnProfile` | F5: the one enemy that changes movement before segment 2's crossfires | trivial |
| S7 | Resonance top-up: keep the top-up (a stuck bar at 0.99 is worse), but stop displaying kill and pickup resonance in segment 1; the bar moves on beats. | D | F4 | trivial |
| S8 | Heat valley: measure first. One human run with the recorder's pressure section decides whether 0.35 at 90% stays. | D | F6 | none |
| S9 | Rite answer at segment 1: let Overtime start at the final checkpoint instead of the unseal, so the last 60-90 s carry decay and specialists. | T: `Level1Builder` at `final_checkpoint` | F7 | small |
| S10 | **Done, then widened** (`HubShop.vendor_slot_count`: 8 / 10 / 12 after play feedback that the shop felt limited). First-Hub vendor: six slots at segment 1 instead of ten, prices unchanged. | D | F3: fewer, weighed purchases; the loot pass's soft cap does not reach the vendor | trivial |
| S11 | Short opening for veterans starts with the "ward flicker" beat instead of the apparatus so the tone lands in under a minute. | D | F8 | small |

S1, S3, S5 and S9 change what the player does; they wait for the first
recorded human run (F8) so the change is measured against a baseline,
not against a reading of the code.

## 4. Human eyes, with what to record

From the story pass, still open, now with the measure each needs:

- Opening walk pacing: the gameplay clock at `objective` "synthesis" and
  at the first kill, from `events.jsonl`.
- Reveal camera: the sentence at the 6-9 window; nothing in the capture
  can judge it.
- Evidence-offer timing under pressure: the `objective` clock at "service"
  against the `spawn` records around it (extended recorder).
- Phase-mirror difficulty lift: the pressure samples across the
  disturbance, ascension and collapse phases (`phase` records) and the
  HP lost per minute per phase.
- The Rite: `gate_checklist` LOCKED to LOCATED to READY clocks, the `exit`
  records (hold, progress, lapses), deaths at the Rite.

## 5. What this pass did not do

No gameplay code changed. The recorder extension (objective, secondary
and checklist events) is the only code, kept separate from tuning as the
standing rule asks. The Cursed Vault stays a segment 2 event: segment 1
has no reward chunk to host it and its "fuck it" moment belongs to the
12-15 window, which is segment 2's.
