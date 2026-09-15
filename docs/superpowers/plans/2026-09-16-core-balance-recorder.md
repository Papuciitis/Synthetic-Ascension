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

- [ ] Ledger and writer: add `core/systems/telemetry/BalanceLedger.gd` and
  `BalanceCaptureWriter.gd`; drive with `BalanceLedgerTest` and
  `BalanceCaptureWriterTest`. Test 100 opening + 50 recruitment - 20 purchase
  + 20 refund = 150 closing, with 50 earned / 20 spent / 20 adjustment.
  Test a 100-damage hit on 25 HP records 25 removed and 75 overkill; a paused
  interval does not add to enemy time-to-kill. Check bounded history keeps
  exact totals and exposes dropped-record count. Commit the tested foundation.
- [ ] Runtime: add `autoload/BalanceRecorder.gd`; register it in project.godot.
  Add observational lifecycle signals to Global and EnemyWorld, detailed
  player damage/heal/stat/life events to RunEvents, and bind at game entry.
  `BalanceRecorderTest` exercises real damage, healing, wallet operations,
  segment completion, reset, and exported files. Preserve existing signals.
- [ ] Build identity: resolve `.git` indirection in BuildInfo so this worktree's
  recordings name the actual commit; verify with BuildInfoTest.
- [ ] Delivery: document automatic use, file locations, timing definitions,
  coverage and loss indicators. Run appropriate regression suites, measure
  hot-path cost, run ScriptParseAuditTest last, review the diff, and commit.

Commands use the installed Godot console executable with `--headless --path .`
and each `res://tools/tests/<Suite>.tscn --quit-after 3000`. Import new scripts
before suites. Verify the process exits and reports zero failures; a timeout or
missing summary is a failure. Only the editor is running at baseline.
