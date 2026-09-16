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
| 3c | Precision, Ordnance (Ranged) | pending |
| 3d | Invocation, Dominion (Magic) | pending |
| 3e | Remaining 24 Fusions, 3 Unions, milestone picks, Evolution reward timing, action charge, Reaction triggers, Automatic Method | pending |
| 4 | Presets per discipline + hybrids through real purchase rules; whole-system tests; frame distributions; rendered checks | pending |
| 5 | Scene/Resource migration boundary note and one-discipline pilot design | pending |
| 6 | Handoff: verified / implemented-unverified / awaiting playtest | pending |

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
