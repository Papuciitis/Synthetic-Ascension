# City continuity and pacing implementation plan

> **For agentic workers:** Use test-first implementation with disjoint task ownership and a fresh final review. User authorization covers implementation and commit/push; do not reopen permission questions while they sleep.

**Goal:** Make a fresh city attempt retain an appealing final development and make terminal defeat a clear, durable PeeP continuation.

**Architecture:** Saved opt-in pacing in AscensionLedger; a profile-scoped pending continuation and commitment map owned by Global; a standalone themed continuation screen; independently selectable developer farming variants. Preserve existing attempt reset and reconstruction semantics except the explicit commitment replay contract.

**Tech Stack:** Godot 4.7.1, GDScript, existing .tscn test scenes and Arcane UI.

**Spec:** docs/superpowers/specs/2026-10-16-city-continuity-and-pacing.md

## Global constraints

- Preserve unlimited equipment rarity, existing stash rank and old nonempty ledger behavior.
- Revelation access after completed 8; Revelation mutation access after completed 9, revision-1 fresh attempts only.
- Ordinary reconstruction never enters PeeP; pending terminal decisions block gameplay until resolved once.
- Preserve all unrelated working-tree changes and the other chat's history/README work.
- Tests use isolated saves; variants default off and are recorded; no force push.

## Review focus

- An old active save with owned BLINK must remain usable before segment 8.
- A rich stash can fund purchases but cannot bypass fresh-attempt milestone requirements.
- Quitting/reloading a dead attempt must not revive it or lose the pending choice.
- Repeated continuation or milestone callbacks must not duplicate attempts, story closure or Doctrine benefits.
- Removing the strongest Gospel instance must reveal the next strongest without stale Luck contributions.

### Task 1: Fresh-attempt city purchase pacing

Files: core/systems/ascension/AscensionLedger.gd; autoload/global.gd (fresh ledger creation only); ui/screens/AscensionScreen.gd if detail explanation needs it; tools/tests/AscensionCityPacingTest.gd/.tscn.

Interfaces: fresh_state(native, version="v4", pacing_revision=0); revision persisted in ledger dictionary; can_buy supplies user-facing milestone refusal. Existing ownership/effects remain unchanged.

- [x] Add behavioral tests for fully qualified rich builds at completed 6/7/8/9, missing parents/Core, old ledgers and production new-attempt opt-in.
- [x] Observe expected failures, implement acquisition-only checks and compatible production initialization.
- [x] Run new test plus Ledger, V5Rank, Screen, Preset and RuntimeSafety regressions. Review and commit task-owned paths.

### Task 2: Pending PeeP and persistent commitments

Files: autoload/SaveData.gd; autoload/global.gd; scenes/game.gd; ui/screens/base.gd; focused new continuation/commitment tests and relevant AttemptReset test updates.

Interfaces produced for Task 3:
- Global.has_pending_peep() -> bool
- Global.pending_peep_summary() -> Dictionary (name, segment, attempt identifier and optional verified outcome facts)
- Global.begin_peep_continuation() -> void (idempotent)
- Global.accept_peep_continuation() -> bool (true only once; creates one new attempt)
- Global.PATH_PEEP, Global.goto_resume() and Global.goto_game() honor pending before gameplay.
- Additive empty-default profile save dictionaries for pending and committed city choices.

- [x] Add tests showing pending survives write/apply/reload, blocks dead gameplay, preserves failed state until acceptance and resolves once.
- [x] Implement save fields, routing and terminal transition with one story closure; preserve ordinary reconstruction.
- [x] Test/profile committed 3/6/9 choices, stage-only replay, no load duplication, invalid-definition fallback and active legacy choices.
- [x] Run save migration, StoryDirector, AttemptReset, Doctrine and GameOverFallback regressions. Review and commit.

### Task 3: Restrained PeeP scene

Files: new ui/screens/PeePContinuation.gd/.tscn; optional small helper under ui/widgets; tools/tests/PeePContinuationUiTest.gd/.tscn; tools/dev/PeePContinuationPreview.gd/.tscn only if needed for reproducible renders.

Consumes Task 2 interfaces. Scene buttons resolve once then call Global.goto_game, or retain pending and return to menu/quit. Use existing theme, compact retention copy and truthful summary. All input methods choose their focused action; no invisible-button activation or forced long wait.

- [x] Write input/summary tests, observe failure, implement scene and terminal wiring.
- [x] Render normal/reduced-motion and representative small/large windows; inspect images and repair overflow or weak hierarchy.
- [x] Review and commit.

### Task 4: Independently selectable farming experiments and evidence

Files: a small core policy/helper for developer arguments; EnemyDrops.gd; ThreatDirector.gd; ManifestationRunner.gd/ManifestationState.gd as needed; BalanceRecorder metadata; focused fixture tests; docs/audits/2026-10-16-city-continuity-and-pacing.md.

Arguments: --city-no-overtime-drop-bonus, --city-no-overtime-rarity-bonus, --city-gospel-strongest-rewards. Resolve from user args; expose chosen flags as plain metadata. Defaults reproduce existing formulas.

- [x] Add independent behavior tests for unchanged baseline, only-OT omission, strongest unequal Gospel rewards/order/removal and unchanged pressure/other instances.
- [x] Observe expected failures, implement minimal seams and recorder metadata.
- [x] Run fixed deterministic probes and relevant economy/Manifestation regressions; report numerical differences without claiming human pacing validation.
- [x] Record retention contract, source provenance, exact commands/results and next human comparison. Review and commit.

### Final verification and push

- [x] Run relevant combined regressions and parse audit. Perform a fresh whole-change review and fix material findings with regression coverage.
- [x] Recheck usage, inspect task commits and unrelated working-tree changes, inspect remote divergence and push the established branch without force.
- [x] Report commits, checks, behavior changes and remaining human playtest needs concisely.

Verification exception: AuditClosureTest93/0 is not counted as a clean pass because native shutdown crashes/leaks reproduce in the exact pre-change629f941 checkout. The other21suites, final92/0 continuation, post-fix624/0 pacing and509/0 parse checks passed. See the final audit and compact evidence.
