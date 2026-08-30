# Playable Opening Sequence — 0.23.0

## Purpose and scope

Area 1, Segment 1 now begins inside the existing handcrafted laboratory. The sequence establishes the earliest surviving account of stable synthetic magic, the mortal player identity, Bren's role as Lattice Specialist, a reasonable arrest attempt, the player's first lethal choice, and Bren's commitment as the first Follower. It does not introduce the later title, PeeP, escort AI, new procedural-generation rules, or later-area lore.

## Phase ownership

| Phase | Player action / presentation | Durable result |
|---|---|---|
| Historical | Two minimal dark-screen beats; mortal name substituted | Current phase saved |
| Admission | Walk the public admissions wing: desk registration, ward flicker, laboratory door; movement free, attack locked | Record-only admission milestones; phase saved |
| Bren | One four-option response; a short reaction | `opening_response_id` saved |
| Synthesis | Move to and activate nodes 0, 1 and 2 | Synthesis milestone and Resonance |
| Calibration | Fire the selected starting attack at a safe procedural target | Demonstrates unclassified attack |
| Construct | First-enemy dossier, then one controlled construct | No drop or Follower reward |
| Officer | Named arrest dialogue; officer cannot take damage until the player presses Attack | First-confrontation milestone |
| Aftermath | Time reduction, music reduction, death alert and Bren response | Lethal escalation recorded |
| Separation | Records-conduit dialogue and restrained camera framing | Bren commitment milestone |
| First Follower | Human presentation, not a currency toast | Followers set to one |

The ADMISSION phase was inserted after HISTORICAL by `OPENING_SEQUENCE_VERSION = 2` (`autoload/global.gd:34-36`); saved v1 phase ints at or beyond it migrate by +1.

`core/systems/world/opening/OpeningSequenceController.gd` owns ordering, input restriction, camera offset, spawn suspension, save phases and cleanup. `OpeningSequenceWorld.gd` draws the light procedural apparatus and three interaction nodes. `OpeningActor.gd` supplies the calibration, construct and officer targets without ordinary drops, kill events or Follower rewards. `Level1Builder.gd` remains authoritative for milestones, Resonance, barriers and the post-opening spawn stage.

## Presentation and dialogue

`data/narrative/OpeningSequenceData.gd` is the single copy source. It contains line ordering, response IDs/labels/reactions, full and short variants, and player-name substitution helpers. `ui/screens/opening/OpeningPresentation.gd` renders five treatments: borderless historical text, Bren/officer dialogue, clinical institutional notices, cyan lattice messages and the warm first-Follower panel. Small world prompts remain non-blocking.

This intentionally avoids a portrait dependency. Bren is dialogue-only. The opening targets use geometric drawing rather than unrelated placeholder character art.

## Full, short, skip and resume

- A profile that has never completed the full opening receives `full`.
- Later fresh attempts receive `short`: the player begins beside the apparatus, receives one Bren line, performs one alignment and sees the known-pattern pulse.
- `skip` grants the same three Segment 1 milestones and Bren/Follower state without presentation.
- An interrupted full opening resumes from its attempt-scoped phase. Historical framing is not replayed once a later phase was saved.
- Existing active saves already beyond synthesis migrate to completed legacy opening state. Segment 2+ bypasses the controller.
- The Base screen exposes **Replay full opening** after the profile has seen it once.

## Camera, input, spawning and tutorial queue

The player-owned `Camera2D` receives a restrained local offset toward the apparatus and records route; its original offset is restored on completion or controller exit. Movement and attack are locked only around blocking beats. Synthesis nodes permit movement but not attack. Both opening fights return ordinary movement/attack control.

`Level1Builder.begin_opening_sequence()` forces `BEFORE_SYNTHESIS`, disables the ambient spawner and removes only ambient enemies that may have appeared during a resume frame. Scripted targets are marked `opening_scripted` and `never_cull`. The construct dossier uses the existing modal queue while combat is paused. Normal spawning resumes at the established Archive stage with 4.5 seconds of grace, preventing a timer burst.

## Save fields

Profile-scoped:

- `opening_full_intro_seen`
- `opening_response_id`
- `opening_follower_explanation_seen`
- `opening_replay_full_next_run`

Attempt-scoped:

- `attempt_opening_version`
- `attempt_opening_mode`
- `attempt_opening_phase`
- `attempt_opening_completed`
- `attempt_opening_officer_completed`
- `attempt_opening_bren_committed`

## Developer controls

The opening developer controls live in the developer console (`ui/widgets/PerformanceOverlay.gd`, OPENING MODE section), which calls into `DevSetCollisionTools`; `Global.debug_set_collision_tools` is a dead flag — only ever assigned `false`, never read (corrected 2026-08-30). They support full/short/skip, replay-next-run, fresh opening-state reset, a serialized legacy-save migration simulation, synthesis/target/construct/officer/death/Bren phase starts, all four response dispositions, and direct Segment 2/5/10 launches.

## Placeholders and extension points

- Existing UI click, wardstone-complete, error and enemy-death sounds are restrained stand-ins for apparatus, pulse, alert and death emphasis. No new licensed audio was added.
- Geometric targets and lattice drawing are temporary authored visuals suitable for low-end hardware; final apparatus/insignia art can replace presentation without changing sequence state.
- Later Bren material can read `opening_response_id` without branching this opening.
- Later Chronicle contradictions can add records around this account without changing the opening's restrained historical line.

## Runtime boundary

Historical 0.23 note: no Godot executable was installed in the packaging environment of the time. Since August 2026 the project runs under Godot 4.7 (headless suites via the Linux 4.7.2 binary — see `README.md`), so the boundary below no longer applies as written: cinematic pacing, typed GDScript loading, imported resources, save migration, camera feel, input, physics, audio, UI layout and spawn transitions require the supplied runtime checklist.
