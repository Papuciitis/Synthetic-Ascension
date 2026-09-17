# Core Balance Recorder Implementation Plan

> Execute inline in the existing isolated worktree. User approved the core scope
> and commits; continue through verification without another design approval.

**Goal:** Produce trustworthy local economy/combat reports from ordinary play.

**Architecture:** A pure ledger reduces events into segment totals and bounded
history. An autoload binds runtime events and lifecycle. A background writer
exports immutable batches and readable reports.

**Tech Stack:** Godot 4.7 GDScript; existing threaded report queue; no dependencies.

**Spec:** docs/superpowers/specs/2026-09-16-core-balance-recorder-design.md

## Tasks

- [x] Ledger and writer: add `core/systems/telemetry/BalanceLedger.gd` and
  `BalanceCaptureWriter.gd`; drive with `BalanceLedgerTest` and
  `BalanceCaptureWriterTest`. Test 100 opening + 50 recruitment - 20 purchase
  + 20 refund = 150 closing, with 50 earned / 20 spent / 20 adjustment.
  Test a 100-damage hit on 25 HP records 25 removed and 75 overkill; a paused
  interval does not add to enemy time-to-kill. Check bounded history keeps
  exact totals and exposes dropped-record count. Commit the tested foundation.
- [x] Runtime: add `autoload/BalanceRecorder.gd`; register it in project.godot.
  Add observational lifecycle signals to Global and EnemyWorld, detailed
  player damage/heal/stat/life events to RunEvents, and bind at game entry.
  `BalanceRecorderTest` exercises real damage, healing, wallet operations,
  segment completion, reset, and exported files. Preserve existing signals.
- [x] Build identity: resolve `.git` indirection in BuildInfo so this worktree's
  recordings name the actual commit; verify with BuildInfoTest.
- [x] Delivery: document automatic use, file locations, timing definitions,
  coverage and loss indicators. Run appropriate regression suites, measure
  hot-path cost, run ScriptParseAuditTest last, review the diff, and commit.

Commands use the installed Godot console executable with `--headless --path .`
and each `res://tools/tests/<Suite>.tscn --quit-after 3000`. Import new scripts
before suites. Verify the process exits and reports zero failures; a timeout or
missing summary is a failure. Only the editor is running at baseline.

## Verification results — 16 September 2026

All suites exited 0. Functional assertions: BalanceLedger 17, CaptureWriter 7,
BalanceRecorder 20, RecorderLoad 5, EnemyCombatService 38, HealingLock 41,
RunSheetLedger 77, EnemyDeathEvent 10, PlayerContactSource 11, SaveIntegrity 62,
BuildInfo 11: **299 passed, zero failed**. ScriptParseAudit checked **395 scripts,
zero failures**; it emitted RID/ObjectDB/resource leak diagnostics on shutdown.
Writer and save suites deliberately exercise invalid files and report expected
filesystem/parse diagnostics before successful assertions.

The 100,000-hit ledger microbenchmark took 855,882 microseconds (8.559 us/hit)
on this machine, retained a single combat metrics window, and preserved exact
totals. This is a ledger microbenchmark, not a full rendered gameplay frame-time
guarantee. A real slow-writer fixture verified the two-batch queue cap and all
40 transactions surviving final drain exactly once.

Independent review found post-registration elite/boss HP changes and final
partial-write status gaps. Failing regression cases reproduced both; the fixed
ledger refreshes profiles and the writer persists incomplete status where JSON
remains writable. Runtime coverage includes an actual promoted EnemyActor.

## Hardening pass — 16 September 2026 (evening)

Reverified the baseline on this checkout first: the eleven functional suites
exited 0 with 299 checks; the writer's invalid-directory error and the save
suite's parse error are the documented fixtures. Review against the six
trust areas found three gaps, all fixed with reproducing tests:

- Player damage outcomes `intercepted` (Bastion's Last Hit leaves 1 HP) and
  `missed` (REWRITE) were dropped by the ledger: the intercepted hit's real HP
  loss vanished and the miss was invisible. Fixed in `BalanceLedger.player_damage`
  (`DAMAGING_OUTCOMES`, `AVOIDED_OUTCOMES`, `intercepted_hits`, `missed_hits`).
- Developer funding (`dev_grant` from the route loader, `developer_grant`) was
  earned income. Fixed with a `followers_debug` bucket; the wallet reconciles
  as opening + earned - spent + adjustments + debug = closing.
- Player damage from an actor bound to an EnemyWorld handle without a `spec`
  property fell back to the kind label; the recorder now resolves the handle's
  archetype. Rule self-damage (Danger Close, No Brakes skid) now reports the
  source `self_damage` instead of `unknown`.

Report and CSV carry the new columns (`seconds_loading`, `followers_debug`,
avoided/intercepted hit rows). New suite `BalanceRecorderOutcomeTest` (15
checks) drives the real player through the real Last Hit, REWRITE and Danger
Close rules and the real wallet; `BalanceLedgerTest` grew to 21.
