# Sustained Combat Pressure Design

## Purpose

Reduce the sustained combat frame drops recorded during the 20:06-20:15
segment-two session without weakening bosses, objective actors, snipers, or
nearby contact threats. This work is independent from the interface redesign.

## Evidence

The newest flight-recorder reports show two distinct classes of stalls.

### Scene materialization

- Initial scene construction jumps from 52 to 1,774 nodes.
- Previous-frame process monitors peak at 384-639 ms.
- These captures contain zero to four enemies and coincide with chunk creation
  and scene construction.

This is a transition hitch, not sustained combat pressure, and is outside this
fix.

### Sustained combat

- Live populations reach 70-126 enemies and roughly 3,000-3,827 nodes.
- Physics peaks reach 45-60 ms; process peaks commonly reach 62-98 ms.
- A representative pressure capture reports 98 enemies, 96 physics-enabled
  actors, 30 full-tier actors, 66 mid-tier actors, and only two far actors.
- Another reports 102 enemies with 92-97 physics-enabled actors while pressure
  level is active.
- Navigation builds consume approximately 312-371 ms of worker CPU for
  4,500-5,300 cells. Completion can coincide with slow frames, but the build is
  threaded and is not the dominant sustained main-thread cost in these samples.
- Recorder sampling overhead remains below 1 ms and is not causal.
- Comparable frame spikes existed in the 17:xx session before the current UI
  files were modified.

## Root-cause hypothesis

`EnemySimulationScheduler` budgets ordinary full and mid actors, but
`max_scheduler_tier()` clamps many smart archetypes to mid until they cross the
smart-physics release distance. Under pressure, that distance is still roughly
1,950 px. The clamp is allowed to exceed the nominal mid budget, so dense mixed
hordes retain 90+ collision bodies even when the adaptive pressure system is
engaged.

The intended safety contract is correct: elites, snipers, bosses, objectives,
and enemies capable of immediate contact must not disappear from world
collision. The pressure release boundary for ordinary smart ambient enemies is
too conservative, and emergency pressure engages too slowly for the recorded
bursts.

## Design

### Pressure-aware smart-actor release

- Preserve all existing protection rules for bosses, minibosses, elites,
  objectives, tutorial actors, summons, active interior actors, boss adds, and
  snipers.
- Preserve full simulation for actors inside the full spatial band.
- Ordinary smart ambient actors outside the full band may release body/hitbox
  physics sooner when pressure is active because player projectile hits already
  resolve through the data-side combat query.
- Use explicit normal, pressure, and emergency smart release distances rather
  than an opaque multiplication at the call site.
- Maintain separate release/reacquire thresholds to prevent tier flapping.

Initial measured targets:

- Normal release/reacquire remain 2,600/2,300 px.
- Pressure release/reacquire become 1,600/1,400 px.
- Emergency release/reacquire become 1,450/1,250 px.

These values keep ordinary smart collision through the full band and a safety
margin beyond it while shedding offscreen physics substantially earlier than
the current 1,950 px pressure boundary.

### Emergency response

- Ordinary pressure retains its sustained engagement delay so a single mild
  spike does not churn tiers.
- A measured physics step of at least 40 ms may promote directly to emergency
  pressure after 0.15 seconds of continued severe readings.
- Recovery remains slower than engagement and steps down one pressure level at a
  time.
- Telemetry records emergency fast-path engagements.

### Navigation

Do not change the threaded flow-field algorithm in this pass. Add telemetry
clarifying main-thread snapshot time, worker build time, and publish time so a
future capture can distinguish snapshot/commit stalls from worker CPU cost.

## Correctness constraints

- No protected actor may be assigned a collisionless far tier.
- Snipers retain their existing collision contract at every distance.
- Nearby ordinary smart enemies remain collision-enabled.
- Data-side projectile targeting remains generation-safe.
- Pressure transitions may not cause repeated full/mid/far reversals at the
  release boundary.
- Management pause and first-encounter pause continue to stop simulation.

## Verification

### Deterministic tests

- Pressure and emergency release distances demote an ordinary ranged actor only
  beyond their respective safe boundaries.
- Normal-pressure behavior retains existing distances.
- Elites, snipers, objectives, and other protected actors never demote to far.
- Severe sustained readings reach emergency faster than the ordinary two-stage
  path; a single brief spike does not.
- Release/reacquire hysteresis prevents boundary flapping.
- New flow telemetry separately reports snapshot, worker, and publish costs.

### Runtime benchmark

Run the existing staged horde benchmark and add a focused 120-actor mixed-horde
stage matching the captured segment-two population.

Acceptance at the reference desktop configuration:

- 120-actor mixed-horde physics p95 is at most 20 ms.
- 120-actor frame p95 is at most 33 ms.
- Pressure-state physics-enabled count is materially below live population and
  does not exceed 64 ordinary actors plus explicitly protected actors.
- No correctness test or existing 550-actor benchmark gate regresses.

If the focused benchmark does not improve physics p95 by at least 20% from its
pre-change baseline, the hypothesis is rejected and the release-distance change
must not ship.

## Out of scope

- Scene-transition/materialization hitches.
- Replacing the flow-field algorithm.
- Reducing encounter population or spawn rates.
- Disabling collision for protected or nearby threats.
- UI refresh optimization, which belongs to the ledger-navigation design.
