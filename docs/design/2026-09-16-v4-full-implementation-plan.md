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
| 3a | Finish Execution, Barrage, Distortion omissions (EX12, EXA, BRE1, BRS2, DT05 slow, DTF1, DTE1, DTV2, approximations) | pending |
| 3b | Momentum, Bastion (Melee) | pending |
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
