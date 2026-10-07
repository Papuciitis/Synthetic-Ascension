# Game design audit and improvement pass (2026-10-04)

Baseline `0ea360e` (enemy-world-work). The request: audit the game's design
and improve it where needed - FPS, balance, Follower balance, gameplay
intensity, fun, story - and study similar games to see what makes them tick.
Everything below landed as commits on `enemy-world-work`; every number is a
headless measurement or a model, not a played result, and the owed rendered
playtest is listed in §10.

## 0. Summary

| Area | The main finding | What changed |
|---|---|---|
| Intensity | Overtime punished walking to the exit, not farming; every recorded death was in collapse; punctuation was two identical beats a segment; the escape was hidden by the loading card | travel grace + time-driven Overtime (your plan §6.3), roster introduced by phase and segment, rotating beat kinds with relax windows, telegraphed swarms, an escalating Rite, a release beat after it, visible power spikes with a rematch ring (§2) |
| Balance | one-shot deaths through unreadable channels; click-limited damage; segment 2 a spike; elites 85% of collapse spawns | big-hit caps and grace, hold to attack, elites as events that scale with the segment, respawn near the Rite (§3) |
| Fun / feel | hits felt thin; hit-stop was off; silent sounds; unreadable hostile attacks | budgeted hit-stop and punch, hit flash and sparks, low-HP vignette and heartbeat, kill-pitch ladder and callouts, adaptive music, hostile tells (§4) |
| Followers | Followers stopped being a decision after Hub 2-3; belief capped at 225 Followers; reward bugs | a stage price scale on vendor and services, the Congregation driving belief and the crowd, Consecrate, consistent reserve rules, fixed settlement (§5) |
| Story | segments 2-10 silent; no frame for death; no chapter close | the Archive of Accounts: named districts, Registry bulletins, epitaphs, the Chronicler's relays, crowd barks, Bren's letters, the segment-10 close (§6) |
| FPS | real play collapsed to ~15 FPS at minute 13-15 of segment 2 (non-chase enemies keep physics bodies; a physics catch-up spiral the scheduler never saw) | catch-up capped and measured, policy/scheduler/sync/renderer/per-hit costs cut; late-mix mean frame 62.6 -> 32.7 ms with a render stand-in (§7) |

## 1. Evidence and method

- **Human data**: the only clean capture on disk (`balance_captures/2026-10-03/2026-10-03_10-40-42…`, segments 1-2: 11.1 min of play, 1,376 kills, 3,399 Followers earned, one death in collapse) and the newest flight-recorder incidents (`performance_results/2026-10-02`, `-10-03`).
- **Six read-only audits** (pacing, combat and feel, Follower economy, story, performance, comparable games), each from the code with file:line evidence; the performance audit ran ~30 instrumented Godot runs.
- **Five implementation packages** in separate worktrees with focused tests, merged into one branch; each package then got an adversarial review (reviewers per lens, three skeptics per finding, kept when two or more upheld it). The economy and story reviews completed and every upheld finding was fixed; the intensity and feel reviews were cut short by the account's usage limit - the high-severity findings were fixed, the rest are listed in §9; the performance review did not run.
- A baseline sweep of all 204 headless suites on `0ea360e`: the only non-passes were AscensionOrdnanceTest (2), InvariantsTest (1, the V4 tree hash pin), PrimaryObjectiveTest (1) and a probe that times out.

## 2. Gameplay intensity and pacing

### 2.1 What a run looked like (code + the 2026-10-03 human capture)

| Stretch | What happened |
|---|---|
| Segment 1 (3.7 min of play, 1.5 min of cards) | never more than 9 alive, 53 kills, 9 HP lost; first kill at 60-90 s |
| Segment 2 recon, 0:00-1:50 | 1-10 alive, no beat possible (beats started at the disturbance phase) |
| Segment 2 disturbance/ascension, 1:50-3:09 | two beats, always `charger_wedge_small` then `warden_line`; 8 -> 94 alive |
| Segment 2 collapse, 3:09-6:54 | 190-205 alive, Overtime 0.9 -> 17.7, enemy damage x1.1 -> x11, 85% of spawns elite; the death |
| Segment 2 Rite, 6:54-7:21 | ambient suppressed, ~190 Overtime enemies remain, then the loading card |

Segments 2-10 shared one template, and before Overtime enemy HP rose ~3% per
segment (x1.63 at segment 2, x1.87 at segment 10) while a median build's output
grew 3-5x. All 16 archetypes unlocked by time inside every segment. The only
real danger was Overtime.

### 2.2 Findings (ranked by impact on fun)

