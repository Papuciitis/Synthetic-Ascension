# Segment 5 teaching fights

Implements delivery step 3 from the approved boss overhaul. Random Bulldozer/Arcanist choice, existing production health/rewards and the step 2 body/arena contracts remain. The two teaching implementations and focused suites are committed in `0a2a27c7`. Compatibility checks, actual Game controls and rendered motion evidence remain pending; S10 phase redesign is later work.

## Bulldozer

The teaching kit consists of a fixed-direction rush, a planted slam, a fully previewed three-impact Fault Line and one below-half-health Runner call. Recovery holds movement and new attacks while leaving the boss damageable.

| Action | Committed tell and geometry | Payload and opening |
|---|---|---|
| Committed Rush | 0.85 s tell, fixed direction, 780 world px/s for 0.36 s: 280.8 px maximum unobstructed travel. Lane width matches the physical boss diameter. | One physical-body intersection hit per rush, authored raw 10 damage with the existing Threat contact multiplier; 0.9 s recovery. Trail and endpoint are cosmetic at both tiers. |
| Planted Impact | 1.3 s tell, fixed 135 px-radius footprint at the captured origin. | Authored raw 18 damage, 0.18 s payload; 0.9 s recovery. |
| Fault Line | Three 85 px-radius footprints at 140 / 280 / 420 px along the captured direction, all previewed before release. Impacts occur at 1.35 / 1.67 / 1.99 s. | Authored raw 10 damage per node, 0.16 s payloads; 0.9 s recovery after the third release. |
| One Runner call | At or below 50% HP, one 1.0 s arrival tell at up to three validated positions 120 px around the captured origin. | At most three actual Runners from the single consumed attempt, subject to body clearance and population limits; 0.9 s recovery. Unclaimed Runners expire after 15 gameplay seconds without kill rewards. |

The Runner opportunity is consumed on commitment, including interruption or failed placement; blocked positions are skipped rather than guaranteeing three arrivals. Source cleanup and existing population reservations remain in force. Rush, slam and Fault Line availability clocks advance during idle selection, with authored resets of 3.6 / 3.6 / 5.2 s respectively.

The Tank's ordinary contact contribution is suppressed throughout its non-idle S5 states, including recovery. Body/Area overlap records stay balanced, while dead, queued and suppressed records add no damaging swarm weight. Other enemies retain ordinary contact pressure. The rush uses its one explicit physical hit rule rather than stacking another boss contact tick.

## Arcanist

The compact S5 kit uses a locked five-bolt fan, an announced body-validated blink and a deterministic three-mine constellation. Major patterns do not overlap: live fan bolts, mines and mine detonation payloads settle before another major pattern starts.

| Action | Committed tell and geometry | Payload and opening |
|---|---|---|
| Focused Fan | 0.95 s tell; five fixed raster ray lanes and five bolts over 46 degrees, captured origin/direction, 320 world px/s and nominal 1.625 s life = 520 px travel. | Authored raw 7 damage per bolt; 0.9 s recovery. |
| Announced Blink | 0.8 s departure/landing tell. Deterministic search among eight candidates exactly 195 px from the captured player position; full body, player separation, loaded/world geometry, pursuit corridor and mine checks. | Advertised destination is revalidated at release and skipped safely if invalid; 1.2 s recovery and at least 6.5 s between blink commitments. |
| Mine Constellation | 0.6 s planting tell; three fixed nodes 210 px from the captured player center, at +60 / 180 / -60 degrees relative to the chosen escape axis. A 240 px escape corridor uses conservative full-Hurtbox clearance plus an 8 px margin. | Each mine keeps its glyph through a 1.4 s fuse, then releases a 95 px-radius, authored raw-15-damage payload for 0.15 s. Planting opens 0.9 s recovery; live pressure still gates the next pattern. |

The blink distance describes the captured target, not a player who moves during the tell; the destination never silently follows that movement. Mine placement checks a hard unresolved-owned-mine cap of five, while normal one-pattern selection yields three at a time. Captured geometry is checked again before release. Pattern ordering uses the attempt seed, segment, boss home and accepted-pattern counter rather than actor IDs or wall time.

Neutral steering gets one bounded reposition between commitments: at most 1.0 s or 80 px accumulated movement, then the Mage stands its ground. Fan/mine availability clocks reset to 2.8 / 4.8 s, but cannot bypass recovery or live-pressure gating. Blink cannot start during another cast or recovery. S5 cannot select beam/pylon pressure. Production ambient policy is unchanged; Arcanist receives no new reinforcement move.

## Gameplay clocks, interruption and compatibility

