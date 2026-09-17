# Phase 2 — Prove one great run: implementation plan

**Date:** 2026-08-27
**Parent:** `docs/SYNTHETIC_ASCENSION_DIRECTION_AND_ROADMAP.md` §6–§11, §24 Phase 2
**Status (2026-08-27, end of day):** mechanisms built and unit-tested; tuning and
the playtest verdicts are still the human's. Per section: 2.1 HitFeel autoload
(`autoload/HitFeel.gd`, HitFeelTest); 2.2/2.3 BuildIdentity + Run Sheet sentence
(`core/systems/run_sheet/BuildIdentity.gd`, BuildIdentityTest); 2.4 EncounterBeats +
EncounterDirector wired in `scenes/game.gd` (EncounterDirectorTest); 2.5 CursedVault
(`core/systems/world/CursedVault.gd`, CursedVaultTest; placed by SegmentProcBuilder
from segment 2); 2.6 power-contrast window + 2.8 rite pressure mode in ThreatDirector
(ThreatDirectorPressureTest), manifestation thresholds at 3/5 rules; 2.7 phase
escalation cue + unlocked beat; 2.8 specialist response on channel and climax pulse on
clear. Not built: the 85%-hold optional reward, ritual-interference beats, healing lock
(no mechanism exists yet), elite modifiers (§9).

Phase 2 is experiential. A coding agent can build the *mechanisms* and the
*instrumentation*; only play decides whether they produce the three hits
(§6.1). This plan separates the two so the human's playtest time goes where
it matters.

Tags follow §4: OBSERVED / PLAYTEST / DESIGN BET / VISION.

---

## What exists today (observed in code)

- **Spawning**: `EnemySpawner` picks from a weighted `EnemySpawnTable`
  (`_spawn_one`), with `spawn_burst`, `queue_authored_wave` (Level 1 tutorial
  beats), `spawn_local_encounter(rect, count, owner)` (indoor volumes), and a
  low-level `_spawn_instance_node(scene, minutes, elite, forced_pos,
  special_kind)` that already supports a forced position and a special kind
  (`summon`, `interior`, `boss_add`) that protects the actor from culling.
  Roster: Grunt, Runner, Charger, Brute, Orbiter, Spitter, Bomber, Leech,
  Splitter, Sniper, Herald, Summoner (+ summoned minion).
- **Pressure**: `ThreatDirector` turns kills/time into carry + heat + overtime;
  segment phases `recon → disturbance → ascension → collapse` scale spawn
  interval and elite chance (`phase_spawn_factor`, `phase_elite_add`); after
  the gate unseals, `overtime` and `evac_pressure` climb with time and kills.
- **Exit Rite**: a 20 s channel with seven authored burst stages
  (`BURST_STAGES`, 2→10 enemies), automatic pulses, safeguards, death
  keeps 60% progress; `cleared` → `complete_segment`.
- **Feel hooks**: `RunEvents.player_hit_landed(source, handle, pos, amount,
  is_crit, is_elite)` fires per pellet per target from `EnemyCombatService`;
  `BattleText` numbers and `enemy_defeated` exist; there is **no hit-stop, no
  camera shake, no kill-punch** anywhere (grep: zero `shake`/`hitstop`).
  Melee resolves in `MeleeSlash.gd` (sector query + area overlap), ranged in
  the projectile manager, magic in `_spawn_magic`.
- **Build identity**: Run Sheet shows Burden/Corruption/Doctrine/Lens lines
  and manifestation list; no one-sentence "what am I".

---

## 2.1 Baseline hit feel — mechanisms (DESIGN BET), tuning (PLAYTEST)

Build one `HitFeel` autoload that listens to `player_hit_landed`,
`enemy_defeated` and `player_damage_taken`, and owns three cheap effects,
each a tunable curve, each default-on but individually switchable in
Settings › Accessibility:

1. **Hit-stop**: `Engine.time_scale` dip (e.g. 0.05 for 30–60 ms) on crits,
   elite hits and kills, with a per-frame budget so a 550-bullet torrent
   cannot chain-freeze the game (at most one stop per 120 ms, longest wins).
2. **Camera punch**: a short directional kick on the player's `Camera2D`
   (offset, not position), stronger for melee than pellets; kills punch
   toward the corpse.
3. **Kill punch on the enemy**: a 60 ms scale pop + white flash via the
   existing modulate path before the pooled node hides; data-only proxies get
   the batched far-kill flash from the backlog (B4).

Per-style defaults to hand the human: melee = heavy stop + punch, ranged =
light per-pellet, magic = stop on impact burst. Everything exposed as
`@export`s on the autoload so tuning needs no code.

Verify: HitFeelTest (budgeting, accessibility off = no time_scale writes),
plus the human's judgement on the three baseline weapons.

## 2.2 / 2.3 Build legibility — instrumentation (OBSERVED gap → VISION)

The roadmap's playtest criterion (§14) is "describe the build in one
sentence". Give the Run Sheet that sentence (§15):

