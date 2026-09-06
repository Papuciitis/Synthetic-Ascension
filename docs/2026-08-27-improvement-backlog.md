# Improvement backlog — what would make Synthetic Ascension better

Written 2026-08-27 after the performance audit, the review round, and the
benchmark re-runs on branch `enemy-world-work` (HEAD `ed1a00b`). It is a ranked
list of what I would do next and why.

**Status 2026-08-28:** done since writing — #1/E1 pressure benchmark exercises
pressure (`20b1b21`), A1 materialization-reason telemetry + burst demotion
(`20b1b21`), #7/D1 option (b) `Global.request_quit()` (`6639ece`), B2 wave
scripting → EncounterBeats/EncounterDirector (`6639ece`), E4 commit bodies now
carry measurements. Everything else is open; priorities now follow
`docs/SYNTHETIC_ASCENSION_DIRECTION_AND_ROADMAP.md` §24.

Legend: **Effort** S (hours) / M (days) / L (a week or more). **Confidence**
is how sure I am the change pays off, based on what the code and captures
actually show. Items marked *observed* come from code or measurements; items
marked *opinion* are design judgement.

---

## The ten things I would do first

| # | Item | Effort | Confidence | Why it is first |
|---|------|--------|------------|-----------------|
| 1 | Make the pressure benchmark actually trip pressure | S | high | Its gate cannot pass by construction today, so nobody can measure the pressure system |
| 2 | Cap live materialization to what the benchmark proves | M | high | Live play converges at ~263 materialized actors vs 64–90 in the benchmark; that gap is the whole "500 enemies at 50 ms" story |
| 3 | Data-only proxies for every archetype, not just CHASE | L | high | Every non-chase enemy must be a full node today; the proxy tier only scales the grunt horde |
| 4 | Projectile simulation in a GDExtension (or packed batch math) | L | medium | 550 bullets alone cost ~15–20 ms of process; GDScript per-bullet loops are the ceiling for bullet-heaven builds |
| 5 | A frame-pacing mode for high-refresh displays | S | high | 144 Hz users get the worst of both clocks today; one setting fixes it |
| 6 | Make the scheduler refresh itself cheap or off-step | M | high | The 5 Hz refresh is the slowest physics step in every benchmark |
| 7 | Retire the exit-time crash | M | medium | rc=139 after every full-run test poisons CI signal and will eventually hit players on quit |
| 8 | Run the benchmark gates in CI, windowed | M | high | The gates exist now; unrun gates decay |
| 9 | Elite and wave legibility | M | opinion | High threat = 80%+ elites; the player cannot read why a wave is hard |
| 10 | Commit hygiene for perf work | S | high | Three of the last perf commits shipped with empty bodies and no numbers |

---

## A. Performance the player actually feels

### A1. Cap live materialization to the proven budget — *observed*
- **What:** Live captures at ≥500 logical enemies average **263 materialized
  actors** (max 919) with median frame 50 ms / p95 123 ms, while the horde
  benchmark holds 64–90 materialized and passes its 33 ms gate. The
  representation policy (budget 64, ceiling 96, 480/640 px hysteresis) is
  being overridden by something in live convergence — most likely the
  lease/attach path for enemies that arrive already inside the band, and
  non-chase archetypes that cannot be proxies at all (see A2).
- **Do:** instrument `EnemyRepresentationManager` with a counter of *why*
  each actor is materialized (in band / not proxy-eligible / protected /
  leased), record it in the flight recorder, and make the ceiling a hard
  ceiling with a priority order (closest first, protected always). Then
  re-capture a real session and compare against the benchmark.
- **Verify:** live capture at 500+ logical shows materialized ≤ 96 and frame
  p95 within 1.3× of the benchmark's.

### A2. Proxies for every archetype — *observed*
- **What:** `EnemyProxySimulation` only simulates `CHASE` records
  (`_is_proxy_chase`). Ranged, orbit, summoner, tactical, herald, charger,
  bomber, leech, splitter and sniper all need a full node, so a mixed late
  wave is mostly nodes regardless of distance.
- **Do:** define a data-only behaviour per archetype at "far" fidelity:
  ranged/orbit keep a standoff distance and do not fire beyond N px;
  chargers path like chase with a speed burst; bombers path like chase;
  summoner/herald/tactical/sniper stay node-only (they are few and special).
  The scheduler's `noncontact_release_min_distance` floor already encodes the
  safe distance for this.
- **Verify:** EnemyProxySimulationTest per archetype; horde benchmark with the
  mixed spawn table instead of grunts only.

### A3. Projectile simulation off GDScript — *observed*
- **What:** The 550-bullet torrent costs ~15–20 ms of process by itself
  (Minigun stage 0, no enemies). The per-bullet loop, ledger dictionaries and
  segment tests are all interpreted.
- **Do:** either a small GDExtension (C++) that owns the packed arrays and
  does move + wall DDA + segment-vs-circle in one pass, or, cheaper first
  step, batch the segment queries by spatial cell so one gather serves many
  bullets. Keep the hit ledgers in GDScript.
