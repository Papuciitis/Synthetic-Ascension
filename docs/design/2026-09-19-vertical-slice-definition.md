# Vertical slice definition (2026-09-19)

What one attempt has to prove before anything new is built, stated so a
playtest can pass or fail it. This closes item 10 of the September 19
list. It draws on the roadmap's three hits (section 6.1), the authored
20-minute run (section 7), the success criteria (section 25), the
game-goal playtest questions (`gamegoal.md` section 52), and today's
audits for what is measured and what is still missing.

## 1. The slice in one sentence

One attempt, about 25 minutes: the authored Segment 1 (institution to
city, ten beats), the Hub, one procedural district segment (Segment 2)
ending in an Exit Rite the world resists, the Hub again. Three starting
styles, one build direction chosen by minute 10, one story worth telling
at the end.

It proves the three hits in order: killing feels good within seconds; the
run has a visible identity by minute 5-10; something worth retelling
happens by minute 20. It does not prove content volume, endless scaling,
or segments 3 and beyond. Those exist procedurally and are outside the
slice's promise.

## 2. What is in the slice today (code inventory)

| Layer | In the build | Notes |
|---|---|---|
| Segment 1 | `Level1Builder`, ten beats landed 2026-08-23 (`docs/design/SEGMENT1_STORY_PASS.md`), Exit Rite checklist UI | opening walk pacing, reveal camera, evidence-offer timing and the phase-mirror lift still need human eyes |
| Segment 2 | `SegmentProcBuilder` + `DistrictPlan` (main route, secondary paths, exploration branches, urban envelope), themes, wardstones, landmarks | the route reproduction in `RoamStreamProbe` walks it |
| Primary objectives | 3: district relay, ward vigil, breach seal (`PrimaryObjectiveCatalog`) | one per segment, seeded |
| Secondary objectives | 3: dangerous alley cache, searchable reward building, wager shrine | the wager stake floor now shares the reconstruction survival rule |
| Deliberate risk | Cursed Vault (guaranteed Manifestation, a hunter and a wedge as the answer, heal lock), Ritual Interference | the section 7 "fuck it" beat exists |
| Encounter beats | 9 in `EncounterBeats` (charger wedge, shield wall, sniper crossfire, summoner nest, hunter, bomber carpet, leech ring, the Rite's sniper crossfire), scheduled by `EncounterDirector` from 45 s, every 60-90 s, phase-gated | roadmap Phase 2.4 asked for 5-8: met on paper, unplayed as a rhythm |
| Exit Rite | hold 20 s, lapse drain, distortion from 50%, last-chance vault at 85%, specialist response every 7 s, backlash | the climax mechanics exist; whether it reads as a climax is a playtest question |
| Enemies | 10 kinds and 2 bosses, elites as an Overtime phenomenon | roster audit R1-R8 (`2026-09-19-enemy-roster-audit.md`): paper against a mid-run build, unlock timing ignores the segment |
| Items | 31 item data, 4 sets, rank / merge / rarity law rev 2, accessories | economy rev 2 (`2026-09-19-economy-v2-probe.md`); loot loop pass L1-L6 open |
| Manifestations | 18 nouns, 10 pairs (`data/manifestations`) | the roadmap wanted 12-15 to test whether items change how the player moves: the count is there, the question is not answered |
| NEG | 7 archetypes built (Engine, Doctrine, Lens, Sigil, Litany, Gambler, the Gravemarch rule), `BurdenResolver`, HUD arithmetic | the slice promises three (Engine / Doctrine / Lens); the other four are in the build, not in the promise |
| Ascension | the V4 tree (`data/ascension/tree_v4.json`), 9 engines, Doctrine picks at 3 / 6 / 9 (9 doctrines), Hub purchase | the tree audit (28 proposals) and the NEG-versus-tree study are filed; the redesign is deferred by decision |
| Augments and majors | 16 augments, 10 major choices | |
| Telemetry | balance recorder rev 2 (captures, `tools/telemetry/run_history.py`), the flight recorder with hitch tags, build simulator campaigns | the human baseline capture is still owed |

## 3. In and out

**In:** everything in the table, at the numbers it has today, on the
three styles, with the Hub between segments. **Out, by decision or by
cost:** the Ascension redesign (deferred), new enemies from the roster
audit (proposed, not built), the loot loop proposals (proposed), Rapier
or GDExtension physics (war room M6 / M7), lighting and music (no such
systems), segments 3+ as authored content, and any new item, set or
Manifestation added for volume rather than for a named decision the
slice lacks.

## 4. Acceptance criteria

Each line names its measure. "Playtest" means one human run with the
balance recorder and the flight recorder on, following the script in
section 6.

| # | Criterion | Measure | State today |
|---|---|---|---|
| A1 | Killing feels good within 30 s on each style | Playtest: the immediate-hit question answered yes on melee, ranged and magic | not verified (needs the display) |
| A2 | By minute 10 the player can name the run's direction | Playtest question; the recorder's build snapshot at 10 min shows a set, an archetype or a Manifestation committed | not verified |
| A3 | A deliberate risk is taken or refused on purpose | A Cursed Vault or wager shrine interaction in `events.jsonl`; the player can say why | not verified |
| A4 | A visible power threshold by minute 15 | Recorder: kills per minute in 12-15 at least 2.5x the 3-6 window; the player reports old enemies dissolving | the simulator says builds reach it; unplayed |
| A5 | The Exit Rite reads as a climax | Playtest: pressure spike felt, specialists noticed, escape or near-death; the recorder's exit and pressure sections | mechanics exist; unplayed since the last changes |
| A6 | The build is described in behaviour, not numbers | The end-of-run sentence (roadmap section 25's good example) | not verified |
| A7 | Three runs, three different stories | Three playtests across styles; `run_history.py` shows three different set / archetype / Manifestation lines | not verified |
| A8 | No frame over 33 ms without a tagged, explained cause at 100 enemies rendered | Flight recorder incidents with `hitch_tags`; the war room M0 rendered baseline | headless: the streaming step is under 9 ms; rendered: unmeasured |
| A9 | No loop a careful player would prefer to playing | Loot loop pass section 2 (P1 tree rental, P2 rarity cap) closed or accepted | open (proposals L1-L6) |
| A10 | The Follower economy creates tension at the Hub | Playtest: one purchase regretted or one hoard kept for reconstruction; the recorder's wallet history | rev 2 prices; unplayed |

The slice is accepted when A1-A8 pass on one run per style and A9-A10
have a recorded decision, not necessarily a fix.

## 5. What blocks acceptance, in order

1. **A human baseline run** (owed since recorder rev 2): one attempt per
   style, both recorders on. Nothing above can pass without it, and every
   audit filed today ends in "unplayed".
2. **The rendered performance baseline** (war room M0): the horde
   benchmark windowed at 60 / 180 / 300 and a stationary Endless Lunge +
   Mass Grave capture; the hitch tags then say whether set VFX pooling
   (M2) is worth building.
3. **Loot loop decisions** (A9): Hub-only refunds with the shrinking share
   (L1-L2) and the rarity soft cap applying to the vendor and the shrine
   (L3-L5). Both are design decisions with the code path already read.
4. **Segment 1 human-eyes items** from the story pass: opening walk
   pacing, the reveal camera, evidence-offer timing, the phase-mirror
   lift. The segment 1 design pass (its own document today) lists them
   with the numbers behind each.
5. **Roster R3 / R5** (unlock timing by segment, specialist rarity) if the
   playtest confirms "paper against a mid-run build" at minute 15; not
   before.

Not blocking: the four newer NEG archetypes (in the build, not the
promise), the tree audit's 28 proposals (redesign deferred), M4-M7.

## 6. The playtest script

One run, one style, both recorders on (`docs/BALANCE_RECORDER.md` for
the capture, `docs/2026-08-28-playtest-protocol.md` for the hotkeys).
Note the clock at each window; answer the question in one sentence.

| Window | Watch for | Question |
|---|---|---|
| 0-3 min (Segment 1: admissions to incident) | readable combat, weapon feel, the flicker beats landing | Did killing feel good before any item mattered? |
| 3-6 min (hostile building, evidence store) | the first POS / NEG choice, the first merge, the augment offer under pressure | Did the offer arrive under pressure, and did you read it? |
| 6-9 min (breach, city reveal, Hub) | the reveal camera, the Hub's prices against the wallet | Did the reveal feel like scale? Was there one purchase you weighed? |
| 9-12 min (Segment 2 opening) | the first encounter beat (a wedge, a wall, a crossfire) | Did you stop autopiloting? |
| 12-15 min | the Cursed Vault or the wager shrine | Did you take or refuse the risk on purpose? |
| 15-18 min | old enemies dissolving, a set or archetype visibly working | Could you point at the build in combat, not in the inventory? |
| 18-25 min (Exit Rite) | the pressure spike, specialists, the last-chance vault, the escape | Did the world know you were leaving? |
| End | the Hub | Describe the build in one sentence about behaviour. |

Hand back: the capture folder, the eight sentences and the run's seed.

## 7. Open decisions

- Whether the slice's promise includes the four newer NEG archetypes, or
  stays at three until those three are proven distinct in play.
- Whether A8 is measured at 100 or at 180 enemies (the horde numbers put
  180 at the floor of "annihilation" builds).
- Loot loop L1-L2 (Hub-only refunds) against keeping mid-run tree access
  as a feature of the Wardstone.
