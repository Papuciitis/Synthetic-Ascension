# Segment 5 teaching fights implementation plan

> For agentic workers: use subagent-driven development for disjoint boss tasks. Root serializes all Godot runs and owns review, staging, commits and pushes. User explicitly authorized execution of delivery step 3; continue without another design-approval round.

**Goal:** Make both random Segment 5 minibosses teach compact, honest patterns with baseline walking escape routes and meaningful melee openings.

**Spec:** `docs/design/2026-10-16-boss-overhaul-proposal.md`, S5 moveset tables and delivery step 3. Builds on the verified step 1/2 geometry, ownership, proportions, courts and raster assets.

**Architecture:** Keep the existing boss brains and AttackScope. Give S5 explicit commitment/recovery clocks, fixed captured geometry and bounded pattern ownership; S10 keeps its current kit for later phase work. Charge owns one physical rush-contact rule, and the player's ordinary contact ledger excludes that boss while this rule owns contact. New arrival cues are finite Sprite2D effects with the same source cancellation contract.

**Tech:** Godot4.7.1, GDScript, built-in ImageGen transparent PNGs, existing isolated enemy-world worktree and SFX bus.

## Constraints and rulings

- Retain seeded random boss choice, existing HP/rewards, unit body scales and physical footprint. No forced fight duration or adaptive health.
- Actual baseline human melee speed is100 worldpx/s (ranged115), despite the script's300 export. Measure production effective speed and capsule for escape tests.
- Starting S5 tuning: rush0.85s tell /0.9s recovery; slam1.3s tell /0.9s recovery; fault line1.35s initial tell,0.32s between three releases /0.9s recovery; reinforcement1.0s arrival tell, one wave of3 below50%HP. Longer tells than the original hypotheses are justified by actual baseline speed.
- Starting mage tuning: focused fan0.95s tell /0.9s recovery, five bolts in46degrees at320worldpx/s with520worldpx visible range; blink0.8s tell /1.2s recovery and at least6.5s cooldown, landing approximately180–210px from target; three mines after0.6s planting tell,1.4s persistent fuse, at most5 unresolved. Tests and rendered motion may justify conservative adjustments, recorded in the audit.
- One major spatial demand at a time. Mines settle before another mage pattern; no tracking/retargeting after commitment. No blink during another cast or recovery.
- Rush trail and endpoint are cosmetic, including the shared legacy end effect in S10. Ordinary Chargers retain their current behavior. No extra contact tick stacked with boss rush damage.
- Full body validation for blink and Runner arrivals; validate actual surrounding world geometry rather than assuming the entire leash is the clear court. Unavailable placement skips safely.
- Fault Line previews every node before the first release, with visibly ordered timing. Mines use a deterministic open arc with a capsule-safe corridor, rather than random encirclement.
- S5 Arcanist gets no new reinforcement move. Existing ambient targets remain available; verify kill-trigger access with a bounded ambient fixture. No spawner suppression/deletion policy or unrelated crowd redesign.
- All combat VFX remain actual raster sprites. Reuse appropriate existing sprites; generate dedicated blink/arrival art with built-in ImageGen. Do not add particles, Line2D or procedural combat drawings.
- Source cancellation, pause, stun, death, disengage and scene cleanup remain mandatory. Decorative Off/Reduced Motion retain essential warnings. Keep all profile writes isolated.
- Finished character animation and S10 phase/controller redesign remain later work. Sprite acting cues can show commitment/recovery without claiming finished animation.

## Review focus

1. A player already touching a boss can leave the dangerous footprint at100px/s without mandatory dash.
2. Body+Area contact duplicates and long frames cannot stack ordinary contact with a rush or hit repeatedly during one rush.
3. Repeated low-health callbacks, stunned arrival casts and failed placements cannot replenish adds or leak reservations.
4. Blink full-body fits, arrival separation and mine corridors remain valid beside walls and near the court edge; no instantaneous harmful placement.
5. Recovery actually holds movement and new casts while still allowing incoming melee damage, and existing ordinary enemies/S10 routing remain compatible.