Both S5 brains advance commitments and recovery on accepted gameplay physics time; S5 `BossMine` fuses use the same clock as native walking. Essential warnings remain until the controller releases or cancels them. `BossArrivalSprites` has a finite autonomous physics lifetime and a no-op render callback. Both brains disable its autonomous callbacks when driving committed progress themselves. The helper creates no damage or actors.

A brief stun cannot remove an already-earned recovery. The Tank retains the opening on its physics clock; the Mage pauses its remaining recovery while stunned. Both check the originating `BossAttackScope.generation`, so full cancellation still clears movement locks and pending cues. Death, disengage, scene exit and scope cancellation retain source-owned cleanup.

The committed rush's final partial step scales velocity by the remaining fraction of that physics step, matching its preview rather than adding a whole final tick. This clamp applies only to the new committed-speed path. Ordinary Chargers and S10 retain their existing selection paths; the shared Tank trail/endpoint becoming cosmetic is intentional. New S10 phase/controller design is not part of this delivery.

The Mage's small attached casting accent still has its autonomous render lifetime. Its essential fan lanes, mine ground warnings and blink destinations remain controller-owned. This is a presentation limit, not a claim that every sprite accent shares the physics clock.

## Why the tells are longer

The production human melee character moves 100 world px/s, with a radius-25 / height-58 walking capsule and a 70 × 70 damage Hurtbox. The player script's 300 export is not the effective run speed. Starting at legal physical body contact, leaving the 135 px slam requires a player center beyond 170 px. With a 150 ms reaction allowance, a 1.15 s tell is too short. Full square-corner geometry also leaves almost no frame margin for a 1.25 s Fault Line tell. The chosen 1.3 / 1.35 s tells provide conservative room; actual Game physics controls must verify them.

Circular hazards/projectiles use the complete square Hurtbox; the rush deliberately queries physical body intersection. Placement conservatively encloses the square in approximately 49.5 px clearance before adding corridor margin. These are baseline movement checks, not guarantees for slow or immobilized builds or a substitute for human difficulty testing. No slowed-player probe, minimum fight duration or adaptive health is added.

## Raster assets

Two dedicated built-in ImageGen PNGs distinguish cyan/ivory blink destinations from warm Runner arrival marks. Their source pixels are copied unchanged. Original canvases are 1254 × 1254, with painted radii 582.7061867 / 588.2401720 measured at alpha > .2 for runtime fitting. Blink has one negligible corner pixel with alpha 1/255; the center and background are transparent. No external crop, repaint or alpha removal is applied.

[Exact prompts](../art/2026-10-16-s5-arrival-prompts.json) and [source/alpha measurements](evidence/2026-10-16-s5-teaching-fights/arrival-art-measurements.json) retain provenance. Arrival cues are finite non-damaging Sprite2D components bound to their boss's AttackScope. Existing fracture, crackle, mine, charge and pulse sprites remain the visual vocabulary. Final character animation and human timing/mix approval remain distinct from these mechanics and sprite cues.

## Verification status

Valid pre-implementation regressions: Bulldozer 9 passed / 28 failed, Arcanist 3 / 27 and arrival component 0 / 1. These expose missing teaching behavior rather than being counted as successful final checks.

| Completed focused suite | Result | Evidence |
|---|---|---|
| Bulldozer teaching | 54 passed / 0 failed; engine exit 0 | [Final log](evidence/2026-10-16-s5-teaching-fights/BossBulldozerTeachingTest-green.log) |
| Arcanist teaching | 41 passed / 0 failed; engine exit 0 | [Final log](evidence/2026-10-16-s5-teaching-fights/BossArcanistTeachingTest-green.log) |
| Shared arrival component | 20 passed / 0 failed | [Final log](evidence/2026-10-16-s5-teaching-fights/BossArrivalSpritesTest-green.log) |
| New probe scripts, normal autoload context | 2 loaded / 0 failed; engine exit 0; compile evidence only | [Load log](evidence/2026-10-16-s5-teaching-fights/S5TeachingProbeLoadTest-green.log) |
| Measured-timing video encoder | 8 passed / 0 failed, including actual FFmpeg packet timing and final duration | [Encoder log](evidence/2026-10-16-s5-teaching-fights/capture-encoder-green.log) |

The arrival suite covers world anchoring, distinct raster sources, pause, cancellation, essential accessibility visibility and gameplay-clock expiry. Its render-only callback regression failed 19 / 1 before moving autonomous lifetime onto physics. A natural low-FPS control also passes; it alone did not reproduce the callback discrepancy because of engine frame-delta clamping.