- **Verify:** Minigun stage 0 process p95 < 5 ms.

### A4. Frame pacing on high-refresh displays — *observed*
- **What:** Physics runs at 60 Hz, render at whatever the display does. Enemies
  are interpolated per render frame, bullets step per render frame within one
  tick of physics time, proxies blend against their 10 Hz slice. At 144 Hz
  the three clocks visibly disagree during load.
- **Do:** a settings toggle "Match physics to display rate (up to 120)" that
  sets `Engine.physics_ticks_per_second` = min(display Hz, 120) and scales the
  physics budget thresholds accordingly; default off. Also expose the render
  cap (60/120/uncapped/vsync).
- **Verify:** capture at 144 Hz shows bullet/enemy step sizes uniform frame
  to frame.

### A5. Make the scheduler refresh not the slowest step — *observed*
- **What:** `compute_assignment` at 5 Hz is a per-candidate Dictionary
  allocation plus `sort_custom` over the whole population; it is the max
  physics step in every benchmark (`assignment_usec` 2.7–3.7 ms at 120
  enemies, far more at 500+). The new per-step measurement subtracts it from
  the pressure signal, but it still costs the frame.
- **Do:** keep candidates in packed arrays (`PackedFloat32Array` priorities
  + `PackedInt32Array` ids) and use a partial selection (top-k for full and
  mid budgets) instead of a full sort; or time-slice the refresh across
  frames like the proxy simulation does.
- **Verify:** `assignment_usec` < 1 ms at 600 enemies.

### A6. Renderer: shrink hidden batches, drop the stale high-water — *observed*
- Batches that go to zero proxies never pass through `_ensure_capacity` and
  keep their peak buffer forever; `_hide_batch` also feeds that capacity into
  `visible_count()` on half-rate frames. Small fix: route empty batches through
  the shrink path.

### A7. Manifestation overlay budget — *observed*
- Up to 18 overlays each with its own material and canvas item. Beyond the
  30 Hz pulse throttle now in place, a single `ManifestationOverlayLayer`
  that draws all rings/halos in one `_draw` (one material, one canvas item)
  would remove the per-effect canvas rebuild cost entirely. Effort M.

---

## B. Combat depth and feel

### B1. Elite legibility — *opinion, grounded in observed numbers*
- At high threat the elite chance saturates at 0.85, so most enemies are
  elites and "elite" stops meaning anything. Replace the flat promotion with
  a small set of visible modifiers (armoured / fast / splitting / shielded /
  vampiric), one or two per elite, with a silhouette or outline colour per
  modifier, and cap elites per wave by *count*, not chance. The threat
  director's overtime can then escalate modifier count instead of promotion
  rate.

### B2. Wave scripting on top of the director — *opinion*
- The ThreatDirector is kill-driven and continuous. Authored "beats" (a
  charger line from the west, a summoner nest, a sniper duo on the ridge)
  layered on the continuous pressure give the player something to read and
  counter. Data: a small wave table per segment consumed by the spawner's
  existing burst path.

### B3. Pierce and beam weapons now behave — *observed*
- With the sorted segment sweep, Anchor Rite (pierce 12–14) hits every enemy
  it crosses. Worth a tuning pass: pierce damage falloff per hit (e.g. −10%
  per enemy) so line-clears feel earned; today it is flat.

### B4. Hit feedback at proxy distance — *observed*
- Data-only deaths skip item drops on purpose and have no impact effect.
  A cheap batched "far kill" flash in the proxy renderer (one instance in a
  dedicated batch for ~150 ms) makes far kills readable without nodes.

### B5. Player melee vs far-tier bodies — *observed*
- Far-tier bodies have no shape and an unmonitorable hitbox; the 640 px floor
  keeps them out of melee range under emergency pressure, but a dash or a
  wide weapon could still reach a far-tier actor. Make the floor derive from
  the player's longest melee reach + dash distance instead of a constant.

---

## C. Systems and economy

### C1. Luck restat spikes — *observed in captures*
- The Luck restat path shows as multi-frame spikes at 0 enemies during
  transitions. Whatever recomputes on Luck change (loot tables, shop rolls)
  should be memoised per Luck value or deferred a frame.

### C2. Autosave never on the kill path — *observed*
- Already dirty-flagged and flushed; make the flush explicitly happen only on
  segment transitions, shop open, and app pause, and assert in a test that no
  `ResourceSaver.save` runs during combat frames.

### C3. Follower economy readability — *opinion*
- Followers are earned per kill (min/max + elite bonus) and spent in the hub.
  A run-end breakdown (earned by archetype, elite bonus share, spent on
  what) would make the economy legible; the run sheet archive already has the
  storage.

### C4. Pickup lifetime — *observed*
- Exploration loot never expires and every pickup polls the player. Beyond
  the idle poll, a player-side magnet Area2D (one shape on the player,
  pickups `set_process(false)` at rest) would make idle pickups cost zero and
  remove the duplicated magnet code in ItemPickup/HealthPickup.

