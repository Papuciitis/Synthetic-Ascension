# First-trailer capture readiness — 4 November 2026

Status: source inspection only; this audit launches no engine and produces no
footage. The first visual priority remains the ground: improve actual-use yard
and courtyard support shapes, then inspect the ordinary Game view. Building a
new recording mode is deferred. The existing ground handoff records the broad
rectangular plots as open work (`docs/handoff/LINUX_STATUS.md`, 23 October entry).

## Useful capture foundations

`tools/dev/CityStreetTraversalProbe.gd` is the strongest existing street base.
It uses the actual Game, a player-centered camera (200–203), normal HUD and
live spawning, encounter director, enemy scheduling and streaming (53–84,
187–197). Seed/passage selectors replay input-driven passage traversal,
building entry/roof cutaway, pickup and a chunk crossing (16–17, 125–180).
It currently saves stills and a traversal report, not a motion sequence.
Initial placement, the ring pickup, god mode, scripted movement/aim/fire and
modal onboarding bypass are staged conditions (12–15, 195–197).

`tools/dev/EliteCrowdFightPreview.gd` already captures real moving Game pixels
with normal simulation speed and HUD (142–178, 217–242). It controls population,
uses god mode and scripted attacks, and includes one deliberate triple-modifier
elite beyond ordinary rolls (178). It is a staged combat showcase, not an
ordinary-run or balance result.

`CityBlockPlayablePreview.gd` scripted capture offsets its camera by
`Vector2(140, -160)` (627–630), disables ambient spawning and the procedural
builder, and freezes streaming (90–109, 167). Its `--playable` branch restores
centered camera and streaming (171–175), but does not restore those producers
or record a clip. `OpeningTransitionPreview.gd` freezes transition states over
a flat stand-in background (38–43, 88–101); it is not continuous opening footage.

## MovieMaker clock traps

Godot's [stable Creating movies documentation](https://docs.godotengine.org/en/stable/tutorials/animation/creating_movies.html)
describes offline recording, `--write-movie`, `--fixed-fps 30`, and lossless PNG
sequences with a WAV sidecar. Encoding must use the recording FPS. Offline frame
pacing does not establish live game performance, and the documentation explicitly
distinguishes this workflow from real-time gameplay recording.

- `CityStreetTraversalProbe.gd:454–459` implements `_wait_seconds` with wall-clock
  ticks. Slow offline frame writes can consume its 0.5/0.6/1.5-second deadlines
  after too little simulation has advanced (166, 175, 389, 394, 602).
- Its overridden `_walk_to` (466–534) calls `_live_step` (561–578): movement is
  bounded by 120 physics ticks and 30 stalled ticks, not a wall-time timeout.
  The inherited walker (`CityBlockPlayablePreview.gd:557–599`) is also physics
  tick based, and this subclass does not use it.
- Inherited `_frames` waits process frames (538–539). The 75-frame pickup hold
  at `CityStreetTraversalProbe.gd:161` becomes 2.5 simulation seconds at 30 FPS;
  it is 1.25 seconds at the fixture's 60-FPS baseline. Streaming settlement
  likewise has a 25/480-process-frame minimum/limit (base 532–536).
- `core/actors/enemy/modules/EnemyAnimator.gd:70` selects stride frames from
  wall time; its proxy also reads that region (5–8). Fixed simulation delta
  alone therefore cannot certify normal-speed enemy animation in offline output.
- Hit-feedback clocks also use wall time: `EnemyLifecycle.gd:37–55` and
  `core/systems/enemy_world/EnemyProxyRenderer.gd:117–127,252,486,586,659–661`.
  Navigation caches additionally use it (`EnemyHordeNav.gd:139,390`).

## Memory and a future experiment gate

The existing crowd recorder retains each RGB image in `_pixels` before saving
after combat (`EliteCrowdFightPreview.gd:151–165`). A 1280×720 RGB frame contains
2.64 MiB of pixel data: four seconds at 24 samples/s is about 253 MiB before
Game overhead. Built-in PNG movie output is worth investigating to avoid that
application-level array; full-Game memory pressure still remains.

Before implementing a movie path, require a small measured clock experiment:

1. Pin source, engine, seed, viewport, 60-Hz physics and `time_scale = 1`.
   Compare ordinary execution with a short 30-FPS offline run at slow wall speed.
2. Record output frame, physics tick, simulation delta, wall time, enemy stride
   frame and hit-flash state. Confirm route waits, motion, animation and feedback
   agree in simulation time; diagnose differences before recording a trailer shot.
3. Keep any clock adaptation confined to an explicit movie path and leave the
   ordinary probe unchanged. Verify normal probe behavior and zero profile writes.
4. Inspect original output frames, duration, HUD, camera, actor motion and audio;
   encode at the recorded FPS and retain staging/source metadata. Older sampled
   or guarded 20-FPS evidence is not smooth first-trailer footage.

No MovieMaker implementation or capture acceptance is claimed here.
