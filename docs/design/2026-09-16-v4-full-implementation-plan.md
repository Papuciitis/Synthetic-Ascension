# V4 full implementation: staged plan and status

Working document for finishing the V4 advancement tree. The matrix
(`docs/design/v4_implementation_matrix.md`, generated from
`tools/design/v4_status.json`) is the per-node truth; this page is the order
of work, the decisions taken, and what each stage verified.

Sources of rules, in priority order:

1. The authored V4 package (`v4 audit and remake.zip`: Full Tree, Start Here,
   Validation) and its verbatim JSON `data/ascension/tree_v4.json`.
2. Review corrections adopted with the user on 2026-09-13
   (`docs/design/2026-09-13-v4-tree-review.md` §10-11): F1 execution
   definition, F3 collectable Debt, F5 Lucky Crit unregistered, F7 chosen-face
   automatic Coin, F8 Fusion Core tags, F11 Payday window, F12 Witness
   one-in-two, F13 boss loop, F14 Reaction Q at G1.
3. Review recommendations not adopted as rules (merge Heat Sink into Coolant,
   Axiom pricing, starter choice) stay recommendations.

The older Follower Ascension proposal (`docs/design/ASCENSION_TREE_SPEC.md`)
is a presentation reference only; none of its economy or node rules apply.

## Stages

| Stage | Scope | Status |
|---|---|---|
| 0 | Read-first: checkout, collaborator commits, recorder, audit, baseline suites | done 2026-09-16 (14 suites green) |
| 1 | Implementation matrix for all 350 nodes and shared rules | done; regenerate after every slice |
| 2 | Stability pass: fragment acquisition, recorder trust, regression coverage, baselines | done 2026-09-16 (see PERFORMANCE_PATCH_CHANGELOG); rendered check deferred to stage 4 |
| 3a | Finish Execution, Barrage, Distortion omissions and the shared rules they hang on | done 2026-09-16 |
| 3b | Momentum, Bastion (Melee) | done 2026-09-16 (66 + 62 checks; BA10 n/a, MOQ5 partial) |
| 3c | Precision, Ordnance (Ranged) | done 2026-09-16 (47 + 63 checks; PRK1 partial) |
| 3d | Invocation, Dominion (Magic) | done 2026-09-16 (59 + 50 checks; DO10 Throw untestable headless) |
| 3e | Remaining 24 Fusions, 3 Unions, milestone picks, Evolution reward timing, action charge, Reaction triggers, Automatic Method | done 2026-09-16 (AscensionFusionTest 50; action table and automatic targeting complete) |
| 4 | Presets per discipline + hybrids through real purchase rules; whole-system tests; frame distributions; rendered checks | done 2026-09-16 (presets_v4.json, AscensionPresetTest, AscensionBuildProbe, docs/audits/2026-09-16-v4-build-checks.md, docs/design/v4_build_test_checklist.md) |
| 5 | Scene/Resource migration boundary note and one-discipline pilot design | done 2026-09-16 (docs/design/2026-09-16-v4-migration-boundary.md; Momentum pilot, design only) |
| 6 | Handoff: verified / implemented-unverified / awaiting playtest | done 2026-09-16 (docs/design/2026-09-16-v4-handoff.md) |

## Decisions and interpretations (recorded as taken)

- 2026-09-16: generated attacks stay data on the runner (no nodes); new
  disciplines follow the same rule. Placed objects (Mines, Sigils, Wells,
  Coordinates, Shells) are engine data drawn by the runner, not scenes.
- 2026-09-16: engines declare an explicit effect table (node id -> effect
  identifier) so authored definitions can later move to Resources that
  reference behaviours by id rather than by display text (stage 5 boundary).

- 2026-09-16: keystone and Mark damage rules run through an explicit
  outgoing-damage hook on EnemyCombatService instead of heal-backs; a
  reduction applies to the whole hit including a consumed Mark's +0.5D.
- 2026-09-16: REWRITE's "normals' melee swings miss" reads as contact damage
  or a normal enemy within 1.5R of the player; elite and boss attacks land.
- 2026-09-16: Only the Weak / One at a Time treat the Core hit that marks an
  unmarked target as marked (authored: application precedes evaluation).
- 2026-09-16: Ascendant's two Revelations have independent meters; kills and
  actions fill both; tap casts the selected (alternating) or the ready one.