---

## D. Robustness

### D1. The exit-time segfault — *observed, unresolved*
- rc=139 strictly after `quit()` on sessions that ran a full chunk-streaming
  scene (about 30% per quit, headless and windowed; three hypotheses already
  falsified: static RID caches, SfxManager voices, WASAPI). Two paths:
  (a) minimal repro for an upstream Godot issue using EnemyProxyRolloutTest;
  (b) on quit, flush saves then `OS.kill(OS.get_process_id())` after a
  deferred frame — masks the teardown race for players and CI at the cost of
  skipping engine cleanup. I would do (b) behind a project setting and file (a).

### D2. Pause-state invariants — *observed*
- Several bugs this week were "state written deferred, then paused". A test
  that pauses the tree mid-recycle/obtain/tier-change and asserts collision,
  visibility and registry state afterwards would catch the next one.

### D3. Save validation cost — *observed*
- Autosaves are unvalidated on purpose; the validated path re-reads the file.
  Validate on load, not on save, and keep a checksum in the header.

---

## E. Tooling and process

### E1. Fix the pressure benchmark's workload — *observed*
- At 120 enemies on this machine `pressure_level` stays 0 in both arms, so
  legacy and candidate are identical and the ≥20% gate cannot pass. Either
  raise the workload until physics sits above `budget_pressure_ms`, or make
  the benchmark force pressure (`set_physics_pressure_override`) so it
  measures the *effect* of the tier policy rather than whether pressure
  happens to trip. Also sample the scheduler's `physics_step_ms` rather than
  `Performance.TIME_PHYSICS_PROCESS` (a once-per-second max) so p95 means
  what it says.

### E2. Benchmarks in CI, windowed — *observed*
- `tools/perf/run_benchmarks.ps1` exists; the horde gate only means anything
  with a real renderer. A self-hosted runner with a GPU (or a software GL
  fallback) running it nightly, storing `performance_results/benchmarks/*` as
  artifacts, and failing on gate regressions, would have caught the 08-24
  regression the day it landed.

### E3. Capture analysis as a gate — *observed*
- `tools/perf/analyze_captures.py` already buckets process/physics by enemy
  count. Add a "regression vs previous day" mode and run it on every capture
  directory in CI.

### E4. Commit hygiene for perf work — *observed*
- Three 08-26 perf commits had empty bodies and no measurements. A
  lightweight rule: any commit touching `autoload/EnemySimulationScheduler.gd`,
  `core/systems/enemy_world/*` or `core/combat/projectile/*` includes the
  benchmark line it was measured with. Cheap, and it makes audits a diff.

### E5. Display-only probes — *observed*
- Six test scenes need a window and fail or time out headless. Mark them with
  a naming convention or a `requires_display` meta and skip them in the
  headless sweep automatically instead of by hand.

### E6. Test exit-code policy — *observed*
- Encode the "rc=139 after a printed full PASS summary counts as pass" rule in
  the sweep script so CI is not red on the engine flake while D1 is open.

---

## F. Architecture (longer horizon)

### F1. Enemy world as the only truth — *observed direction, opinion on pace*
- The authoritative Enemy World is the right shape: handles, packed arrays,
  representation leasing. Finish the migration: move HP, status and knockback
  reads in the remaining node paths (`EnemyActor` still mirrors several) to
  the world, and make nodes pure views. Then A2 becomes a data change, not a
  behaviour port.

### F2. Deterministic simulation clock — *opinion*
- The proxy sim, bullets and scheduler all consume physics time now. One
  more step — seedable RNG per system and no wall-clock reads in gameplay —
  gives replays and a deterministic benchmark, which makes every perf number
  reproducible instead of "noise 7.9–12.6 ms across identical runs".

### F3. Spatial index shared by everything — *observed*
- EnemyIndex (nodes) and EnemyWorld's grid (records) both exist. Once F1
  lands, retire EnemyIndex's bucket grid and query the world grid from
  spells, magnets and the scheduler alike; one index, one set of radius
  queries, one place to clamp the radius.

---

## What I would explicitly not do

- Do not raise `max_physics_steps_per_frame` to "fix" dilation; the cap is
  what stops the death spiral.
- Do not add more tiers to the scheduler; the bugs this week were all in the
  transitions between the three that exist.
- Do not tune pressure thresholds until E1 gives a benchmark that exercises
  them; today any number would be tuned against noise.

---

## Archived 2026-09-06: hit-stop

`HitFeel.hit_stop_enabled` is now off by default. In the 2026-09-06 playtest
the `Engine.time_scale` dip on crits, elite hits and kills read as a hitch
("feels like lag"), not as impact. The code, its exports (`stop_scale`,
`stop_ms`, `min_stop_interval_ms`) and `HitFeelTest` are kept whole so it can
come back tuned; the camera punch stays on. If it returns, try a shorter stop
(20 ms) with a visible flash on the same frame, or a stop only on kills, and
judge it in a windowed run rather than by numbers. Effort S, confidence
*opinion*.