## Task 1 — Bulldozer teaching kit

Owner: tank implementer. Files: `BossBulldozerBrain.gd`, `EnemyCharge.gd`, narrow player contact ledger hooks in `core/actors/player/player.gd`; new `tools/tests/BossBulldozerTeachingTest.gd/.tscn`.

- [x] Write actual cast/physics/contact regressions for fixed rush direction, harmless crumbs/end, exactly one physical rush hit, ambient contact compatibility, planted slam/recovery, full three-node previews/order, one warned finite Runner wave and cleanup.
- [x] Root observes valid RED before production edits.
- [x] Implement S5 explicit clocks and movement locks, finite reinforcement consumption, body-validated arrivals and shared cosmetic rush endpoint. Preserve ordinary Charger behavior.
- [ ] Verify focused suite plus contact, charge, boss lifecycle/identity/audio/ownership suites. Independently review; commit and push coherent checkpoint.

## Task 2 — Arcanist teaching kit

Owner: mage implementer. Files: `BossArcanistBrain.gd`, narrowly `BossMine.gd` if unresolved bookkeeping requires it; focused placement helper if useful; new `tools/tests/BossArcanistTeachingTest.gd/.tscn`.

- [x] Write real fan/blink/mine regressions with captured origins/directions, actual range, recovery locks, deterministic corridor, mine cap, full-body wall rejection and pause/interruption cleanup; root observes RED.
- [x] Implement tier-specific timing/pressure gating, announced validated blink and deterministic three-mine arc. S5 cannot select beam/pylons. Preserve S10's current selection for later work.
- [ ] Verify focused suite plus old cast/geometry/audio/ownership regressions. Independently review; commit and push checkpoint.

## Task 3 — Shared sprite arrival cues

Owner: root. New `scenes/world/bosses/BossArrivalSprites.gd` exposes `setup(world_pos:Vector2,radius:float,duration:float,kind:StringName)` with `blink`/`summon` kinds, `set_progress(value:float)` and `cancel_attack()`. It uses actual transparent PNGs in boss art/VFX, world-anchored and bound through AttackScope. Caller gameplay clocks own release; no damage in this helper.

- [x] Write expiry, world-origin, pause, source cancellation and accessibility regressions in `BossArrivalSpritesTest.gd/.tscn`; observe RED before helper production code.
- [x] Generate, inspect, measure and copy unchanged dedicated blink/Runner arrival sprites; preserve prompts, source hashes and import settings.
- [x] Implement fixed-radius, persistent essential ground cue with finite non-flashing progress, then wire both brains through the agreed interface.
- [ ] Verify focused test and rendered normal/small-window samples with no procedural combat effect primitives.

## Task 4 — Actual fight/escape evidence and integration

Owner: visual/probe implementer after brain interfaces settle. New actual Game S5 probe and focused escape/build-access tests under tools/dev and tools/tests.

- [ ] Run representative seeds for both roles, evaluate reachable escape trajectories with the real player's capsule/effective movement and dense ordinary geometry near boundaries. Include slow/baseline walking, dash unavailable, melee pursuit and ambient kill-trigger targets.
- [ ] Capture real timed anticipation/release/recovery for both choices at1280×720 and960×540 with normal camera, player, terrain and HUD. Use isolated profile; record actual damage outcomes and save-write counts. God mode cannot establish avoidability.
- [ ] Separate automated geometry/correctness from human satisfaction, visual timing and final mix approval. Keep damage-observing fixtures separate from optional immortal capture-only playback.
- [ ] Final scoped independent review, appropriate compatibility tests and ScriptParseAudit last. Update audit/roadmap/evidence/plan; commit/push all owned work and verify remote HEAD, preserving unrelated dirty edits.