1. **Overtime punished travel, not farming.** The capture unsealed 23,700 px
   from the gate; the 55-kill buffer was gone after 4.6 s of walking, the evac
   countdown hit zero after 32 s, and the player died 1,835 px short of the
   gate at Overtime 13, then respawned 19,017 px away. Every recorded death in
   every capture on disk (7/7, 13/13, 1/1) happened in collapse.
2. **No climax and no release.** The Rite lowered pressure, and the loading
   scrim covered the completion pulse within about three frames.
3. **Thin, identical punctuation.** Two beats per segment, always the same two
   (escalation popped unlocked beats in catalogue order); nothing in recon or
   after the unseal.
4. **No "new threat" rhythm.** No archetype was new after segment 2, and the
   power-contrast window re-armed every segment and fired in the Hub or the
   opening seconds, where it held nothing (three of three human firings).
5. **Segment 1's climax was broken** (bugs b-d below), and its approach spawned
   13 ticks in 55.6 s against ~65 intended.
6. **The unseal was a cliff**: Overtime 0.9 -> 5.7 and elites ~14% -> 85% of
   spawns within 15 s.

Bugs found and fixed:
- **a.** Ambient spawning ignored the phase gate and the per-segment unlock
  speed-up (`spawner._pick_enabled_entry` checked start time only).
- **b.** Segment 1 never held its Rite stage: the seal refresh after
  `M_FINAL_PLAZA` set the approach stage again.
- **c.** Every segment-1 kill after the approach opened restarted the spawn
  timer behind a fresh grace pause (`set_segment1_stage` had no "unchanged" check).