- 2026-09-16: Doctrine pick Fortune (reward reroll) is out of the combat
  scope; Wild Card is moot because a claim can already buy any qualified
  Evolution. Both recorded in the matrix.
- 2026-09-16 (3b): Momentum claims the existing Manifestation pool as V4
  asks; its 0-1 value is read as 0-100, its travel fill and still-bleed stay
  as tuned for items, and the engine adds V4's dash producer (+15). No
  Brakes' 100-150 overflow lives in the engine. Dash-shaped effects use the
  player's real dash (160 px) while ranges use L = 240.
- 2026-09-16 (3b): Lunge counts as a dash, so it also grants the +15; under
  Burnout the pool therefore reads 15 after a Lunge, not 0.
- 2026-09-16 (3b): Immovable (BA10) has no trigger: nothing displaces the
  player. It stays purchasable with no effect and is recorded n/a rather
  than given a replacement mechanic. Aftershock's "reverse knockback" is
  likewise moot (RUPTURE staggers by stun).
- 2026-09-16 (3b): Bastion prevention (Guard, Plate, Anvil, Glass Armor) and
  armor changes (Glass Armor, Armor sink, Zero Armor) are expressed through
  the per-source incoming-damage multiplier; Thorns reads the prevented
  share of that hit. Meltdown's third ring applies Thorns' virtual 20%-max-HP
  block to enemies within R, since a virtual hit has no source.
- 2026-09-16 (3b): Last Hit's intercepted blow grants no Force (it empties
  the pool by rule); Return to Sender's caught Force is then spent by Stored
  Force on the same strike when both are owned.
- 2026-09-16 (3b): Carry (MOQ5) drags one normal now; friendly Mines, Sigils
  and Wells follow once Ordnance/Invocation exist (partial until 3c/3d).
- 2026-09-16 (3c): projectile behaviours the tree needs (pierce damage ramp,
  terrain bounce, seeking within a turn budget, direction offset, and an
  end-of-flight report with the path flown) live in
  ProjectileSimulationManager as per-slot data set from HitProfileAdapter
  fields; reports are delivered after the simulation step so a listener
  that spawns replacements never races the swap-remove. Hit records carry
  the projectile id, direction and targets crossed.
- 2026-09-16 (3c): a Weak Point is a runner status plus an engine-owned
  expiry (3 s); the runner's status sweep only clears dead enemies.
  Consumption and Read happen in one on_hit pass with the rule "the hit that
  exposes never consumes" enforced by ordering.
- 2026-09-16 (3c): Return Shot returns along the last leg (a bounced path
  reverses its final segment, then continues straight). With both Return
  Shot and Smart Rounds owned, the return takes precedence over the
  edge return. Deadshot and JUDGEMENT slow world time through
  Engine.time_scale with a real-time budget kept by the runner; automatic
  and Reaction casts of Deadshot pick the densest line through aim with no
  pause. JUDGEMENT's lines are placed by attack presses during the pause
  (a line runs across the screen through the player and cursor); tests
  place them directly.
- 2026-09-16 (3c): One Bullet's "+0.4D and +R/8 per extra projectile of the
  same volley" is not applied to Barrage's side rounds (partial, recorded).
- 2026-09-16 (3c): every blast is an impact on the runner's queue tagged
  "cast:blast:N"; the engine keeps centre and radius so Blast Pull,
  Fracture, Spotter, Danger Close and the action-charge rules resolve from
  the hit record. Mines trigger on an enemy within 22 px after arming.
  Shells fall 0.6 s (Big One 0.9 s, FIRE MISSION 0.2 s after its 1 s grid
  tell, Bunker Buster fixed 0.2 s before landing). "Occupied cell" is an
  80 px grid cell holding an enemy. Rolling Thunder's lanes are six
  horizontal lanes across the camera rect.
- 2026-09-16 (3c): Designate is a held Q: tap places, tap on a Coordinate
  fires, hold 0.35 s places and fires; Fire Again's dormant Coordinates
  reactivate when the runner's Q cooldown reaches zero. Fuse (axiom) hangs
  on a new on_q_activated engine hook the runner calls after any Q cast.