- `BuildIdentity.describe(inventory, augments, manifestations)` → primary
  identity (Corruption / Doctrine / Lens / Momentum / Shard / none), secondary
  engine (the strongest generator→spender chain among active
  manifestations), set progress, NEG census + active burden, Luck.
- The Run Sheet renders it at the top; the run archive stores it, so a
  playtest session yields a list of "what runs became".
- Manifestation *graph* read: classify each active manifestation by its role
  tags (generator / converter / spender / amplifier / bridge) and report
  connected chains; 2.3's "can 2–3 engines emerge" becomes a number the
  archive shows per run.

No balance changes here; this is how the human sees whether 2.2/2.3 hold.

## 2.4 Encounter beats (DESIGN BET) — 5–8 authored beat types

An `EncounterBeat` data resource + `EncounterDirector` node that the
ThreatDirector can schedule (§8.1 "what kind of problem"). Each beat is
composed from existing archetypes via `_spawn_instance_node(scene, …,
forced_pos, special_kind=&"beat")` so beats are protected from culling and
counted separately from the ambient cap:

| Beat | Composition | Where | Player must… |
|---|---|---|---|
| Charger wedge | 5–7 Chargers in a V | one flank, 900 px | move laterally |
| Shield wall | 4 Brutes in a line + 3 Spitters behind | ahead of travel | flank or pierce |
| Sniper crossfire | 2 Snipers at ±60° | 1400 px | break line of sight |
| Summoner nest | 1 Summoner + 2 Heralds, static | off-route, 1100 px | commit to a detour |
| Hunter | 1 elite Runner with "fast" + "vampiric" | anywhere | turn and fight |
| Bomber carpet | 6 Bombers in an arc | between player and objective | reposition |
| Leech ring | 8 Leeches in a ring, closing | around player | burst out |

Scheduling: one beat per 60–90 s from `disturbance` onward, never during a
tutorial stage, never two of the same in a row, cooldown after the Exit Rite
unseals (the rite owns that time). Each beat announces itself once (a
`BattleText.popup` word and a HUD callout via `RunEvents.objective_changed`
style channel) so it is *legible*, and reports `beat_started/ended` events
to the flight recorder so playtests can be read back.

Verify: EncounterBeatTest (composition, placement respects walkability,
protection from culling, cooldowns), then playtest which beats stop
autopilot.

## 2.5 One strong risk/reward encounter (DESIGN BET)

Reuse the indoor local-encounter machinery: a **Cursed Vault** beat placed
off-route with a visible reward (guaranteed Manifestation or rare item) and
an explicit cost when opened: Threat spike + a Hunter beat + healing
disabled for 45 s. Opening is a deliberate interaction (hold), so the
"fuck it" moment is a choice, not an ambush.

## 2.6 Power contrast (DESIGN BET)

Two levers, both data:
- **Enemy scaling floor**: `ThreatDirector` currently scales HP/damage/speed
  continuously with carry/heat; add a per-segment *lag* so enemy HP scaling
  trails player power for the first N minutes after a power threshold
  (Manifestation count 3, 5; rarity merges), letting old enemies visibly
  crumble before the next threat arrives.
- **Threshold announcements**: when the player crosses a threshold, the world
  says so (a popup + the director queues a "…what is THAT" beat: Hunter or
  Shield wall) — the rhythm in §11.

## 2.7 Mid-run escalation (DESIGN BET)

Bind the segment phases to visible changes: `ascension` unlocks two new beat
types and elite modifiers; `collapse` adds the ritual-interference beat
(local rule change: projectiles curve or dead enemies revive briefly). Each
phase change already emits `segment_phase_changed`; the HUD label should
carry a one-line "the district is changing" cue.

## 2.8 Exit Rite as climax (DESIGN BET)

The rite already escalates bursts; make the world *react*:
- At channel start: `ThreatDirector` enters a `rite` pressure mode (spawn
  interval ×0.6, elite +0.15, specialist response: one Sniper crossfire beat
  + one Charger wedge on the route to the gate).
- At 50% hold: reality distortion cue (screen tint + manifestation overlays
  intensify; cheap, uses the existing pulse VFX).
- At 85%: "last chance" — an optional Cursed Vault-style reward spawns at the
  edge of the rite radius; taking it costs the safeguard buffer.
- On clear: a 2 s power-fantasy pulse (automatic pulse stage 3 with a larger
  radius) before `complete_segment`, so escaping *looks* like a god.

Verify: ExitRiteClimaxTest (mode enters/leaves with the channel, beats spawn
once, reward cost applied), then playtest the "escape looking like a god or
die close to the exit" feeling.

---

## Order of work

1. HitFeel mechanisms (2.1) — smallest, unblocks every playtest.
2. BuildIdentity + Run Sheet sentence (2.2/2.3) — makes playtests readable.
3. EncounterBeat + EncounterDirector with the seven beats (2.4).
4. Cursed Vault (2.5) on top of beats.
5. Power contrast + threshold announcements (2.6) and phase escalation (2.7).
6. Exit Rite climax (2.8).

After each step: unit tests green, full sweep green, one windowed playtest by
the human with the §25 questions. Numbers (durations, multipliers) are
exports everywhere; this plan fixes shapes, not values.