Independent source review identified committed rush final-step overshoot (286 px at 60 Hz and 312 px with 0.1 s scheduling versus the 280.8 px preview), early render-clock warning/arrival expiry, shortened recovery after a brief stun, queued-contact swarm weight and cancellation-generation handling. Focused regressions failed before correction. Final scoped source re-review found no remaining material P1/P2 in the reviewed teaching logic and guards. The diagnostic file named `BossBulldozerTeachingTest-first-green.log` records 44 / 1 and is not final passing evidence.

Compatibility suites, actual Game escape/melee/build-access controls, final script audit and new rendered motion evidence remain pending. Engine verification is serialized with the other game chats under the human's explicit coordination authorization, to avoid simultaneous memory-heavy runs.

The first actual-Game smoke launch stopped at an unresolved probe base class before any gameplay assertion. The normal-autoload loader exposed two type-inference errors in the new preview (`mine_offset` and `boss_owned`); explicit Vector2/bool annotations corrected them. Both preview and escape scripts now load successfully. The retained diagnostic/smoke logs are failed setup evidence, not avoidance results. Production Game source was not changed for this correction.

## Actual Game controls and capture limits

`tools/dev/S5TeachingFightPreview.tscn` uses the actual Game scene, generated S5 court, production player, normal camera/HUD and native movement/aim/attack input. Its inherited `tools/tests/S5TeachingEscapeTest.tscn` arranges controlled casts through the real brain interfaces, then observes real process/physics clocks and damage resolution. Actor and brain callbacks stay disabled during initial placement and are explicitly enabled for combat. The live controller captures one signed sidestep from the production committed direction, retaining it and the reaction clock through `rush_tell` → `rush` rather than reversing each tick at the court center.

Authored paired cases use production 100 px/s walking with a 150 ms reaction allowance and dash unavailable, stationary controls, separate native-dash cases, native melee hits during recovery, and one prescribed real court-edge slam. Defaults cover seeds 16102026 and 16102027; execution results are pending. Mine controls must observe all three actual boss-owned `BossMine` instances and three real mine `DamageCircle` payloads per stay/walk attempt, so a skipped plant cannot pass as a safe constellation. A stationary mine control need not take damage because the center and corridor are deliberately safe. Hazard attempts are counted separately from HP loss, preventing native invulnerability/mitigation from concealing an intersecting path. These cases are not exhaustive wall, angle, crowd or slowed-build coverage.

The Mage kill-trigger case uses the actual normal spawner/table with a disclosed initial batch of up to six and ambient cap eight, plus the connected EX01 → EX03 → EX06 fixture loadout. It requires genuine player-attributed normal kills and actual Execution/Cleave activation. These are controlled ambient targets, not Mage reinforcements. Default isolated captures disable ambient for readability; production spawning is unchanged.

Optional `--boss-hp-ratio=0.49` controls starting current health after real arena configuration, retains production maximum health and injects no damage/kill event. Captions and metadata disclose the threshold condition, including initial/max HP. The actual Tank controller selects its finite warned Runner call naturally. Native kill events retain `special_spawn_kind` to distinguish real `boss_add` Runner kills; an isolated live capture does not automatically receive the ambient Cleave loadout. A Runner kill count alone cannot establish Cleave activation.

The dedicated Tank `--case=adds` access control, also selected by the default escape suite, is authored separately from isolated playback. It starts at a disclosed 49% HP with the connected EX01 → EX03 → EX06 fixture loadout, enables no ambient spawns, and lets the actual controller select its warned Runner wave. Genuine native Runner kills and an increase in the real Cleave counter are required. Its runtime outcome remains pending; these actors are the Tank's production reinforcement move, not injected fodder.

The fixtures isolate save selection/directories and recorders before Game readiness, disable autosave and use nonpersisted runtime settings. Final telemetry must confirm zero save writes for each run; authored isolation is not itself a runtime result. Default live output is ignored under `.superpowers/sdd/s5-teaching-fights/live`; root selects unique evidence directories for actual runs.

Live rendering keeps a 1920 × 1080 canvas with 1280 × 720 or 960 × 540 windows and normal camera zoom. Frames are buffered during combat, written afterward, and carry both simulation and measured wall timestamps in `capture-info.json`. Video encoding must preserve those measured VFR intervals rather than accelerate a slow run to the requested sample rate. Export time is excluded from combat duration. Audio is muted, and this is not a performance benchmark.

Optional immortal playback is explicitly labelled and cannot establish avoidability. Actual Game controls and new captures are still pending. Frozen step-2 samples do not prove these teaching clocks. Automated geometry/correctness, observed live outcomes, dense human readability, final animation, pacing and human sound-mix approval remain separate forms of evidence.