- 2026-09-16 (3d): Sigil pulses resolve inside the engine (so Chain Pulse
  and Choir know the distinct-hit count) and are drawn through a runner
  impact effect; Echo releases reuse the runner's Core-strike geometry
  toward the nearest enemy. A pulse that missed its interval catches up
  within one tick (THE HOST's triple speed). Blood Rune's healing cut is a
  new engine heal_multiplier read by player.heal after the Doctrine
  multiplier.
- 2026-09-16 (3d): forced movement (Wells, Compel, Collapse, KNEEL) is
  stepped by the engine through the runner's enemy move primitive with a
  terrain contact check (Throw) and a 14 px crossing check (Collision /
  Dragnet) per step; since everything in a Well moves at one speed, a
  trailing body only crosses one that has stopped. "Stagger" is a stun: a
  boss converts L of resisted travel into 0.5 s; KNEEL's boss slam adds
  0.4 s. Only elites and bosses "resist" (a normal that has used its travel
  simply rests, storing no Weight). Repulse shoves the cone away from the
  player and the Ring away from its centre.
- 2026-09-16 (3d): KNEEL pulls at 900 px/s until every caught normal has
  arrived (at most 1 s), holds 0.5 s (Orbit: 1.5 s), then slams; Again
  waits 1 s after the throw and pulls back the same way. Throw (DO10)
  cannot be exercised headless: the test world has no terrain, so it is
  recorded partial pending a rendered check.
- 2026-09-16 (3d): weighted-hit counters (Leave a Sigil, Gravity Well,
  Impact Fuse) compare with a 0.0005 epsilon so ten hits at Proc Power 0.4
  reach four.
- 2026-09-16 (3e): a Fusion runs in the engine that owns its trigger and
  reaches the partner through runner.engine_of_discipline; every cross-call
  is null-guarded so a Fusion whose partner engine is absent does nothing.
  Unions route to a UnionEngine ("UN") the runner builds when any Union is
  owned. Engines report Jams, full Force discharges and executions to
  runner.note_union_trigger for TOTAL OFFENSIVE.
- 2026-09-16 (3e): Slingshot's arc is approximated (the player is mirrored
  across the Well's centre, then dashes R toward aim). Blood Rite raises the
  line through a per-target status Execution reads; executions are
  reported by Execution rather than inferred from kill tags. Backtrack adds
  damage to the live projectile through a new manager helper. Rune Bomb's
  partner detonation is recursion-guarded on the Ordnance side. INCARNATE
  carries the newest Sigil and Well (their own timers keep running, as the
  rule states); "10% max HP taken" counts applied damage, not prevented.
- 2026-09-16 (3e): headless tests now wait by resolved projectiles or by
  distance travelled instead of frame counts: headless frames run as fast
  as the machine allows, so a fixed frame count covered 4-12 px per frame
  depending on load, and two suites flapped when another process ran.
- 2026-09-16 (4): presets are derived from the authored builds in
  tree_v4.json (early = the route's first four locals, developed = through
  the Q, its first mutation and the fork, pure = the authored build plus the
  keystone that touches it) and the review's hybrids; they live in
  data/ascension/presets_v4.json, replay through the real purchase rules in
  AscensionPresetTest, and the dev overlay's route loader lists and equips
  them. Ordnance's pure preset takes Spotter: Danger Close sits beside Chain
  Reaction and Blast Pull, which the authored route does not buy.
- 2026-09-16 (4): the scripted preset fights and the build probe measure
  process deltas and wall spacing per frame; headless numbers are labelled
  HEADLESS everywhere and bound the simulation only. The first measured
  frame of a preset fight includes the 60-body spawn burst, so the max is
  read with that in mind and p95/p99 carry the judgement. Rendered runs
  use the machine's real display (DISPLAY :0, Intel UHD 620, OpenGL) and
  sit at a 16.7 ms median by vsync; their p95/p99/max and draw-call median
  are the comparison.
- 2026-09-16 (4): a runner that re-enters the tree rebuilds its engines
  (_enter_tree), which the scene-transition check needed; a reparented
  player previously kept an empty engine list until the next refresh.
- 2026-09-16 (3c): AscensionBarrageDenseBenchmark's single-frame "max
  fragment update < 12 ms" bound proved noise-driven (baseline runs of the
  committed 3b state span 8.8-16.7 ms while p95 stays 4.9-5.4 ms); the
  guard now checks p99 and the kill-count floor reflects the unseeded
  chain's spread. No throughput change: p95 5.0-6.0 ms after 3c.