- **d.** Blocked formations aborted instead of trying another placement
  (segment 1's guaranteed wedge placed 0 of 3).

### 2.3 What changed

| Change | Where | Numbers |
|---|---|---|
| Overtime punishes staying, not travelling (the user's plan 2026-09-17 §6.3, numbers adjusted) | `ThreatDirector` | time term after a travel grace of `clamp(distance_to_rite / 180, 60, 150)` s; time 0.008 -> 0.012/s; kills 0.035 -> 0.006 past the 55 buffer; formation kills and kills inside the exit encounter excluded; additions clamped to HP +2.0 / damage +1.5 inside the encounter; Gospel's injected seconds skip the grace |
| Honest evac countdown | `ThreatDirector._update_evac` | EVAC IN N = real seconds of grace left, then EVAC NOW |
| Collapse ramps in | `ThreatDirector._recompute` | over 20 s from the ascension values; collapse elite add 0.12 -> `min(0.12, 0.04 + 0.01 x segment)` |
| Elites are events again | `ThreatDirector`, `spawner` | Overtime elite bonus 0.65 -> 0.30; elite chance cap 0.85 -> 0.45; concurrent elites 24 -> 12; elite HP x(1 + 0.15 x (segment - 2)), cap x2.2; fodder unchanged |
| Rite no longer stacks spawn speed/elites | `ThreatDirector` | `rite_spawn_factor` 0.6 -> 1.0, `rite_elite_add` 0.15 -> 0 (plan §6.3) |
| Roster by phase and segment (bug a) | `EnemySpawnTable.entry_allowed`, `EnemySpawnEntry.min_segment`, spawn table | recon = grunts/runners only; Sniper/Warden/Lurker from segment 3, Summoner/Chanter/Siphon from 4, Herald/Splitter from 5 (segment 2 collapse now mixes 8 archetypes instead of 16) |
| Beat variety and cadence | `EncounterBeats`, `EncounterDirector` | every beat tagged with the kind of question it asks; least recently asked kind first; tutorial-sized beats segment-1 only; Hunter recon-eligible; first beat 45 -> 40 s, interval 60-90 -> 45-70 s; beats on the walk to an unsealed gate every 40-55 s (none within 2,800 px of the rite); placement fallback (other flank / quarter turn, nudged members) |
| Build-up / peak / relax (Left 4 Dead) | `EncounterDirector`, `spawner.set_ambient_lull` | a beat's arrival holds ambient spawning 3 s; answering it halves ambient spawning for 12 s |
| Telegraphed swarms (Deep Rock Galactic: Survivor) | `EncounterDirector`, `spawner.set_ambient_surge` | every 210-270 s from the disturbance phase until the unseal: an 8 s warning, 20 s at half interval under the same alive cap, an announced break, an 18 s relax window |
| The Rite as a building holdout (Risk of Rain 2's teleporter) | `EncounterBeats`, `EncounterDirector.request_rite_wave` | response = crossfire + a charger pair (was the six-charger wedge); the seven channel waves alternate sights and flankers and end on one fast vampiric hunter; never more than two authored melee per arrival (plan §6.2) |
| The escape is a release beat | `EscapeRelease`, `game.complete_segment` | 2.4 s real time before the Hub: player untouchable, spawning stopped, ordinary enemies within 1,230 px dissolve nearest-first (retired, no rewards or procs), elites/bosses stay, a 0.35 s slow-motion breath, ESCAPED |
| Visible power escalation | `ThreatDirector`, `EncounterDirector`, `SetRunner`, `AugmentRunner` | thresholds remembered per run (not re-armed per segment); thresholds crossed outside combat wait for the next combat phase; 4+ piece set tiers and Transcendences are thresholds now; each opens the hold and a "rematch" ring of 16 old patrols 5 s later |
| Segment 1 bugs b-d | `Level1Builder`, `spawner.set_segment1_stage`, `EncounterDirector` | see 2.2 |

Modelled effect (the code's own formulas, evaluated by hand):

| Scenario | Old Overtime -> enemy damage | New Overtime -> enemy damage |
|---|---|---|
| walk 23,700 px for 120 s at 5 kills/s | 20.0 -> x12.9 | 3.3 -> x1.6 |
| same walk at 10 kills/s | 41.0 -> x31.1 (cap 30) | 6.9 -> x3.6 |
| camp 6 min after the grace at 5 kills/s | 88 -> x79 (cap 30) | 18.8 -> x11.9 |

Farming still becomes lethal; travelling no longer is.

Plan §6.4 recovery was completed alongside: after a death in the exit
encounter the kept progress does not drain for 10 s while the player returns
from a respawn 800-1,200 px from the rite (§3), and new reinforcements wait
5 s. Review fixes: one rematch ring at a time, and no beats within 2,800 px
of an unsealed gate (formations drawn there walked into the exit encounter).

Tests: `ThreatDirectorPressureTest` (39), `EncounterDirectorTest` (88),
`PacingBeatsTest` (40, new), `EscapeReleaseTest` (14, new),
`RiteRecoveryTest` (11, new), `BalanceExitDiagnosticsTest` (35),
`HudThreatTooltipTest` (21), plus the unchanged rite/spawner/elite/enemy
suites (§10).

### 2.4 Not changed (design calls for the user)

- **Binding pick timing.** The per-segment Binding is a paused screen at the
  start of the next segment (70 s paused in segment 2). Presenting it on Hub
  arrival (Brotato batches picks with the shop) would let the player buy with
  the new augment in mind; it touches the save/resume flow, so it is a
  proposal only.
- **Segment 1 for veterans.** Every restart replays segment 1 (about 5 minutes
  with the cards). Bug c's fix makes its approach busier; a "begin at the
  city" option for veterans is a design call.
- **Run finale.** Runs continue past segment 10 by your decision; segment 10's
  close now gets a chapter card (§6), not an ending.
- **Late spawn weights.** Shifting late segments from fodder toward specialists
  adds variety but adds non-chase (non-proxy) enemies, which is exactly the
  measured FPS problem (§7) - left until the proxy question is decided.

## 3. Combat balance and difficulty

### 3.1 Findings

1. **Difficulty was one cliff, and kills drove it** (see §2): before the unseal
   enemies gained about 3% HP and 2% damage per segment, while a median build's
   output grew ~5x by segment 6; from segment 4 kills were limited by the
   spawner (the segment-6 median build clears the 180 cap in 1.4 s).
2. **Segment 2 was a spike**: alive cap 4-20 in segment 1, 180 in segment 2,
   16 archetypes and ~258 elites in one segment.
3. **Burst deaths came through the least readable channels**: no hit
   invulnerability, no per-hit cap; contact was 59% and Spitter bolts 29% of HP
   lost in the human capture, and the fatal hit was a 40.5-damage Spitter bolt
   (base 5) at x11.65.
4. **Every shot needed a click**: the human averaged 2.4 attacks/s (peak 4.9)
   against a cadence cap of ~8/s - damage was click-limited.
5. **Augment ceilings** (Lv.20 x7.65 potency, Doctrine bonuses multiplying to
   x4.22) are a runaway risk - but the cost used to show up as faster Overtime
   (kill-driven); with Overtime now time-driven, more power reads as power.
   Left for a playtest (§9).

### 3.2 What changed

- Overtime, elites, roster gates, elite HP scaling: §2.
- **Big-hit protection** (`player._take_damage`): a contact tick is capped at
  22% of max HP, any other hit at 30%, a boss's at 45% (before armour); a hit
  costing at least 8% buys 0.35 s of visible invulnerability. A full-HP player
  can no longer be one-shot (Halls of Torment's "hitboxes in the player's
  favour").
- **Hold to attack** (setting, default on): the weapon's own cadence gates a
  held button. A large DPS increase for human players; rhythm rules were
  adapted (Death Rattle ignores held repeats; Third Litany and Stored Violence
  resolve a beat on release).
- **Respawn near the Rite** after the unseal (800-1200 px out, walkable,
  fewest enemies, 5 s protection) instead of the checkpoint 19,000 px away;
  the rite's kept progress waits 10 s and new reinforcements wait 5 s
  (plan §6.4).

## 4. Fun and feel

### 4.1 Findings

Hits felt thin: no hit flash, no death animation, no knockback on basic
attacks; no crit/hurt/death/dash/pick sounds; the hit spark existed but was
not wired; `player_melee_hit` and `drop` were defined but never played; item
pickups were silent; hit-stop was off because its first design stopped on
every kill (a 5 Hz stutter at 7.5 kills/s - the "lag" of 2026-09-06). Hostile
attacks were hard to read: Spitters fired with no windup, enemy bolts had the
player's shape, Snipers aimed from off-screen, the Charger's tell faded out
just before the dash.

### 4.2 What changed

- **Hit-stop and camera punch return, budgeted** (`HitFeel`): stops only on
  elite/boss kills (45 ms) and crit kills (30 ms), 600 ms apart, at time scale
  0.25, never past 60 ms; punch only when the player is hurt (2.5-6 px, at most
  every 250 ms) or an elite/boss dies; setting "Hit-stop & Camera Punch".
- **Hit confirmation**: materialized enemies flash white for 0.07 s (at most
  every 0.12 s each); data-only proxies flash in the batched shader; sparks on
  every crit and every third hit (12 per frame); a crit merging into a damage
  number keeps its crit styling.
- **The player's state**: a 0.08 s red hurt tint, an invulnerability blink, and
  at 30% HP or less a pulsing red edge vignette with a heartbeat (-14 dB at 30%
  to -8 dB at 15%).
- **Audio**: kill sounds climb a semitone per 5 kills in 1.5 s (up to +7); a
  "xN" callout and thump at 15 kills in 0.6 s; ELITE DOWN with a sting; the
  silent melee-hit, drop and pickup sounds play. Three procedural sounds
  (heartbeat, thump, sting) come from `tools/design/build_sfx_procedural.py`.
- **Adaptive music without new assets**: a low-pass on the Music bus opens
  with the segment's phase (3.5 / 6 / 10 / 20 kHz for recon / disturbance /
  ascension / collapse or exit encounter) and muffles to 1.2 kHz with a -3 dB
  duck at low health.
- **Readable hostiles**: Spitter/Herald/Tactical shots wait behind a 0.25 s
  tell; enemy bolts draw 1.3x with a halo in the shooter's colour; the Charger
  tell builds to full opacity and flashes on release; Bombers burn a 0.35 s
  fuse; off-screen aiming Snipers get edge markers.
- Health pickups are no longer consumed (and lost) during a healing lock.

Knockback on basic attacks was skipped: the per-hit knockback path
deep-copied cold state; the per-hit no-copy read from §7 removes that
obstacle, so it is a small follow-up.

## 5. Follower economy

### 5.1 Findings

- **Followers stopped being a decision after Hub 2-3**: from Hub 2 the wallet
  covered the whole shelf and from Hub 3-4 any single tree node except the top;
  the shelf rose 2.8x from Hub 1 to Hub 9 while income rose ~7x; the 10-segment
  run on record ended with 16,424 unspent.
- **Belief capped at 225 Followers** (+15%), about 30 s into segment 2.
- **Restock acted as a slot machine** (8 restocks at Hub 1 in the human run,
  no vendor purchase), capped at 999.
- **Defects**: zero-reward actors paid 1 (90 summoned-minion kills paid 90 in
  the human run), one-Follower kills ignored the Overtime decay (~12% of a
  segment's combat income was bug-driven), V5 rank refunds paid 100%,
  inconsistent reserve rules.

### 5.2 What changed

| Change | Where |
|---|---|
| One kill settlement for both death paths: authored-0 pays 0 with no riders; Overtime decay as a fraction with a running carry | `Global.settle_kill_reward` |
| A stage price scale `1 + 0.25 x max(0, segment - 2)` on vendor buys (sells unchanged), restocks (999 cap removed), imprints, wagers; Transfusion `20 x max(2, segment)`/level; Vouchers `max(250 + 50s, 150 + 100s)`; Manufactured Witness `max(100, 8% of the wallet)` - segments 1-2 unchanged | `Global.market_scale`, `HubShop`, services |
| The Congregation: Followers recruited this attempt (recruit reasons only - never trades, refunds, undo or dev grants), saved with the run; belief cap `clamp(0.15 + 0.05 log2(congregation / 2500), 0.15, 0.30)` (+0.15 Prophet, +0.20 Census, ceiling 0.60); the Hub crowd is sized from it, so spending never shrinks the believers you recruited; Run Sheet "BELIEF · CONGREGATION N · CAP +X%" | `Global`, `HubCrowd`, `RunSheetHUD` |
| Consecrate: pay `150 x segment x (k+1)` to raise one Binding card one grade (the paid counterpart of the Burdened Binding) | `Global.binding_consecrate`, `AugmentSelect` |
| Tithes never strand the run (`Global.spend_survivable`); V5 rank downgrades, refunds and their cascades pay the refund share; refunds confirm with the exact quote | `AscensionLedger`, `AscensionScreen`, tithes |
| Telemetry: per segment recruits, peak wallet, Hub-departure wallet and spend by sink (`run_history.py --segments`) | `BalanceLedger`, `run_history.py` |

Modelled per Hub (income from the measured runs, -12% from the settlement
fix; a "reasonable visit" = 2.5 vendor items, 1.5 tree nodes, a Recast, 3
restocks, one Consecrate from Hub 3):

| Hub | Income | Whole shelf | Visit | Unspent reserve before -> after |
|---:|---:|---:|---:|---:|
| 1 | 936 | 714 | 727 | 209 -> 209 |
| 2 | 2,646 | 1,422 | 902 | 2,322 -> 1,953 |
| 4 | 3,780 | 2,012 | 2,184 | 7,446 -> 4,873 |
| 6 | 4,860 | 3,375 | 3,439 | 13,496 -> 7,454 |
| 8 | 5,724 | 5,538 | 5,701 | 18,472 -> 7,659 |
| 10 | 6,480 | 6,546 | 7,798 | 23,274 -> 6,389 |

The reserve levels off at roughly one segment's income instead of growing
without bound. Tree prices and requirements are untouched (the redesign stays
deferred by your decision).

## 6. Story

### 6.1 Findings

Segment 1 carries ~830 words of strong writing; segments 2-10 carried no
story text at all (no district names on screen, no arrivals, no institutional
voice), death had no frame, nothing reacted to deaths, choices, race or
Followers, the Chronicler said "I keep the witness accounts" but never relayed
one, and there was no chapter close. The copy already implied a frame (the
Archives, chronicles, witness accounts).

### 6.2 What changed - the Archive of Accounts

Each run is one account of the same night; the Registry's official report
stands against the movement's witness accounts.

- **Foundation**: `data/narrative/StoryLines.gd` (all line pools in the house
  voice) and `core/systems/narrative/StoryDirector.gd` (a Hades-style picker:
  priority beats above 50, weighted draws below with a recent-line memory,
  once-scopes per profile / attempt / account, seeded per run), a static
  `StoryLedger` fed by existing signals, presenters for segments and the Hub;
  one save field `SaveData.meta_story`.
- **Districts are named, arrived in and left**: the loading card names the
  district; each segment opens with a Registry bulletin (a card the first time
  on a profile, a tip afterwards) and an arrival line; the Hub notes the
  departure. The bulletins stop printing your name as the run goes on
  ("Researcher X" -> "the unregistered practitioner" -> "the synthetic event"
  -> "[NAME WITHHELD]").
- **Death has a frame**: Game Over epitaphs from the run's facts (where, how,
  witnesses), reconstruction card variants, "Last account ended on ..." on the
  save card.
- **The square answers**: the Chronicler relays the last account in the next
  run's first Hub, counts the accounts; crowd barks by archetype, Follower tier,
  Doctrine stage and segment; the Acolyte and staff react; Follower milestones
  (10 to 1M) as witness accounts.
- **Bren** writes after segments 1, 3, 5, 9 and 10, varying with your opening
  answer (saved but never read before).
- **Segment 10 closes the chapter** (UNCONTAINED, bookending Segment 1's
  UNAUTHORISED; a line for the dominant Doctrine family; its last line names
  Syn'Tek - the only place the name appears). The run continues beyond the wall.
- Race classification at the admission desk; 19 RECORDS in the Grimoire;
  factual fixes (Bren carries the original sequences; neutral pronouns in two
  augments; "Rite marker"; "Beyond the Wall · Segment N" past 10).
- Constraints kept: no new Beka lines; Followers have titles, not names; Bren
  stays dialogue-only; bosses are not renamed.

### 6.3 Open questions for you

1. The bosses "The Bulldozer" and "The Arcanist" - the latter shares the
   protagonist's default name. Not renamed.
2. Bren's arc ends after segment 10 in the new letters - is that right?
3. Syn'Tek is spoken only on the segment-10 card - is that the moment you want?
4. "THE ATTEMPT ENDS" and "ASCENSION FAILED" name the same event differently.
5. Left as they were: "One containment officer is dead", the "Resist or
   surrender the work" button (surrender is not possible), "PeeP" in
   OPENING_SEQUENCE.md, the hub labels "Merchant"/"Next Segment", Segment 11+
   rendering the Service Courtyards while the story calls it Beyond the Wall.

## 7. Performance (FPS)

### 7.1 Findings (measured)

- The benchmarks missed the real-play collapse: they spawned at a run clock of
  0-90 s (Grunt and Runner only, both proxy-eligible), while segment 2 at
  minute 13-15 ran at a frame p50 of 58-65 ms with 102-160 materialized actors,
  2-4 physics ticks in 99.7% of frames and the scheduler's pressure at level 0
  in every sample - its physics measure read one tick, not the frame.
- The physics server itself was 0.3 ms a tick; the cost was GDScript in
  `_physics_process` (enemy steps, `sync_legacy_actor`, the representation
  policy's full sorts, scheduler refresh), the renderer publish (~28 µs per
  instance), and per-hit fan-out (95-230 µs a hit).
- Segment 1 hitches: every 5th kill 23-41 ms (checklist labels using glyphs the
  theme fonts lack -> system font fallback), chunk activations 77-178 ms (a
  tile source per random decal alpha), TileMap clears up to 294 ms, the first
  ground-splat noise 160 ms; the hitch tagger mislabelled most of them.

### 7.2 What changed

| Change | Measured |
|---|---|
| Catch-up spiral: the pressure signal reads the whole frame's physics; `Engine.max_physics_steps_per_frame = 2` (runtime, not project.godot); under emergency far chargers/bombers drop to the far tier; mid tier in 5 groups under pressure | late mix: physics ticks/frame 3-4 -> 2 |
| Representation policy: one bulk read, linear selection instead of full sorts (identical choices over 144 random worlds) | 6.1 -> 0.23 ms p50 at 250 alive |
| Enemy step sync fast path (`EnemyWorld.sync_actor_motion`) | 26.8 -> 6.7 µs per update |
| Renderer: bulk reads, inlined writes, no debug mirrors, off-screen culling, half-rate uploads past 120 on-screen proxies; proxy hit flash in the shader | publish 4.0 -> 1.7 ms at 250 alive |
| Per-hit: no-copy cold-state reads, the runner returns early when nothing listens, the recorder folds a frame's hits once, Q flushes budgeted at 64 damage calls | listeners 141-158 -> 78-90 µs a hit; runner 69-78 -> 4-8 µs |
| Scheduler refresh on parallel arrays (identical ranking) | 6.2 -> 2.9 ms at ~175 actors |
| Projectile wall test skips cells with no blocker nearby (0 mismatches in 10,500 segments) | 29.2 -> 11.1 µs per bullet |
| Segment-1 hitches: checklist rows update in place with font-covered marks; one decal tile source per texture (4 alpha levels); chunk clears erase only painted cells; splat noise built during load (identical bytes) | checklist update 31 -> 0.36 ms |
| Hitch tagger charges the frame phase that claimed the frame | segment 1 "unattributed" 240 -> 10 |
| Benchmarks: `HORDE_MINUTES` / `HORDE_SEGMENT` reproduce the late mix; the minigun benchmark's per-frame tree walk removed | - |

Late-mix reproduction (minute 14, 150 alive, firing, a 12 ms render
stand-in; base and new interleaved, 2.6-3.0 GHz): **mean frame 62.6 / 58.5 ->
32.7 / 32.1 ms, p99 126-140 -> 70-77 ms, physics per frame 34-37 -> 11.5 ms**.
Horde benchmark at 550: frame p99 47.6 -> 13.9 ms, physics p95 56.8 -> 19.6 ms
(headless). The roster gates (§2) also lower the non-chase share in segments
2-4.

### 7.3 Not done

- **Proxies for far non-chase archetypes** - the remaining structural cost
  (~130 physics bodies, ~11.5 ms physics at minute 14); needs a decision on
  what off-screen ranged and summoner enemies may do.
- **30 Hz physics with interpolation** (-25% past the cliff in the audit) -
  needs a feel test with the display.
- An emergency-pressure trigger on frame time, vegetation tiles (same random
  alpha issue as decals), the remaining missing glyphs (✓ in "SECONDARY
  COMPLETE", ●/○ set pips: ~6 ms on first show), a typed actor publish record.

## 8. What similar games do, and what this pass took from them

Research on 2026-10-04 (web sources: developer talks and postmortems, GDC
material, wikis with numbers, patch notes; ~190 sources). Wiki figures are
community-maintained; anything unverified is marked.

### 8.1 What makes them tick

| Game | What makes it tick | Lesson for Synthetic Ascension |
|---|---|---|
| Vampire Survivors | move-only input; a small reward about every 23 s; slot-machine chests; minute-scripted waves with set-piece formations that bypass the cap; 30:00 screen clear, then the Reaper | punctuation by authored set pieces; fodder HP fixed while bosses scale with the player |
| Brotato (Godot) | 20 waves of 20-90 s, each followed by a shop; deliberately skewed stats; enemies capped at 100 | batch decisions with the shop; a hard on-screen cap in Godot; prices that rise with the wave |
| Halls of Torment (Godot 4 + C++) | never-impeded movement, player-favoured hitboxes, timed bosses over 30 min | readability over bullet hell; circle checks on a grid instead of Area2D per hit |
| Deep Rock Galactic: Survivor | dig your own escape routes; telegraphed swarms; every stage ends in a 30 s sprint to the drop pod | announce a swarm, let it peak, announce its end |
| 20 Minutes Till Dawn | manual aim, fixed-minute elites and bosses, enemy cap in steps (200/400/600) | caps that step with the run, not a wall from the start |
| HoloCure | a mini-boss every 2 min, scripted walls/rings/stampedes | varied spikes every 90-150 s |
| Megabonk (2025) | the player opens the boss portal; opt-in Final Swarm; Charge Shrines that teach "hold the circle" | rehearse the Rite's verb mid-segment; let skilled players opt into more |
| Ball x Pit (2025) | ball fusion; a self-automating town between runs | meta progression that respects time |
| Nova Drift | super-mods with harsh trade-offs; a boss every 20 waves | build-defining picks with costs |
| Hades / Hades II | ~21k lines chosen from weighted, condition-checked event pools; death returns you to a hub that reacts; bosses remember tallies | cheap reactive story keyed to run facts |
| Cult of the Lamb | the cult (followers with faith and loyalty) and the dungeon feed each other; sacrifice is rare and costly | followers as a stock that produces, not only a wallet you spend |
| Risk of Rain 2 | a difficulty clock; a teleporter holdout the player starts; Void Fields kill everything when a cell completes; prices scale with the same driver as gold | the Exit Rite as a holdout that builds; the clean slate after it; prices that track income |
| Slay the Spire / Balatro | fixed small income against fixed prices; escalating repeat costs; capped interest | spending tension comes from the price curve, not from scarcity alone |
| Darkest Dungeon | one narrator voice reacting to crits, deaths and region entry | one rate-limited institutional voice for the thin later segments |
| Left 4 Dead (pacing reference) | AI director: build up, sustain the peak 3-5 s, relax 30-45 s with minimal spawns; bosses exempt | explicit relax windows |

### 8.2 Lessons applied in this pass

- **Pacing:** relax windows after every answered formation and after every
  swarm (Left 4 Dead); varied spike kinds rotated (Vampire Survivors,
  HoloCure); telegraphed swarms with an announced end (Deep Rock Galactic:
  Survivor); the Rite as a holdout that builds and a clean slate after it
  (Risk of Rain 2); fodder paper-thin while elites scale (Vampire Survivors).
- **Juice:** feedback only for player-relevant events (elite/boss/crit kills,
  being hurt), never per fodder kill - with 300 enemies per-kill feedback is
  noise, which is exactly why the 2026-09-06 playtest read hit-stop as lag
  (Vlambeer numbers: 10-20 ms freeze, one white frame, small kick).
- **Economy:** prices track the income driver (Risk of Rain 2, Brotato);
  escalating repeats without a cap (Slay the Spire's removal, Balatro's
  reroll); followers as a stock that is never shrunk by spending (Cult of the
  Lamb): see §5.
- **Story:** event pools keyed to run facts with priority and once-flags
  (Hades), cause-of-death lines, one institutional voice (Darkest Dungeon):
  see §6.
- **Performance:** stop the physics catch-up spiral; keep the standing crowd
  bounded and cheap (Brotato's 100 cap, Vampire Survivors' 300/500): see §7.

### 8.3 Lessons not applied (yet), with the reason

- **Pay per encounter instead of per corpse** (Slay the Spire, Balatro): the
  cleanest fix for kill income growing with build power, but it changes every
  reward table; the market scale (§5) is the smaller step.
- **A hard standing-crowd cap of ~100 with random non-elite culls** (Brotato):
  the alive cap stays 180; the measured problem is non-chase enemies that
  cannot become proxies (§7), which is a design call first.
- **Circle checks on a grid instead of Area2D hits** (Halls of Torment):
  a larger refactor of the hit path; recorded in §7 as the next structural step.
- **Player-started Rite, opt-in overtime, mid-segment "hold the circle"
  shrines** (Megabonk, Risk of Rain 2's Shrine of the Mountain): good fits,
  new content rather than tuning.

## 9. Open: design calls and review findings not fixed in this pass

**Design calls for you** (not changed): the Binding pick on Hub arrival
instead of segment start; a veteran's start at segment 2; proxies for far
non-chase enemies; 30 Hz physics; augment potency ceilings (Lv.20 x7.65,
Doctrine bonuses multiplying) - watch them now that Overtime no longer
punishes kills; the story questions in §6.3; whether the +30% belief cap and
hold-to-attack's DPS increase want an enemy answer in segments 6-9.

**Upheld by the intensity review, not yet fixed** (low/medium):
- SetRunner/AugmentRunner re-emit power thresholds on every stat recompute; harmless for the hold (deduped per run) but BalanceRecorder logs each emit.
- The per-run threshold memory is not saved, so a Continue can re-fire a threshold; in segment 1 a threshold can be spent where the director cannot rematch.
- The first swarm counts from segment load, so a long recon can land it on the primary objective with the escalation beat; a swarm ignores boss proximity; an unseal during a surge ends it as "announced"; `set_ambient_surge` restarts the clock at the base interval.
- Rite waves: a charger pair plus the last hunter can be 3 melee at once; cleared formations refill without a gap; the wave cursor counts calls, so with Law of Admission the last hunter never comes, and it cannot reach a channelling player anyway.
- A death during the 2.4 s release (only lethal self-payments get past its invulnerability) does not stop the segment completing; closing the game in that window loses the completion; `_retire_some` casts before checking validity.
- Per-segment elite HP also scales the armoured plate.
- EVAC IN counts only the grace, so kills and Gospel sermons no longer move it.
- `debug_force_spawn` is phase-gated too (the benchmarks now set collapse and segment 5 themselves).

**Upheld by the feel review, not yet fixed**: the hurt camera punch always
kicks straight down (it is sent the player's own position); punch decay uses
the new time scale on a frame scaled with the old one; an elite Bomber that
blows itself up on the player is celebrated as an elite kill; the hurt-kick
rate limit keeps the first hit, not the biggest; the crit watch listens per
pellet even when hit-stop is off.

**Raised by feel reviewers but never verified** (the usage limit stopped the
skeptics) - check before relying on them: Death Rattle billing a press-and-hold;
the hit flash guard dropping untagged hits; Nothing Wasted never returning a
held shot; attacking out of rite recovery also ending its phasing; Dignity's
25%-hit drawback now unreachable under the caps; a rite respawn landing
inside the encounter's entry radius; the "fewest enemies" respawn check
counting only materialized enemies; +35% move speed during rite recovery;
BuildSimulator running with big-hit protection on; guard-cancelled hits
still flashing; the big-hit cap applying before all mitigation; the Bomber
fuse burning per physics tick; the Charger release flash on its own clock.

**The performance review did not run.** Its package ships equivalence tests
for every behaviour-preserving change (§7), but nothing was adversarially
reviewed.

## 10. Verification and what is owed

- Every package's suites passed in its worktree, and the merged branch passed
  the parse audit (488 scripts) and the cross-package suites before the
  final review fixes; the last four fixes (held-attack cadence floor, the
  Bottomless hold rule, one rematch ring, no beats near an unsealed gate)
  were committed without a headless run at your request.
- **Owed - a rendered playtest with both recorders on**, segments 1-3 at
  least: the travel grace and the EVAC countdown; the release beat; swarms
  and relax windows; the rematch ring after a set tier or Transcendence; the
  Rite's escalation; hit-stop timing and flash/spark density on the UHD 620;
  the vignette, heartbeat and music filter; hostile tells; hold to attack;
  prices at Hubs 2-4 and Consecrate; story cards, the Chronicler, the
  segment-10 card; proxy culling and the hit flash at screen edges;
  segment-1 decals.

## 11. Where things live

- Pacing: `autoload/ThreatDirector.gd`, `core/systems/encounters/*`, `core/systems/spawner/*`, `core/systems/world/{ExitRite,EscapeRelease}.gd`, `scenes/game.gd`.
- Feel: `autoload/{HitFeel,SfxManager,AudioManager,SettingsManager}.gd`, `core/actors/player/player.gd`, `ui/controllers/HudDangerOverlay.gd`, `core/systems/vfx/*`, `tools/design/build_sfx_procedural.py`.
- Economy: `autoload/global.gd` (`settle_kill_reward`, `market_scale`, congregation, `binding_consecrate`, `spend_survivable`), `ui/screens/HubShop.gd`, `core/systems/augments/*`, `core/systems/ascension/AscensionLedger.gd`, `tools/telemetry/run_history.py`.
- Story: `data/narrative/StoryLines.gd`, `core/systems/narrative/*`.
- Performance: `autoload/EnemySimulationScheduler.gd`, `core/systems/enemy_world/*`, `core/systems/world/{ChunkManager,ChunkTileRenderer,GroundSplatRenderer}.gd`, `autoload/performance/*`; benchmarks take `HORDE_MINUTES` / `HORDE_SEGMENT`.
- Research notes behind §8 are summarised here; the full source list was a working file and is not kept in the repository.
