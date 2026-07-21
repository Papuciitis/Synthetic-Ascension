# Segment 1 Rebuild — Handover and Runtime Checklist

## Chapter route

Segment 1 remains a deterministic institutional escape:

1. Experimental laboratory — opening card, synthesis, movement/attack and initial containment.
2. Research/archive wing — connected rooms, first lethal confrontation and first Wardstone.
3. Containment courtyard — open fight space, assistant commitment, first Follower and Resonance explanation.
4. Institution service district — loading/maintenance spaces, controlled security encounter, detours and second Wardstone.
5. Outer gate plaza — blocked early sightline, final checkpoint, Exit Rite and first horde-pressure peak.

The start is cell `(15, 25)` and the Rite is `(20, -50)` at 64 px per cell. Story areas, Wardstones, barrier cells and the Rite use the shared cell conversion. The three seals still enforce archive, service and outer-approach progression.

## Milestone-driven spawn profile

`Segment1SpawnProfile.gd` is the tuning source of truth.

| Stage | Interval | Alive cap | Batch | New pressure |
|---|---:|---:|---:|---|
| Before synthesis | disabled | 0 | 0 | No ambient enemies |
| Initial containment | 4.6 s | 4 | 1 | Containment Officer only |
| Archive | 3.8 s | 6 | 1 | Adds Runner |
| Courtyard | 3.25 s | 8 | 1 | Adds Orbiter |
| Service | 2.8 s | 11 | 1 | Adds ranged/charge specialists |
| Outer approach | 2.15 s | 15 | 2 | Adds Bomber; Threat allowed |
| Exit Rite | 1.35 s | 20 | 2 | Final channel bursts remain |

The synthesis `spawn_burst(4)` was removed. Synthesis information is one blocking card, followed by grace and ordinary single spawns. The security `spawn_burst(7)` was replaced with three enemies spaced by 0.8 s after a 2.25 s delay. Blocking cards pause actors and spawn timers; dismissal resets the spawn clock, so reading cannot accumulate a wave.

Elapsed scene time never unlocks the early roster. General Threat and elite scaling are ignored until the outer approach.

## Contact damage

Player contact state is keyed by unique enemy instance ID. Area and body overlap events increment a refcount for the same source instead of counting it as two enemies. The loop applies one immediate deterministic tick, then waits `contact_tick` before another.

Swarm multiplier: `min(2.25, 1.0 + 0.35 × (unique enemies - 1))`.

This keeps surrounding dangerous without the former entry-hit plus immediate-loop-hit spike.

## Tutorials and Followers

- The first supported enemy archetype triggers one profile-persistent dossier, safely queued and paused.
- Developer mode can reset or force enemy dossiers.
- The assistant is still the first actual Follower. Pre-assistant combat influence is suppressed.
- The first-Follower card explains belief, supplies and reconstruction.
- Combat gains aggregate into one contextual toast; Hub commitments and enemy drains are explained.
- Death shows either exact reconstruction cost/remaining Followers or the terminal “Pattern cannot be restored” card.
- Hovering the HUD Followers pill shows the next reconstruction cost.

## Resonance

Authored values remain 93% total before secondary sources: synthesis 10%, confrontation 12%, Wardstone 1 17%, assistant 12%, security clear 12%, Wardstone 2 17%, checkpoint 13%. Kills, loot and slow passive gain remain secondary. Final-plaza arrival fills only a remaining shortfall, preventing gate waiting.

## Save/developer compatibility

- Layout version remains `2`; obsolete Segment 1 checkpoints reset and current coordinates are bounds/walkability checked.
- Dossier discoveries are a new profile field with an empty default for older saves.
- Follower count remains attempt-scoped and is clamped at zero.
- The handcrafted builder exits before changing later-segment state.
- Developer starts into Segments 1, 2, 5 and 10 still use the same launch paths; runtime verification remains required.

## Required Godot 4.6 playtest

### Tutorial pacing

- Read the opening card and reach synthesis with zero enemies.
- Confirm the synthesis card closes before grace/spawning proceeds.
- Record time to first enemy, first Wardstone, service checkpoint and Exit Rite.
- Record Resonance on first plaza entry; verify no farming/waiting is needed.
- Confirm the Rite is neither visible, HUD-targeted nor reachable early.
- Confirm early caps/intervals feel manageable and the Rite is the first major horde peak.
- Confirm no burst occurs after pausing on any tutorial/dossier.

### Damage and enemies

- Hold one enemy against both body and hitbox: verify one contact source and no double first-frame hit.
- Repeat with 2–6 enemies and confirm the capped swarm curve is dangerous but survivable.
- Verify dossiers appear once per profile, queue, fully pause, use a readable image, and can be force/reset in developer mode.
- Confirm no dossier interrupts a boss or active Rite channel.
- Confirm indoor/outdoor spawns navigate all five spaces and never appear behind seals/outside bounds.

### UI and Followers

- Verify all eight equipment slots are generated, correctly labelled/mapped and accept current clicks, drag/drop, hover, tooltip and fly-in effects.
- Change exported grid columns and confirm no missing/misaligned controls.
- Verify Expanded Satchel in HUD, Stash and Hub.
- Confirm the assistant changes 0 → 1 and no earlier kill changes Followers.
- Test aggregated combat gains, trade gain/cost, refresh cost, Leech/Herald drains and boss rewards.
- Die with enough, exactly enough and insufficient Followers; verify text, respawn invulnerability and terminal attempt reset.
- Save/reload follower and dossier state.

### Projectiles

- Test ordinary ranged and Spitter/Herald shots against enemies/player, cover and very fast movement.
- Equip Firestone and verify color, impact damage and Burn; verify melee/magic Firestone still works.
- Test shotgun mutation, lifesteal, boss hit caps and piercing if configured.
- Run the developer 100-shot/sustained test and record profiler/frame-time results at several active counts.
- Verify homing, reflected, chain, mine, beam and boss-specific node projectiles remain functional.

### Regression

- Continue after each Wardstone and complete the Rite/completion report/Hub transition.
- Developer-start Segments 1, 2, 5 and 10.
- Test Hub buy/sell/refresh, bag/stash/equipment transfers, bosses, audio and save/reload.

Godot 4.6 was unavailable during this patch. None of the runtime/performance outcomes above are claimed from static validation.