## Verification log

- 2026-09-16 baseline on 31a84e4 + local: AscensionLedgerTest 71,
  AscensionRunnerTest 29, AscensionBarrageTest 38, AscensionExecutionTest 30,
  AscensionDistortionTest 38, AscensionHybridTest 41, AscensionScreenTest 18,
  AscensionRuntimeSafetyTest 18, AscensionChainBurstBenchmark 6,
  BalanceLedgerTest 17, BalanceCaptureWriterTest 7, BalanceRecorderTest 20,
  GroundLootCapTest 6, LoadingScrimTest 6; all 0 failed. Machine: Intel
  i7-8650U, 8 threads, 31 GB, Godot 4.7.2 headless; display :0 available for
  rendered checks (Intel UHD 620).
- 2026-09-16 stage 2: EnemyLowestHealthQueryTest 10, AscensionBarrageDenseBenchmark
  6, FlightRecorderSampleTest 6, PerformanceFlightRecorderTest 48,
  EnemyCombatQueryTest 19, AscensionBarrageTest 38, AscensionHybridTest 41,
  AscensionRuntimeSafetyTest 18; all 0 failed. Numbers in the changelog.
- 2026-09-16 stage 3a: AscensionSharedRulesTest 30, AscensionSliceCompletionTest
  23, plus the nine earlier ascension suites unchanged; ScriptParseAuditTest 395.
- 2026-09-16 stage 3b: AscensionMomentumTest 66, AscensionBastionTest 62; the
  full set (Ledger 71, Runner 29, Barrage 38, Execution 30, Distortion 38,
  Hybrid 41, Screen 18, RuntimeSafety 18, SharedRules 30, SliceCompletion 23,
  ChainBurst 6, BarrageDense 6, LowestHealth 10, FlightRecorderSample 6,
  BalanceLedger 17, BalanceCaptureWriter 7, BalanceRecorderLoad 5,
  GroundLootCap 6, LoadingScrim 6) 0 failed; ScriptParseAuditTest 397.
  Matrix: 178 implemented, 6 partial, 5 n/a, 160 missing, 1 ambiguous.
- 2026-09-16 stage 3c: AscensionPrecisionTest 47, AscensionOrdnanceTest 63;
  the full set unchanged (Momentum 66, Bastion 62, EnemyCombatQueryTest 19
  added to the run); ScriptParseAuditTest 399. Dense benchmark compared
  before/after (see decisions). Matrix: 244 implemented, 7 partial, 5 n/a,
  93 missing, 1 ambiguous.
- 2026-09-16 stage 3d: AscensionInvocationTest 59, AscensionDominionTest 50;
  the full set unchanged; ScriptParseAuditTest 401. Matrix: 309
  implemented, 8 partial, 5 n/a, 27 missing (24 Fusions, 3 Unions), 1
  ambiguous.
- 2026-09-16 stage 3e: AscensionFusionTest 50 (24 Fusions, 3 Unions); the
  full set green; ScriptParseAuditTest 402. Matrix: 336 implemented, 8
  partial, 5 n/a, 0 missing among nodes (one shared row, control
  conversions, stays missing), 1 ambiguous.
- 2026-09-16 stages 4-6: AscensionPresetTest 246 (37 presets at real
  prices, 37 scripted crowd fights, whole-system checks); the full set
  green (Ledger 71, Runner 29, Barrage 38, Execution 30, Distortion 38,
  Hybrid 41, Screen 18, RuntimeSafety 18, SharedRules 30, SliceCompletion
  23, Momentum 66, Bastion 62, Precision 47, Ordnance 63, Invocation 59,
  Dominion 50, Fusion 50, ChainBurst 6, BarrageDense 6, LowestHealth 10,
  FlightRecorderSample 6, EnemyCombatQuery 19, BalanceLedger 17,
  BalanceCaptureWriter 7, BalanceRecorderLoad 5, GroundLootCap 6,
  LoadingScrim 6); ScriptParseAuditTest: 402 passed, 0 failed. Build probe: ten headless
  and three rendered runs in docs/audits/2026-09-16-v4-build-checks.md.
  Matrix: 336 implemented, 8 partial (control conversions and HUD now
  recorded partial rather than missing), 5 n/a, 1 ambiguous.
